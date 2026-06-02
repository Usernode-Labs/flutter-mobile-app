package com.usernode_labs.usernode.alarm

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.usernode_labs.usernode.R

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
    }

    private var currentSlotNumber: Int? = null
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

            startMonitoring(0, false)
            val firedAtMs = System.currentTimeMillis()

            val eventData = mapOf(
                "alarmId" to "slot_monitoring_null_intent",
                "slotNumber" to 0,
                "firedAtMs" to firedAtMs,
                "batteryLevel" to 0,
                "networkState" to "unknown",
                "nodeRunning" to false
            )

            // Enforce a single-engine policy:
            // - If the UI engine/channel exists, deliver the event through it (no headless engine).
            // - Otherwise, spin up the headless engine to deliver the alarm event.
            val handler = AlarmMethodChannelHandler.getInstance()
            if (handler != null && handler.isActivityAttached()) {
                handler.sendEventToFlutter("android_alarm_fired", eventData)
            } else {
                BackgroundAlarmEngine.sendAlarmEvent(
                    applicationContext,
                    "android_alarm_fired",
                    eventData
                )
            }
            return START_STICKY
        }

        when (intent.action) {
            ACTION_START_MONITORING -> {
                val slotNumber = intent.getIntExtra("slotNumber", -1)
                val alarmId = intent.getStringExtra("alarmId")
                val nodeRunning = intent.getBooleanExtra("nodeRunning", false)
                val alarmTimeMs = intent.getLongExtra("alarmTimeMs", -1L)
                val reason = intent.getStringExtra("reason")
                val purpose = intent.getStringExtra("purpose")
                Log.d(TAG, "[SlotMonitoringService] START_MONITORING - Slot: $slotNumber, AlarmId: $alarmId, nodeRunning=$nodeRunning")

                // Allow alarmId-only wake (e.g., fg_resume) by using 0 as placeholder
                val safeSlot = if (slotNumber != -1) slotNumber else 0
                val globalSlot = optionalLongExtra(intent, "globalSlot")
                    ?: optionalLongExtra(intent, "global_slot")
                    ?: safeSlot.takeIf { it > 0 }?.toLong()
                startMonitoring(safeSlot, nodeRunning, alarmTimeMs)
                val firedAtMs = System.currentTimeMillis()
                val latencyMs = if (alarmTimeMs > 0) firedAtMs - alarmTimeMs else 0L

                val eventData = mutableMapOf<String, Any?>(
                    "alarmId" to (alarmId ?: "unknown"),
                    "slotNumber" to safeSlot,
                    "alarmTimeMs" to alarmTimeMs,
                    "firedAtMs" to firedAtMs,
                    "latencyMs" to latencyMs,
                    "batteryLevel" to 0,
                    "networkState" to "unknown",
                    "nodeRunning" to nodeRunning
                )
                globalSlot?.let { eventData["globalSlot"] = it }
                reason?.let { eventData["reason"] = it }
                purpose?.let { eventData["purpose"] = it }

                // Enforce a single-engine policy:
                // - If the UI engine/channel exists, deliver the event through it (no headless engine).
                // - Otherwise, spin up the headless engine to deliver the alarm event.
                val handler = AlarmMethodChannelHandler.getInstance()
                if (handler != null && handler.isActivityAttached()) {
                    handler.sendEventToFlutter("android_alarm_fired", eventData)
                } else {
                    BackgroundAlarmEngine.sendAlarmEvent(
                        applicationContext,
                        "android_alarm_fired",
                        eventData
                    )
                }
            }
            ACTION_STOP_MONITORING -> {
                Log.d(TAG, "[SlotMonitoringService] STOP_MONITORING action received")
                stopMonitoring()
            }
            ACTION_START_PERSISTENT -> {
                Log.d(TAG, "[SlotMonitoringService] START_PERSISTENT action received")
                startPersistentMode()
            }
            ACTION_STOP_PERSISTENT -> {
                Log.d(TAG, "[SlotMonitoringService] STOP_PERSISTENT action received")
                stopPersistentMode()
            }
            else -> {
                Log.w(TAG, "[SlotMonitoringService] Unknown action: ${intent.action}")
            }
        }

        Log.d(TAG, "[SlotMonitoringService] Returning START_STICKY")
        return START_STICKY
    }

    private fun startMonitoring(slotNumber: Int, nodeRunning: Boolean, alarmTimeMs: Long = -1L) {
        currentSlotNumber = slotNumber
        Log.i(TAG, "[SlotMonitoringService] ✓ Starting foreground monitoring for slot $slotNumber")

        val scheduledTime = AlarmTimeFormatter.formatScheduledTime(alarmTimeMs)
        val baseMessage = if (nodeRunning) {
            "Monitoring slot $slotNumber for block production"
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
            val eventData = mapOf("slotNumber" to slotNumber)
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
        val slotBeingStopped = currentSlotNumber
        Log.i(TAG, "[SlotMonitoringService] Stopping foreground monitoring for slot $slotBeingStopped")

        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
            Log.d(TAG, "[SlotMonitoringService] Foreground service stopped, notification removed")
            isForegroundServiceActive = false

            // Send event to Flutter
            Log.d(TAG, "[SlotMonitoringService] Sending android_foreground_service_stopped event to Flutter")
            val eventData = mapOf("slotNumber" to slotBeingStopped)
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

        currentSlotNumber = null

        try {
            stopSelf()
            Log.d(TAG, "[SlotMonitoringService] Service stopSelf() called")
        } catch (e: Exception) {
            Log.e(TAG, "[SlotMonitoringService] Error calling stopSelf()", e)
        }
    }

    private fun startPersistentMode() {
        isPersistentMode = true
        isPersistentModeActive = true
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
                    mapOf<String, Any?>()
                )
            } else {
                BackgroundAlarmEngine.sendAlarmEvent(
                    applicationContext,
                    "android_persistent_foreground_started",
                    emptyMap()
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "[SlotMonitoringService] Failed to start persistent foreground service", e)
            isPersistentMode = false
            isPersistentModeActive = false
        }
    }

    @Suppress("DEPRECATION")
    private fun optionalLongExtra(intent: Intent, key: String): Long? {
        if (!intent.hasExtra(key)) return null
        val value = intent.extras?.get(key) ?: return null
        return when (value) {
            is Int -> value.toLong()
            is Long -> value
            is Number -> value.toLong()
            is String -> value.toLongOrNull()
            else -> null
        }?.takeIf { it > 0 }
    }

    private fun stopPersistentMode() {
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
                    mapOf<String, Any?>()
                )
            } else {
                BackgroundAlarmEngine.sendAlarmEvent(
                    applicationContext,
                    "android_persistent_foreground_stopped",
                    emptyMap()
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "[SlotMonitoringService] Error stopping persistent foreground", e)
        }

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
        Log.i(TAG, "[SlotMonitoringService] ✗ Service onDestroy() - Slot: $currentSlotNumber, Time: ${System.currentTimeMillis()}")
        Log.d(TAG, "[SlotMonitoringService] Service destroyed, monitoring ended")
        isForegroundServiceActive = false
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
