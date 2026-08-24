package com.usernode_labs.usernode.alarm

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.usernode_labs.usernode.R
import com.usernode_labs.usernode.session.SessionAuthorityNative

class SlotMonitoringService : Service() {
    companion object {
        private const val TAG = "usernode/SlotMonitoringService"
        const val ACTION_START_MONITORING = "com.usernode.app.START_MONITORING"
        const val ACTION_STOP_MONITORING = "com.usernode.app.STOP_MONITORING"
        const val ACTION_START_PERSISTENT = "com.usernode.app.START_PERSISTENT"
        const val ACTION_STOP_PERSISTENT = "com.usernode.app.STOP_PERSISTENT"

        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "slot_monitoring_channel"
        private const val CHANNEL_NAME = "Slot Monitoring"

        // Track persistent mode state globally so it can be queried
        @Volatile
        var isPersistentModeActive = false
            private set

        @Volatile
        var isForegroundServiceActive = false
            private set

        @Volatile
        var currentOwner: RuntimeOwner? = null
            private set
    }

    private var currentGlobalSlot: Int? = null
    private var isPersistentMode = false

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "[SlotMonitoringService] Service onCreate() - Time: ${System.currentTimeMillis()}")
        Log.d(TAG, "[SlotMonitoringService] Process ID: ${android.os.Process.myPid()}, Thread ID: ${android.os.Process.myTid()}")
        createNotificationChannel()
        Log.d(TAG, "[SlotMonitoringService] Notification channel created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val currentTime = System.currentTimeMillis()
        Log.i(TAG, "[SlotMonitoringService] onStartCommand() - Action: ${intent?.action}, StartId: $startId, Time: $currentTime")

        // happens on crash
        if (intent == null) {
            Log.w(TAG, "[SlotMonitoringService] Received null intent in onStartCommand")
            stopSelf()
            return START_NOT_STICKY
        }

        when (intent.action) {
            ACTION_START_MONITORING -> {
                val owner = RuntimeOwner.fromIntent(intent)
                if (owner == null) {
                    Log.w(TAG, "Ignoring START_MONITORING without a complete owner")
                    return START_NOT_STICKY
                }
                val globalSlot = readGlobalSlotExtra(intent) ?: 0
                val alarmId = intent.getStringExtra("alarmId")
                val nodeRunning = intent.getBooleanExtra("nodeRunning", false)
                val alarmTimeMs = intent.getLongExtra("alarmTimeMs", -1L)
                Log.d(TAG, "[SlotMonitoringService] START_MONITORING - GlobalSlot: $globalSlot, AlarmId: $alarmId, nodeRunning=$nodeRunning")

                // Allow alarmId-only wake (e.g., fg_resume) by using 0 as placeholder
                NativeSchedulingAuthority.process.runIfAdmitted(
                    operation = "service.start_monitoring",
                    owner = owner,
                    admitted = {
                        SessionAuthorityNative.isBackgroundRuntimeAdmitted(this, it)
                    },
                ) {
                    startMonitoring(globalSlot, nodeRunning, alarmTimeMs, owner)
                    true
                }
            }
            ACTION_STOP_MONITORING -> {
                val owner = RuntimeOwner.fromIntent(intent) ?: return START_NOT_STICKY
                NativeSchedulingAuthority.process.runIfOwned(
                    operation = "service.stop_monitoring",
                    owner = owner,
                    resourceOwner = { currentOwner },
                ) {
                    stopMonitoring()
                    true
                }
            }
            ACTION_START_PERSISTENT -> {
                val owner = RuntimeOwner.fromIntent(intent) ?: return START_NOT_STICKY
                NativeSchedulingAuthority.process.runIfAdmitted(
                    operation = "service.start_persistent",
                    owner = owner,
                    admitted = {
                        SessionAuthorityNative.isBackgroundRuntimeAdmitted(this, it)
                    },
                ) {
                    startPersistentMode(owner)
                    true
                }
            }
            ACTION_STOP_PERSISTENT -> {
                val owner = RuntimeOwner.fromIntent(intent) ?: return START_NOT_STICKY
                NativeSchedulingAuthority.process.runIfOwned(
                    operation = "service.stop_persistent",
                    owner = owner,
                    resourceOwner = { currentOwner },
                ) {
                    stopPersistentMode()
                    true
                }
            }
            else -> {
                Log.w(TAG, "[SlotMonitoringService] Unknown action: ${intent.action}")
            }
        }

        Log.d(TAG, "[SlotMonitoringService] Returning START_STICKY")
        return START_STICKY
    }

    private fun startMonitoring(
        globalSlot: Int,
        nodeRunning: Boolean,
        alarmTimeMs: Long = -1L,
        owner: RuntimeOwner,
    ) {
        currentGlobalSlot = globalSlot
        currentOwner = owner
        Log.i(TAG, "[SlotMonitoringService] ✓ Starting foreground monitoring for global slot $globalSlot")

        val scheduledTime = AlarmTimeFormatter.formatScheduledTime(alarmTimeMs)
        val baseMessage = if (nodeRunning) {
            "Monitoring slot $globalSlot for block production"
        } else {
            "Warming up node to monitor slots"
        }
        val messageWithTime = if (scheduledTime != null) {
            "$baseMessage (since $scheduledTime)"
        } else {
            baseMessage
        }

        val notification = createNotification(
            title = if (nodeRunning) "Block Production Monitoring" else "Starting node...",
            message = messageWithTime
        )

        try {
            startForeground(NOTIFICATION_ID, notification)
            Log.d(TAG, "[SlotMonitoringService] Foreground service started with notification ID $NOTIFICATION_ID")
            isForegroundServiceActive = true

            // Send event to Flutter
            Log.d(TAG, "[SlotMonitoringService] Sending android_foreground_service_started event to Flutter")
            val eventData = mapOf<String, Any?>(
                "globalSlot" to globalSlot,
            ) + owner.toMap()
            val handler = AlarmMethodChannelHandler.getInstance()
            if (handler != null && handler.isActivityAttached()) {
                handler.sendEventToFlutter("android_foreground_service_started", eventData)
            } else {
                BackgroundAlarmEngine.sendAlarmEvent(
                    applicationContext,
                    "android_foreground_service_started",
                    eventData
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "[SlotMonitoringService] Failed to start foreground service", e)
        }

    }

    private fun stopMonitoring() {
        val globalSlotBeingStopped = currentGlobalSlot
        val ownerBeingStopped = currentOwner
        Log.i(TAG, "[SlotMonitoringService] Stopping foreground monitoring for global slot $globalSlotBeingStopped")

        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
            Log.d(TAG, "[SlotMonitoringService] Foreground service stopped, notification removed")
            isForegroundServiceActive = false

            // Send event to Flutter
            Log.d(TAG, "[SlotMonitoringService] Sending android_foreground_service_stopped event to Flutter")
            val eventData = mapOf<String, Any?>(
                "globalSlot" to globalSlotBeingStopped,
            ) + (ownerBeingStopped?.toMap() ?: emptyMap())
            val handler = AlarmMethodChannelHandler.getInstance()
            if (handler != null && handler.isActivityAttached()) {
                handler.sendEventToFlutter("android_foreground_service_stopped", eventData)
            } else {
                BackgroundAlarmEngine.sendAlarmEvent(
                    applicationContext,
                    "android_foreground_service_stopped",
                    eventData
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "[SlotMonitoringService] Error stopping foreground", e)
        }

        currentGlobalSlot = null
        currentOwner = null

        try {
            stopSelf()
            Log.d(TAG, "[SlotMonitoringService] Service stopSelf() called")
        } catch (e: Exception) {
            Log.e(TAG, "[SlotMonitoringService] Error calling stopSelf()", e)
        }
    }

    @Suppress("DEPRECATION")
    private fun readGlobalSlotExtra(intent: Intent): Int? {
        return numberExtra(intent, "globalSlot")
            ?: numberExtra(intent, "global_slot")
            ?: numberExtra(intent, "slotNumber")
    }

    @Suppress("DEPRECATION")
    private fun numberExtra(intent: Intent, key: String): Int? {
        val value = intent.extras?.get(key) ?: return null
        return when (value) {
            is Int -> value
            is Long -> value.toInt()
            is Number -> value.toInt()
            is String -> value.toIntOrNull()
            else -> null
        }?.takeIf { it >= 0 }
    }

    private fun startPersistentMode(owner: RuntimeOwner) {
        isPersistentMode = true
        isPersistentModeActive = true
        currentOwner = owner
        Log.i(TAG, "[SlotMonitoringService] ✓ Starting persistent foreground mode")

        val notification = createNotification(
            title = "Block Production Active",
            message = "Monitoring for block production opportunities"
        )

        try {
            startForeground(NOTIFICATION_ID, notification)
            Log.d(TAG, "[SlotMonitoringService] Persistent foreground service started with notification ID $NOTIFICATION_ID")

            // Send event to Flutter
            Log.d(TAG, "[SlotMonitoringService] Sending android_persistent_foreground_started event to Flutter")
            val handler = AlarmMethodChannelHandler.getInstance()
            if (handler != null && handler.isActivityAttached()) {
                handler.sendEventToFlutter(
                    "android_persistent_foreground_started",
                    owner.toMap(),
                )
            } else {
                BackgroundAlarmEngine.sendAlarmEvent(
                    applicationContext,
                    "android_persistent_foreground_started",
                    owner.toMap(),
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "[SlotMonitoringService] Failed to start persistent foreground service", e)
            isPersistentMode = false
            isPersistentModeActive = false
        }
    }

    private fun stopPersistentMode() {
        val ownerBeingStopped = currentOwner
        Log.i(TAG, "[SlotMonitoringService] Stopping persistent foreground mode")
        isPersistentMode = false
        isPersistentModeActive = false

        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
            Log.d(TAG, "[SlotMonitoringService] Persistent foreground service stopped, notification removed")
            isForegroundServiceActive = false

            // Send event to Flutter
            Log.d(TAG, "[SlotMonitoringService] Sending android_persistent_foreground_stopped event to Flutter")
            val handler = AlarmMethodChannelHandler.getInstance()
            if (handler != null && handler.isActivityAttached()) {
                handler.sendEventToFlutter(
                    "android_persistent_foreground_stopped",
                    ownerBeingStopped?.toMap() ?: emptyMap(),
                )
            } else {
                BackgroundAlarmEngine.sendAlarmEvent(
                    applicationContext,
                    "android_persistent_foreground_stopped",
                    ownerBeingStopped?.toMap() ?: emptyMap(),
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "[SlotMonitoringService] Error stopping persistent foreground", e)
        }
        currentOwner = null

        try {
            stopSelf()
            Log.d(TAG, "[SlotMonitoringService] Service stopSelf() called")
        } catch (e: Exception) {
            Log.e(TAG, "[SlotMonitoringService] Error calling stopSelf()", e)
        }
    }

    override fun onBind(intent: Intent?): IBinder? {
        Log.d(TAG, "[SlotMonitoringService] onBind() called (returning null)")
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.i(TAG, "[SlotMonitoringService] Service onDestroy() - GlobalSlot: $currentGlobalSlot, Time: ${System.currentTimeMillis()}")
        Log.d(TAG, "[SlotMonitoringService] Service destroyed, monitoring ended")
        isForegroundServiceActive = false
        currentOwner = null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_LOW
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, importance).apply {
                description = "Notifications for slot monitoring"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(title: String, message: String): Notification {
        // Do not attempt to launch UI directly; just show service notification
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .build()
    }

    fun updateNotification(title: String, message: String) {
        val notification = createNotification(title, message)
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }

}
