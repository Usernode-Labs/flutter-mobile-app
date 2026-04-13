package com.usernode_labs.usernode.alarm

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import com.usernode_labs.usernode.R

class AlarmScheduler(
    private val context: Context,
    private val alarmManager: AlarmManager
) {
    companion object {
        private const val TAG = "usernode/AlarmScheduler"
        private const val PREFS_NAME = "alarm_prefs"
        private const val SCHEDULED_ALARMS_KEY = "scheduled_alarms"
        private const val SCHEDULED_CHANNEL_ID = "slot_alarm_scheduled"
        private const val SCHEDULED_CHANNEL_NAME = "Scheduled Slot Alarms"
    }

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun scheduleExactAlarm(
        alarmId: String,
        delayMs: Long,
        slotNumber: Int,
        data: Map<String, Any>
    ): Boolean {
        try {
            Log.d(TAG, "[AlarmScheduler] Attempting to schedule alarm - ID: $alarmId, Slot: $slotNumber, Delay: $delayMs")

            val currentTime = System.currentTimeMillis()
            val effectiveDelayMs = delayMs.coerceAtLeast(0L)
            val triggerAtMs = currentTime + effectiveDelayMs

            // Check if we can schedule exact alarms
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val canSchedule = alarmManager.canScheduleExactAlarms()
                Log.d(TAG, "[AlarmScheduler] Exact alarm permission status: $canSchedule (API ${Build.VERSION.SDK_INT})")
                if (!canSchedule) {
                    Log.w(TAG, "[AlarmScheduler] Cannot schedule exact alarms - permission not granted")
                    return false
                }
            } else {
                Log.d(TAG, "[AlarmScheduler] No permission check needed (API ${Build.VERSION.SDK_INT} < 31)")
            }

            // Create intent for alarm receiver
            Log.d(TAG, "[AlarmScheduler] Creating PendingIntent for alarm broadcast")
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = "com.usernode.app.SLOT_ALARM"
                putExtra("alarmId", alarmId)
                putExtra("slotNumber", slotNumber)
                putExtra("alarmTimeMs", triggerAtMs)
                // Fan out provided data map into intent extras for downstream consumers
                for ((key, value) in data) {
                    when (value) {
                        is String -> putExtra(key, value)
                        is Int -> putExtra(key, value)
                        is Long -> putExtra(key, value)
                        is Boolean -> putExtra(key, value)
                        is Double -> putExtra(key, value)
                        else -> Log.w(TAG, "[AlarmScheduler] Skipping extra for key=$key unsupported type=${value::class.java.simpleName}")
                    }
                }
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                alarmId.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            Log.d(TAG, "[AlarmScheduler] PendingIntent created with hashCode: ${alarmId.hashCode()}")

            // Schedule exact alarm
            Log.d(
                TAG,
                "[AlarmScheduler] Current time: $currentTime, Trigger at: $triggerAtMs, Delay: ${effectiveDelayMs}ms (${effectiveDelayMs/1000}s)"
            )

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Log.d(TAG, "[AlarmScheduler] Using setExactAndAllowWhileIdle (API >= 23)")
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMs,
                    pendingIntent
                )
            } else {
                Log.d(TAG, "[AlarmScheduler] Using setExact (API < 23)")
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMs,
                    pendingIntent
                )
            }

            // Save alarm ID for tracking
            saveScheduledAlarm(alarmId, slotNumber)
            Log.d(TAG, "[AlarmScheduler] Alarm saved to SharedPreferences")

            showScheduledNotification(alarmId, slotNumber, triggerAtMs)

            Log.i(TAG, "[AlarmScheduler] ✓ Successfully scheduled exact alarm for slot $slotNumber at $triggerAtMs (in ${effectiveDelayMs/1000}s)")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "[AlarmScheduler] ✗ Error scheduling exact alarm for slot $slotNumber", e)
            return false
        }
    }

    fun cancelAlarm(alarmId: String): Boolean {
        try {
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = "com.usernode.app.SLOT_ALARM"
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                alarmId.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()

            // Remove from saved alarms
            removeScheduledAlarm(alarmId)

            Log.i(TAG, "Cancelled alarm: $alarmId")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error cancelling alarm", e)
            return false
        }
    }

    fun cancelAllAlarms(): Boolean {
        try {
            val scheduledAlarms = getScheduledAlarms()

            for (alarmId in scheduledAlarms.keys) {
                cancelAlarm(alarmId)
            }

            clearScheduledAlarms()

            Log.i(TAG, "Cancelled all alarms")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error cancelling all alarms", e)
            return false
        }
    }

    private fun saveScheduledAlarm(alarmId: String, slotNumber: Int) {
        val alarms = getScheduledAlarms().toMutableMap()
        alarms[alarmId] = slotNumber
        prefs.edit()
            .putString(SCHEDULED_ALARMS_KEY, alarms.entries.joinToString(",") { "${it.key}:${it.value}" })
            .apply()
    }

    private fun removeScheduledAlarm(alarmId: String) {
        val alarms = getScheduledAlarms().toMutableMap()
        alarms.remove(alarmId)
        prefs.edit()
            .putString(SCHEDULED_ALARMS_KEY, alarms.entries.joinToString(",") { "${it.key}:${it.value}" })
            .apply()
    }

    private fun getScheduledAlarms(): Map<String, Int> {
        val alarmsString = prefs.getString(SCHEDULED_ALARMS_KEY, "") ?: ""
        if (alarmsString.isEmpty()) return emptyMap()

        return alarmsString.split(",")
            .mapNotNull { entry ->
                val parts = entry.split(":")
                if (parts.size == 2) {
                    parts[0] to parts[1].toIntOrNull()
                } else null
            }
            .filter { it.second != null }
            .associate { it.first to it.second!! }
    }

    private fun clearScheduledAlarms() {
        prefs.edit().remove(SCHEDULED_ALARMS_KEY).apply()
    }

    private fun showScheduledNotification(
        alarmId: String,
        slotNumber: Int,
        alarmTimeMs: Long
    ) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    SCHEDULED_CHANNEL_ID,
                    SCHEDULED_CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_LOW
                )
                nm.createNotificationChannel(channel)
            }

            val scheduledText = AlarmTimeFormatter.formatScheduledTime(alarmTimeMs)
            // val message = if (scheduledText != null) {
            //     "Scheduled slot $slotNumber at $scheduledText"
            // } else {
            //     "Scheduled slot $slotNumber"
            // }
            val message = "wakeup at $scheduledText"

            val notification = NotificationCompat.Builder(context, SCHEDULED_CHANNEL_ID)
                .setSmallIcon(R.drawable.launch_background)
                .setContentTitle("Slot alarm scheduled")
                .setContentText(message)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setAutoCancel(true)
                .build()

            nm.notify(alarmId.hashCode(), notification)
        } catch (e: Exception) {
            Log.w(TAG, "[AlarmScheduler] Failed to show scheduled notification", e)
        }
    }

}
