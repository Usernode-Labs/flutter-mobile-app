package com.usernode_labs.usernode.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class AlarmScheduler(
    private val context: Context,
    private val alarmManager: AlarmManager
) {
    companion object {
        private const val TAG = "usernode/AlarmScheduler"
        private const val PREFS_NAME = "alarm_prefs"
        private const val SCHEDULED_ALARMS_KEY = "scheduled_alarms"
    }

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun scheduleExactAlarm(
        alarmId: String,
        alarmTimeMs: Long,
        slotNumber: Int,
        data: Map<String, Any>
    ): Boolean {
        try {
            Log.d(TAG, "[AlarmScheduler] Attempting to schedule alarm - ID: $alarmId, Slot: $slotNumber, Time: $alarmTimeMs")

            // SET_ALARM_CLOCK doesn't require runtime permission - always available
            Log.d(TAG, "[AlarmScheduler] Using SET_ALARM_CLOCK API - no permission check needed (API ${Build.VERSION.SDK_INT})")

            // Create intent for alarm receiver
            Log.d(TAG, "[AlarmScheduler] Creating PendingIntent for alarm broadcast")
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = "com.usernode.app.SLOT_ALARM"
                putExtra("alarmId", alarmId)
                putExtra("slotNumber", slotNumber)
                putExtra("alarmTimeMs", alarmTimeMs)
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

            // Schedule alarm clock - visible to user, highest priority
            val currentTime = System.currentTimeMillis()
            val delayMs = alarmTimeMs - currentTime
            Log.d(TAG, "[AlarmScheduler] Current time: $currentTime, Alarm time: $alarmTimeMs, Delay: ${delayMs}ms (${delayMs/1000}s)")

            Log.d(TAG, "[AlarmScheduler] Using setAlarmClock for slot $slotNumber - will appear in system alarm list")
            val alarmClockInfo = AlarmManager.AlarmClockInfo(
                alarmTimeMs,
                pendingIntent // Show intent when alarm is tapped in system UI
            )
            alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)

            // Save alarm ID for tracking
            saveScheduledAlarm(alarmId, slotNumber)
            Log.d(TAG, "[AlarmScheduler] Alarm saved to SharedPreferences")

            Log.i(TAG, "[AlarmScheduler] ✓ Successfully scheduled alarm clock for slot $slotNumber at $alarmTimeMs (in ${delayMs/1000}s)")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "[AlarmScheduler] ✗ Error scheduling alarm clock for slot $slotNumber", e)
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
}
