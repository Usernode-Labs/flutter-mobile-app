package com.usernode_labs.usernode.alarm

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import com.usernode_labs.usernode.R
import com.usernode_labs.usernode.session.NativeProducerWakeCoordinator
import com.usernode_labs.usernode.session.ProducerWakeSource

class SlotMonitoringService : Service() {
    companion object {
        private const val TAG = "usernode/SlotMonitoringService"
        const val ACTION_START_MONITORING = "com.usernode.app.START_MONITORING"
        const val ACTION_STOP_MONITORING = "com.usernode.app.STOP_MONITORING"
        const val ACTION_START_PERSISTENT = "com.usernode.app.START_PERSISTENT"
        const val ACTION_STOP_PERSISTENT = "com.usernode.app.STOP_PERSISTENT"
        private const val ACTION_NATIVE_PRODUCER_MONITORING =
            "com.usernode.app.NATIVE_PRODUCER_MONITORING"
        private const val EXTRA_NATIVE_POLL_AFTER_MS = "nativePollAfterMs"

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

        fun startNativeProducerMonitoring(
            context: Context,
            applicationIncarnation: String,
            pollAfterMs: Long,
        ) {
            val intent = Intent(context, SlotMonitoringService::class.java).apply {
                action = ACTION_NATIVE_PRODUCER_MONITORING
                putExtra(
                    ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION,
                    applicationIncarnation,
                )
                putExtra(EXTRA_NATIVE_POLL_AFTER_MS, pollAfterMs.coerceAtLeast(0))
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stopNativeProducerMonitoring(context: Context) {
            context.stopService(Intent(context, SlotMonitoringService::class.java))
        }
    }

    private var currentGlobalSlot: Int? = null
    private var currentApplicationIncarnation: String? = null
    private var isPersistentMode = false
    private val producerHandler = Handler(Looper.getMainLooper())
    private val producerPoll = Runnable {
        NativeProducerWakeCoordinator.submit(
            applicationContext,
            ProducerWakeSource.WATCHDOG,
            refreshPolicy = false,
        )
    }

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
                val applicationIncarnation = intent.getStringExtra(
                    ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION,
                )
                if (!ApplicationIncarnationStore(this).matches(applicationIncarnation)) {
                    Log.w(TAG, "Ignoring stale START_MONITORING command")
                    stopIfNotServingCurrentIncarnation(startId)
                    return START_NOT_STICKY
                }
                val globalSlot = readGlobalSlotExtra(intent) ?: 0
                val alarmId = intent.getStringExtra("alarmId")
                val nodeRunning = intent.getBooleanExtra("nodeRunning", false)
                val alarmTimeMs = intent.getLongExtra("alarmTimeMs", -1L)
                Log.d(TAG, "[SlotMonitoringService] START_MONITORING - GlobalSlot: $globalSlot, AlarmId: $alarmId, nodeRunning=$nodeRunning")

                // Allow alarmId-only wake (e.g., fg_resume) by using 0 as placeholder
                startMonitoring(
                    globalSlot,
                    nodeRunning,
                    alarmTimeMs,
                    applicationIncarnation!!,
                )
            }
            ACTION_STOP_MONITORING -> {
                Log.d(TAG, "[SlotMonitoringService] STOP_MONITORING action received")
                stopMonitoring()
            }
            ACTION_NATIVE_PRODUCER_MONITORING -> {
                val applicationIncarnation = intent.getStringExtra(
                    ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION,
                )
                if (!ApplicationIncarnationStore(this).matches(applicationIncarnation)) {
                    Log.w(TAG, "Ignoring stale native producer monitoring command")
                    stopIfNotServingCurrentIncarnation(startId)
                    return START_NOT_STICKY
                }
                startMonitoring(
                    globalSlot = 0,
                    nodeRunning = true,
                    applicationIncarnation = applicationIncarnation!!,
                )
                producerHandler.removeCallbacks(producerPoll)
                producerHandler.postDelayed(
                    producerPoll,
                    intent.getLongExtra(EXTRA_NATIVE_POLL_AFTER_MS, 0).coerceAtLeast(0),
                )
            }
            ACTION_START_PERSISTENT -> {
                val applicationIncarnation = intent.getStringExtra(
                    ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION,
                )
                if (!ApplicationIncarnationStore(this).matches(applicationIncarnation)) {
                    Log.w(TAG, "Ignoring stale START_PERSISTENT command")
                    stopIfNotServingCurrentIncarnation(startId)
                    return START_NOT_STICKY
                }
                Log.d(TAG, "[SlotMonitoringService] START_PERSISTENT action received")
                startPersistentMode(applicationIncarnation!!)
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

    private fun stopIfNotServingCurrentIncarnation(startId: Int) {
        if (!ApplicationIncarnationStore(this).matches(currentApplicationIncarnation)) {
            stopSelf(startId)
        }
    }

    private fun startMonitoring(
        globalSlot: Int,
        nodeRunning: Boolean,
        alarmTimeMs: Long = -1L,
        applicationIncarnation: String,
    ) {
        currentGlobalSlot = globalSlot
        currentApplicationIncarnation = applicationIncarnation
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

        } catch (e: Exception) {
            Log.e(TAG, "[SlotMonitoringService] Failed to start foreground service", e)
        }

    }

    private fun stopMonitoring() {
        val globalSlotBeingStopped = currentGlobalSlot
        Log.i(TAG, "[SlotMonitoringService] Stopping foreground monitoring for global slot $globalSlotBeingStopped")

        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
            Log.d(TAG, "[SlotMonitoringService] Foreground service stopped, notification removed")
            isForegroundServiceActive = false

            producerHandler.removeCallbacks(producerPoll)
        } catch (e: Exception) {
            Log.e(TAG, "[SlotMonitoringService] Error stopping foreground", e)
        }

        currentGlobalSlot = null
        currentApplicationIncarnation = null

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

    private fun startPersistentMode(applicationIncarnation: String) {
        isPersistentMode = true
        isPersistentModeActive = true
        currentApplicationIncarnation = applicationIncarnation
        Log.i(TAG, "[SlotMonitoringService] ✓ Starting persistent foreground mode")

        val notification = createNotification(
            title = "Block Production Active",
            message = "Monitoring for block production opportunities"
        )

        try {
            startForeground(NOTIFICATION_ID, notification)
            Log.d(TAG, "[SlotMonitoringService] Persistent foreground service started with notification ID $NOTIFICATION_ID")

        } catch (e: Exception) {
            Log.e(TAG, "[SlotMonitoringService] Failed to start persistent foreground service", e)
            isPersistentMode = false
            isPersistentModeActive = false
        }
    }

    private fun stopPersistentMode() {
        Log.i(TAG, "[SlotMonitoringService] Stopping persistent foreground mode")
        isPersistentMode = false
        isPersistentModeActive = false

        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
            Log.d(TAG, "[SlotMonitoringService] Persistent foreground service stopped, notification removed")
            isForegroundServiceActive = false

            producerHandler.removeCallbacks(producerPoll)
        } catch (e: Exception) {
            Log.e(TAG, "[SlotMonitoringService] Error stopping persistent foreground", e)
        }
        currentApplicationIncarnation = null

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
        producerHandler.removeCallbacks(producerPoll)
        super.onDestroy()
        Log.i(TAG, "[SlotMonitoringService] Service onDestroy() - GlobalSlot: $currentGlobalSlot, Time: ${System.currentTimeMillis()}")
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
