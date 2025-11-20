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
        private const val TAG = "AlarmScheduler"
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
                putExtra("alarmTimeMs", alarmTimeMs)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                alarmId.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            Log.d(TAG, "[AlarmScheduler] PendingIntent created with hashCode: ${alarmId.hashCode()}")

            // Schedule exact alarm
            val currentTime = System.currentTimeMillis()
            val delayMs = alarmTimeMs - currentTime
            Log.d(TAG, "[AlarmScheduler] Current time: $currentTime, Alarm time: $alarmTimeMs, Delay: ${delayMs}ms (${delayMs/1000}s)")

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Log.d(TAG, "[AlarmScheduler] Using setExactAndAllowWhileIdle (API >= 23)")
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    alarmTimeMs,
                    pendingIntent
                )
            } else {
                Log.d(TAG, "[AlarmScheduler] Using setExact (API < 23)")
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    alarmTimeMs,
                    pendingIntent
                )
            }

            // Save alarm ID for tracking
            saveScheduledAlarm(alarmId, slotNumber)
            Log.d(TAG, "[AlarmScheduler] Alarm saved to SharedPreferences")

            Log.i(TAG, "[AlarmScheduler] ✓ Successfully scheduled exact alarm for slot $slotNumber at $alarmTimeMs (in ${delayMs/1000}s)")
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
}
