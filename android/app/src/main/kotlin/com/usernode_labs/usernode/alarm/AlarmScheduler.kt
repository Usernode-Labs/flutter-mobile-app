package com.usernode_labs.usernode.alarm

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import com.usernode_labs.usernode.R
import com.usernode_labs.usernode.session.SessionAuthorityNative

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
        private const val SCHEDULED_NOTIFICATION_ID = 1002
    }

    private val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    private val alarmStateStore = AlarmStateStore(context)

    fun scheduleExactAlarm(
        alarmId: String,
        delayMs: Long,
        globalSlot: Int,
        data: Map<String, Any>,
        owner: RuntimeOwner,
    ): Boolean = NativeSchedulingAuthority.process.runIfAdmitted(
            operation = "alarm.schedule",
            owner = owner,
            admitted = { SessionAuthorityNative.isBackgroundRuntimeAdmitted(context, it) },
        ) {
            scheduleExactAlarmLocked(
                alarmId,
                delayMs,
                globalSlot,
                data + owner.toMap(),
            )
        }

    private fun scheduleExactAlarmLocked(
        alarmId: String,
        delayMs: Long,
        globalSlot: Int,
        data: Map<String, Any>,
    ): Boolean {
        try {
            Log.d(TAG, "[AlarmScheduler] Attempting to schedule alarm - ID: $alarmId, GlobalSlot: $globalSlot, Delay: $delayMs")

            val currentTime = System.currentTimeMillis()
            val scheduledElapsedRealtimeMs = SystemClock.elapsedRealtime()
            val effectiveDelayMs = delayMs.coerceAtLeast(0L)
            val triggerAtMs = currentTime + effectiveDelayMs
            val triggerElapsedRealtimeMs = scheduledElapsedRealtimeMs + effectiveDelayMs

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val canSchedule = alarmManager.canScheduleExactAlarms()
                Log.d(TAG, "[AlarmScheduler] Exact alarm permission status: $canSchedule (API ${Build.VERSION.SDK_INT})")
                if (!canSchedule) {
                    Log.w(TAG, "[AlarmScheduler] Cannot schedule exact alarms - permission not granted")
                    alarmStateStore.recordScheduleFailed(
                        alarmId = alarmId,
                        globalSlot = globalSlot,
                        triggerAtMs = triggerAtMs,
                        scheduledAtMs = currentTime,
                        scheduledElapsedRealtimeMs = scheduledElapsedRealtimeMs,
                        triggerElapsedRealtimeMs = triggerElapsedRealtimeMs,
                        requestedDelayMs = delayMs,
                        effectiveDelayMs = effectiveDelayMs,
                        data = data,
                        failureReason = "exact_alarm_permission_denied",
                    )
                    return false
                }
            } else {
                Log.d(TAG, "[AlarmScheduler] No permission check needed (API ${Build.VERSION.SDK_INT} < 31)")
            }

            Log.d(TAG, "[AlarmScheduler] Creating PendingIntent for alarm broadcast")
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = "com.usernode.app.SLOT_ALARM"
                putExtra("alarmId", alarmId)
                putExtra("globalSlot", globalSlot)
                putExtra("alarmTimeMs", triggerAtMs)
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
                putExtra("nativeScheduledAtMs", currentTime)
                putExtra("scheduledElapsedRealtimeMs", scheduledElapsedRealtimeMs)
                putExtra("nativeTriggerAtMs", triggerAtMs)
                putExtra("triggerElapsedRealtimeMs", triggerElapsedRealtimeMs)
                putExtra("requestedDelayMs", delayMs)
                putExtra("effectiveDelayMs", effectiveDelayMs)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                alarmId.hashCode(),
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            Log.d(TAG, "[AlarmScheduler] PendingIntent created with hashCode: ${alarmId.hashCode()}")

            Log.d(
                TAG,
                "[AlarmScheduler] Current time: $currentTime, Trigger at: $triggerAtMs, Delay: ${effectiveDelayMs}ms (${effectiveDelayMs/1000}s)",
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                Log.d(TAG, "[AlarmScheduler] Using setExactAndAllowWhileIdle (API >= 23)")
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMs,
                    pendingIntent,
                )
            } else {
                Log.d(TAG, "[AlarmScheduler] Using setExact (API < 23)")
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerAtMs,
                    pendingIntent,
                )
            }

            saveScheduledAlarm(alarmId, globalSlot)
            alarmStateStore.recordScheduled(
                alarmId = alarmId,
                globalSlot = globalSlot,
                triggerAtMs = triggerAtMs,
                scheduledAtMs = currentTime,
                scheduledElapsedRealtimeMs = scheduledElapsedRealtimeMs,
                triggerElapsedRealtimeMs = triggerElapsedRealtimeMs,
                requestedDelayMs = delayMs,
                effectiveDelayMs = effectiveDelayMs,
                data = data,
            )
            Log.d(TAG, "[AlarmScheduler] Alarm saved to SharedPreferences")

            showScheduledNotification(globalSlot, triggerAtMs)
            Log.i(TAG, "[AlarmScheduler] ✓ Successfully scheduled exact alarm for global slot $globalSlot at $triggerAtMs (in ${effectiveDelayMs/1000}s)")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "[AlarmScheduler] ✗ Error scheduling exact alarm for global slot $globalSlot", e)
            return false
        }
    }

    fun cancelAlarm(alarmId: String, owner: RuntimeOwner): Boolean =
        NativeSchedulingAuthority.process.runIfOwned(
            operation = "alarm.cancel",
            owner = owner,
            resourceOwner = { alarmStateStore.owner(alarmId) },
        ) {
            cancelAlarmLocked(alarmId, "cancel_alarm")
        }

    fun cancelAllAlarms(owner: RuntimeOwner): Boolean =
        NativeSchedulingAuthority.process.serialized("alarm.cancel_all") {
            var succeeded = true
            for (alarmId in getScheduledAlarms().keys) {
                if (alarmStateStore.owner(alarmId) == owner) {
                    succeeded = cancelAlarmLocked(alarmId, "cancel_all_alarms") && succeeded
                }
            }
            succeeded
        }

    fun cancelAllAlarmsForReset(reason: String): Boolean =
        NativeSchedulingAuthority.process.serialized("alarm.cancel_all_reset") {
            cancelAllAlarmsLocked(reason)
        }

    private fun cancelAllAlarmsLocked(reason: String): Boolean {
        try {
            val scheduledAlarms = getScheduledAlarms()

            for (alarmId in scheduledAlarms.keys) {
                cancelAlarmLocked(alarmId, reason)
            }

            clearScheduledAlarms()

            Log.i(TAG, "Cancelled ${scheduledAlarms.size} tracked alarms (reason=$reason)")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error cancelling all alarms", e)
            return false
        }
    }

    fun hasScheduledAlarm(alarmId: String): Boolean =
        NativeSchedulingAuthority.process.serialized("alarm.has_scheduled") {
            try {
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = "com.usernode.app.SLOT_ALARM"
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                alarmId.hashCode(),
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )

            val exists = pendingIntent != null
            Log.d(TAG, "[AlarmScheduler] PendingIntent exists for $alarmId: $exists")
            exists
            } catch (e: Exception) {
                Log.e(TAG, "[AlarmScheduler] Error checking alarm existence for $alarmId", e)
                false
            }
        }

    fun getAlarmDebugState(alarmId: String): Map<String, Any?> {
        return alarmStateStore.getState(
            alarmId = alarmId,
            pendingIntentExists = hasScheduledAlarm(alarmId),
            canScheduleExactAlarms = canScheduleExactAlarms()
        )
    }

    private fun cancelAlarmLocked(alarmId: String, reason: String): Boolean {
        try {
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = "com.usernode.app.SLOT_ALARM"
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                alarmId.hashCode(),
                intent,
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            )

            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
            }

            removeScheduledAlarm(alarmId)
            alarmStateStore.recordCancelled(
                alarmId = alarmId,
                reason = reason,
                cancelledAtMs = System.currentTimeMillis()
            )

            Log.i(TAG, "Cancelled alarm: $alarmId")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error cancelling alarm", e)
            return false
        }
    }

    private fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true
        }
    }

    private fun saveScheduledAlarm(alarmId: String, globalSlot: Int) {
        val alarms = getScheduledAlarms().toMutableMap()
        alarms[alarmId] = globalSlot
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
        globalSlot: Int,
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
            val message = if (scheduledText != null) {
                "Slot $globalSlot wakeup at $scheduledText"
            } else {
                "Slot $globalSlot wakeup scheduled"
            }

            val notification = NotificationCompat.Builder(context, SCHEDULED_CHANNEL_ID)
                .setSmallIcon(R.drawable.launch_background)
                .setContentTitle("Slot alarm scheduled")
                .setContentText(message)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setAutoCancel(true)
                .build()

            nm.notify(SCHEDULED_NOTIFICATION_ID, notification)
        } catch (e: Exception) {
            Log.w(TAG, "[AlarmScheduler] Failed to show scheduled notification", e)
        }
    }

}
