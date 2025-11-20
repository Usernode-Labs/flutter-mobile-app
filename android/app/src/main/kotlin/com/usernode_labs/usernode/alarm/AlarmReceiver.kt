package com.usernode_labs.usernode.alarm

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "AlarmReceiver"
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
            else -> {
                Log.w(TAG, "[AlarmReceiver] Unknown action received: ${intent.action}")
            }
        }
    }

    private fun handleSlotAlarm(context: Context, intent: Intent) {
        val alarmId = intent.getStringExtra("alarmId")
        val slotNumber = intent.getIntExtra("slotNumber", -1)
        val scheduledTimeMs = intent.getLongExtra("alarmTimeMs", -1L)

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

        // Send event to Flutter
        Log.d(TAG, "[AlarmReceiver] Sending android_alarm_fired event to Flutter")
        val eventData = mapOf(
            "alarmId" to alarmId,
            "slotNumber" to slotNumber,
            "batteryLevel" to 0, // TODO: Get actual battery level
            "networkState" to "unknown" // TODO: Get actual network state
        )
        AlarmMethodChannelHandler.getInstance()?.sendEventToFlutter("android_alarm_fired", eventData)

        // Start foreground service to keep app alive during monitoring
        Log.d(TAG, "[AlarmReceiver] Starting SlotMonitoringService")
        val serviceIntent = Intent(context, SlotMonitoringService::class.java).apply {
            action = SlotMonitoringService.ACTION_START_MONITORING
            putExtra("alarmId", alarmId)
            putExtra("slotNumber", slotNumber)
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

        // Also try to launch the app if possible
        Log.d(TAG, "[AlarmReceiver] Attempting to launch app")
        try {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            launchIntent?.let {
                it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                it.putExtra("slotNumber", slotNumber)
                it.putExtra("fromAlarm", true)
                context.startActivity(it)
                Log.d(TAG, "[AlarmReceiver] App launch intent sent")
            } ?: Log.w(TAG, "[AlarmReceiver] Launch intent is null")
        } catch (e: Exception) {
            Log.w(TAG, "[AlarmReceiver] Could not launch app from alarm", e)
        }
    }

    private fun handleBootCompleted(context: Context) {
        Log.i(TAG, "Device boot completed - alarms need to be rescheduled")

        // Start a background service to reschedule alarms
        // This ensures alarms are restored even if user doesn't open the app
        val serviceIntent = Intent(context, BootRescheduleService::class.java)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }

        Log.i(TAG, "Boot reschedule service started")
    }
}
