package com.usernode_labs.usernode.alarm

import android.app.AlarmManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import android.app.NotificationManager
import android.app.NotificationChannel
import android.app.PendingIntent
import com.usernode_labs.usernode.MainActivity
import com.usernode_labs.usernode.R

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "usernode/AlarmReceiver"
        private const val ACTION_EXACT_ALARM_PERMISSION_CHANGED =
            "android.app.action.SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED"
    }

    override fun onReceive(context: Context, intent: Intent) {
        Log.i(TAG, "[AlarmReceiver] Broadcast received - Action: ${intent.action}, Time: ${System.currentTimeMillis()}")

        when (intent.action) {
            "com.usernode.app.SLOT_ALARM" -> {
                handleSlotAlarm(context, intent)
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                handleBootCompleted(context)
            }
            Intent.ACTION_MY_PACKAGE_REPLACED -> {
                handlePackageReplaced(context)
            }
            ACTION_EXACT_ALARM_PERMISSION_CHANGED -> {
                handleExactAlarmPermissionStateChanged(context)
            }
            else -> {
                Log.w(TAG, "[AlarmReceiver] Unknown action received: ${intent.action}")
            }
        }
    }

    private fun handleSlotAlarm(context: Context, intent: Intent) {
        val alarmId = intent.getStringExtra("alarmId")
        val slotNumber = intent.getIntExtra("slotNumber", -1)
        val scheduledTimeMs = intent.getLongExtra("alarmTimeMs", -1L)
        val nodeRunning = intent.getBooleanExtra("nodeRunning", false)
        val globalSlot = optionalLongExtra(intent, "globalSlot")
            ?: optionalLongExtra(intent, "global_slot")
            ?: slotNumber.takeIf { it > 0 }?.toLong()
        val reason = intent.getStringExtra("reason")
        val purpose = intent.getStringExtra("purpose")

        Log.d(TAG, "[AlarmReceiver] Slot alarm details - ID: $alarmId, Slot: $slotNumber, Scheduled: $scheduledTimeMs")

        if (alarmId == null) {
            Log.e(TAG, "[AlarmReceiver] Missing alarmId in intent")
            return
        }
        if (slotNumber == -1) {
            Log.e(TAG, "[AlarmReceiver] Missing or invalid slotNumber in intent")
            return
        }

        val currentTime = System.currentTimeMillis()
        val latencyMs = if (scheduledTimeMs > 0) currentTime - scheduledTimeMs else 0L
        Log.i(TAG, "[AlarmReceiver] ✓ Slot alarm FIRED for slot $slotNumber (latency: ${latencyMs}ms)")

        // Take the native wakelock before handing control to Flutter so the
        // inactivity sleep path cannot win a race against alarm recovery.
        NativeWakeLockManager.acquire(context)

        val eventData = mutableMapOf<String, Any?>(
            "alarmId" to alarmId,
            "slotNumber" to slotNumber,
            "alarmTimeMs" to scheduledTimeMs,
            "firedAtMs" to currentTime,
            "latencyMs" to latencyMs,
            "batteryLevel" to 0,
            "networkState" to "unknown",
            "nodeRunning" to nodeRunning
        )
        globalSlot?.let { eventData["globalSlot"] = it }
        reason?.let { eventData["reason"] = it }
        purpose?.let { eventData["purpose"] = it }

        val handler = AlarmMethodChannelHandler.getInstance()
        if (handler != null && handler.isActivityAttached()) {
            Log.d(TAG, "[AlarmReceiver] Sending android_alarm_fired event to attached Flutter activity")
            handler.sendEventToFlutter("android_alarm_fired", eventData)
        } else {
            Log.d(TAG, "[AlarmReceiver] Delivering android_alarm_fired via background engine")
            BackgroundAlarmEngine.sendAlarmEvent(
                context,
                "android_alarm_fired",
                eventData
            )
        }

        // Start foreground service to keep app alive during monitoring
        Log.d(TAG, "[AlarmReceiver] Starting SlotMonitoringService")
        val serviceIntent = Intent(context, SlotMonitoringService::class.java).apply {
            action = SlotMonitoringService.ACTION_START_MONITORING
            putExtra("alarmId", alarmId)
            putExtra("slotNumber", slotNumber)
            putExtra("nodeRunning", nodeRunning)
            putExtra("alarmTimeMs", scheduledTimeMs)
            globalSlot?.let { putExtra("globalSlot", it) }
            reason?.let { putExtra("reason", it) }
            purpose?.let { putExtra("purpose", it) }
        }
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Log.d(TAG, "[AlarmReceiver] Using startForegroundService (API >= 26)")
                context.startForegroundService(serviceIntent)
            } else {
                Log.d(TAG, "[AlarmReceiver] Using startService (API < 26)")
                context.startService(serviceIntent)
            }
            Log.d(TAG, "[AlarmReceiver] SlotMonitoringService start command sent")
        } catch (e: Exception) {
            Log.e(TAG, "[AlarmReceiver] Failed to start SlotMonitoringService", e)
        }
    }

    private fun handleBootCompleted(context: Context) {
        Log.i(TAG, "Device boot completed - starting monitoring")
        sendAuditRecoveryEvent(context, "boot_completed")
        startMonitoringService(
            context = context,
            alarmId = "boot_completed",
            slotNumber = 0,
            nodeRunning = false
        )
    }

    private fun handlePackageReplaced(context: Context) {
        Log.i(TAG, "App updated - starting monitoring")
        sendAuditRecoveryEvent(context, "package_replaced")
        startMonitoringService(
            context = context,
            alarmId = "package_replaced",
            slotNumber = 0,
            nodeRunning = false
        )
    }

    private fun handleExactAlarmPermissionStateChanged(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }

        val eventType = if (granted) {
            "android_exact_alarm_permission_granted"
        } else {
            "android_exact_alarm_permission_denied"
        }
        sendFlutterEvent(
            context = context,
            eventType = eventType,
            eventData = mapOf(
                "source" to "permission_state_changed_broadcast",
                "stateChanged" to true
            )
        )
    }

    private fun sendAuditRecoveryEvent(context: Context, reason: String) {
        sendFlutterEvent(
            context = context,
            eventType = "android_alarm_recovery_requested",
            eventData = mapOf(
                "reason" to reason,
                "source" to "alarm_receiver"
            )
        )
    }

    private fun sendFlutterEvent(
        context: Context,
        eventType: String,
        eventData: Map<String, Any?>
    ) {
        val handler = AlarmMethodChannelHandler.getInstance()
        if (handler != null && handler.isActivityAttached()) {
            handler.sendEventToFlutter(eventType, eventData)
            return
        }

        BackgroundAlarmEngine.sendAlarmEvent(context, eventType, eventData)
    }

    private fun startMonitoringService(
        context: Context,
        alarmId: String,
        slotNumber: Int,
        nodeRunning: Boolean
    ) {
        val serviceIntent = Intent(context, SlotMonitoringService::class.java).apply {
            action = SlotMonitoringService.ACTION_START_MONITORING
            putExtra("alarmId", alarmId)
            putExtra("slotNumber", slotNumber)
            putExtra("nodeRunning", nodeRunning)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }

        Log.i(TAG, "SlotMonitoringService started (alarmId=$alarmId, slot=$slotNumber)")
    }

    private fun showFallbackNotification(
        context: Context,
        slotNumber: Int,
        scheduledTimeMs: Long
    ) {
        val channelId = "slot_alarm_fallback"
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Slot Alarm",
                NotificationManager.IMPORTANCE_HIGH
            )
            nm.createNotificationChannel(channel)
        }

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("slotNumber", slotNumber)
            putExtra("fromAlarm", true)
        }
        val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        val pendingIntent = PendingIntent.getActivity(context, 0, launchIntent, piFlags)

        val scheduledTimeText = AlarmTimeFormatter.formatScheduledTime(scheduledTimeMs)
        val message = if (scheduledTimeText != null) {
            "Resumed for slot $slotNumber (scheduled $scheduledTimeText)"
        } else {
            "Resumed for slot $slotNumber"
        }

        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(R.drawable.launch_background)
            .setContentTitle("Slot alarm fired")
            .setContentText(message)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .build()

        nm.notify(slotNumber, notification)
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

}
