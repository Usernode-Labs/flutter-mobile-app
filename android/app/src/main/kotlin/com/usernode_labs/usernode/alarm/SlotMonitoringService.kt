package com.usernode_labs.usernode.alarm

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.usernode_labs.usernode.R
import com.usernode_labs.usernode.MainActivity

class SlotMonitoringService : Service() {
    companion object {
        private const val TAG = "SlotMonitoringService"
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

        if (intent == null) {
            Log.w(TAG, "[SlotMonitoringService] Received null intent in onStartCommand")
            return START_STICKY
        }

        when (intent.action) {
            ACTION_START_MONITORING -> {
                val slotNumber = intent.getIntExtra("slotNumber", -1)
                val alarmId = intent.getStringExtra("alarmId")
                Log.d(TAG, "[SlotMonitoringService] START_MONITORING - Slot: $slotNumber, AlarmId: $alarmId")

                if (slotNumber != -1) {
                    startMonitoring(slotNumber)
                } else {
                    Log.e(TAG, "[SlotMonitoringService] Invalid slot number in START_MONITORING intent")
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

    private fun startMonitoring(slotNumber: Int) {
        currentSlotNumber = slotNumber
        Log.i(TAG, "[SlotMonitoringService] ✓ Starting foreground monitoring for slot $slotNumber")

        val notification = createNotification(
            title = "Slots Coming Up",
            message = "Open the app to increase your chances of producing blocks"
        )

        try {
            startForeground(NOTIFICATION_ID, notification)
            Log.d(TAG, "[SlotMonitoringService] Foreground service started with notification ID $NOTIFICATION_ID")

            // Send event to Flutter
            Log.d(TAG, "[SlotMonitoringService] Sending android_foreground_service_started event to Flutter")
            val eventData = mapOf("slotNumber" to slotNumber)
            AlarmMethodChannelHandler.getInstance()?.sendEventToFlutter("android_foreground_service_started", eventData)
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

            // Send event to Flutter
            Log.d(TAG, "[SlotMonitoringService] Sending android_foreground_service_stopped event to Flutter")
            val eventData = mapOf("slotNumber" to slotBeingStopped)
            AlarmMethodChannelHandler.getInstance()?.sendEventToFlutter("android_foreground_service_stopped", eventData)
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
            title = "Slots Coming Up",
            message = "Open the app to increase your chances of producing blocks"
        )

        try {
            startForeground(NOTIFICATION_ID, notification)
            Log.d(TAG, "[SlotMonitoringService] Persistent foreground service started with notification ID $NOTIFICATION_ID")

            // Send event to Flutter
            Log.d(TAG, "[SlotMonitoringService] Sending android_persistent_foreground_started event to Flutter")
            AlarmMethodChannelHandler.getInstance()?.sendEventToFlutter("android_persistent_foreground_started", mapOf<String, Any?>())
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

            // Send event to Flutter
            Log.d(TAG, "[SlotMonitoringService] Sending android_persistent_foreground_stopped event to Flutter")
            AlarmMethodChannelHandler.getInstance()?.sendEventToFlutter("android_persistent_foreground_stopped", mapOf<String, Any?>())
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
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(message)
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    fun updateNotification(title: String, message: String) {
        val notification = createNotification(title, message)
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
    }
}
