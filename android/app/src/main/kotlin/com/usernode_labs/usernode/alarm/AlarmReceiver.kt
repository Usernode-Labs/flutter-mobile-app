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
        Log.i(TAG, "Alarm received: ${intent.action}")

        when (intent.action) {
            "com.usernode.lingash.SLOT_ALARM" -> {
                handleSlotAlarm(context, intent)
            }
            Intent.ACTION_BOOT_COMPLETED -> {
                handleBootCompleted(context)
            }
        }
    }

    private fun handleSlotAlarm(context: Context, intent: Intent) {
        val alarmId = intent.getStringExtra("alarmId") ?: return
        val slotNumber = intent.getIntExtra("slotNumber", -1)
        if (slotNumber == -1) return

        Log.i(TAG, "Slot alarm fired for slot $slotNumber")

        // Start foreground service to keep app alive during monitoring
        val serviceIntent = Intent(context, SlotMonitoringService::class.java).apply {
            action = SlotMonitoringService.ACTION_START_MONITORING
            putExtra("alarmId", alarmId)
            putExtra("slotNumber", slotNumber)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }

        // Also try to launch the app if possible
        try {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            launchIntent?.let {
                it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                it.putExtra("slotNumber", slotNumber)
                it.putExtra("fromAlarm", true)
                context.startActivity(it)
            }
        } catch (e: Exception) {
            Log.w(TAG, "Could not launch app from alarm", e)
        }
    }

    private fun handleBootCompleted(context: Context) {
        Log.i(TAG, "Device boot completed - alarms need to be rescheduled")
        // Alarms are lost on reboot and need to be rescheduled
        // This will be handled by Flutter when the app starts
    }
}
