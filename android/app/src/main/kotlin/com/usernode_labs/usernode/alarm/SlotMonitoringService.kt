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

        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "slot_monitoring_channel"
        private const val CHANNEL_NAME = "Slot Monitoring"
    }

    private var currentSlotNumber: Int? = null

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "SlotMonitoringService created")
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "SlotMonitoringService onStartCommand: ${intent?.action}")

        when (intent?.action) {
            ACTION_START_MONITORING -> {
                val slotNumber = intent.getIntExtra("slotNumber", -1)
                if (slotNumber != -1) {
                    startMonitoring(slotNumber)
                }
            }
            ACTION_STOP_MONITORING -> {
                stopMonitoring()
            }
        }

        return START_STICKY
    }

    private fun startMonitoring(slotNumber: Int) {
        currentSlotNumber = slotNumber
        Log.i(TAG, "Starting foreground monitoring for slot $slotNumber")

        val notification = createNotification(
            title = "Block Production Monitoring",
            message = "Monitoring slot $slotNumber for block production"
        )

        startForeground(NOTIFICATION_ID, notification)
    }

    private fun stopMonitoring() {
        Log.i(TAG, "Stopping foreground monitoring")
        currentSlotNumber = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.i(TAG, "SlotMonitoringService destroyed")
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
