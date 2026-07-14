package com.usernode_labs.usernode.alarm

import android.content.Context
import android.util.Log
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.workDataOf
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

object AlarmWatchdogScheduler {
    private const val TAG = "usernode/AlarmWatchdog"
    private const val PERIODIC_WORK_NAME = "usernode_alarm_watchdog_periodic"
    private const val ONE_TIME_WORK_NAME = "usernode_alarm_watchdog_once"
    private const val WATCHDOG_TAG = "usernode_alarm_watchdog"
    private const val PREFS_NAME = "alarm_watchdog_prefs"
    private const val LAST_RUN_AT_MS_KEY = "last_run_at_ms"
    private const val LAST_RUN_REASON_KEY = "last_run_reason"
    private const val LAST_RUN_ATTEMPT_KEY = "last_run_attempt"
    private const val PERIODIC_CONFIGURED_KEY = "periodic_configured"
    private const val PERIODIC_SCHEDULED_AT_MS_KEY = "periodic_scheduled_at_ms"
    private const val PERIODIC_REASON_KEY = "periodic_reason"
    private const val ONE_TIME_ENQUEUED_AT_MS_KEY = "one_time_enqueued_at_ms"
    private const val ONE_TIME_REASON_KEY = "one_time_reason"
    private const val CANCELLED_AT_MS_KEY = "cancelled_at_ms"

    fun ensurePeriodic(context: Context, reason: String): Boolean {
        return try {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()
            // WorkManager requires periodic work to repeat at least every
            // 15 minutes. This is not an initial delay; immediate recovery
            // uses enqueueOneTime().
            val request = PeriodicWorkRequestBuilder<AlarmWatchdogWorker>(
                15,
                TimeUnit.MINUTES
            )
                .setInputData(workDataOf("reason" to reason))
                .setConstraints(constraints)
                .setBackoffCriteria(
                    BackoffPolicy.EXPONENTIAL,
                    10,
                    TimeUnit.MINUTES
                )
                .addTag(WATCHDOG_TAG)
                .build()

            WorkManager.getInstance(context.applicationContext)
                .enqueueUniquePeriodicWork(
                    PERIODIC_WORK_NAME,
                    ExistingPeriodicWorkPolicy.KEEP,
                    request
                )
            prefs(context)
                .edit()
                .putBoolean(PERIODIC_CONFIGURED_KEY, true)
                .putLong(PERIODIC_SCHEDULED_AT_MS_KEY, System.currentTimeMillis())
                .putString(PERIODIC_REASON_KEY, reason)
                .apply()
            Log.i(TAG, "Ensured periodic alarm watchdog (reason=$reason)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to ensure periodic alarm watchdog", e)
            false
        }
    }

    fun enqueueOneTime(context: Context, reason: String): Boolean {
        if (!isEnabled(context)) {
            Log.i(TAG, "Ignoring one-time watchdog request while disabled (reason=$reason)")
            return false
        }

        return try {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()
            val request = OneTimeWorkRequestBuilder<AlarmWatchdogWorker>()
                .setInputData(workDataOf("reason" to reason))
                .setConstraints(constraints)
                .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                .addTag(WATCHDOG_TAG)
                .build()

            WorkManager.getInstance(context.applicationContext)
                .enqueueUniqueWork(
                    ONE_TIME_WORK_NAME,
                    ExistingWorkPolicy.REPLACE,
                    request
                )
            prefs(context)
                .edit()
                .putLong(ONE_TIME_ENQUEUED_AT_MS_KEY, System.currentTimeMillis())
                .putString(ONE_TIME_REASON_KEY, reason)
                .apply()
            Log.i(TAG, "Queued one-time alarm watchdog (reason=$reason)")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to queue one-time alarm watchdog", e)
            false
        }
    }

    fun cancel(context: Context): Boolean {
        return try {
            val workManager = WorkManager.getInstance(context.applicationContext)
            workManager.cancelUniqueWork(PERIODIC_WORK_NAME)
            workManager.cancelUniqueWork(ONE_TIME_WORK_NAME)
            prefs(context)
                .edit()
                .putBoolean(PERIODIC_CONFIGURED_KEY, false)
                .putLong(CANCELLED_AT_MS_KEY, System.currentTimeMillis())
                .apply()
            Log.i(TAG, "Cancelled alarm watchdog work")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel alarm watchdog work", e)
            false
        }
    }

    fun isEnabled(context: Context): Boolean =
        prefs(context).getBoolean(PERIODIC_CONFIGURED_KEY, false)

    suspend fun state(context: Context): Map<String, Any?> = withContext(Dispatchers.IO) {
        val prefs = prefs(context)
        val persistedState = mapOf<String, Any?>(
            "periodicWorkName" to PERIODIC_WORK_NAME,
            "oneTimeWorkName" to ONE_TIME_WORK_NAME,
            "periodicConfigured" to prefs.getBoolean(PERIODIC_CONFIGURED_KEY, false),
            "periodicScheduledAtMs" to prefs.getLong(PERIODIC_SCHEDULED_AT_MS_KEY, 0L),
            "periodicReason" to prefs.getString(PERIODIC_REASON_KEY, null),
            "oneTimeEnqueuedAtMs" to prefs.getLong(ONE_TIME_ENQUEUED_AT_MS_KEY, 0L),
            "oneTimeReason" to prefs.getString(ONE_TIME_REASON_KEY, null),
            "cancelledAtMs" to prefs.getLong(CANCELLED_AT_MS_KEY, 0L),
            "lastRunAtMs" to prefs.getLong(LAST_RUN_AT_MS_KEY, 0L),
            "lastRunReason" to prefs.getString(LAST_RUN_REASON_KEY, null),
            "lastRunAttempt" to prefs.getInt(LAST_RUN_ATTEMPT_KEY, 0)
        )

        try {
            val workManager = WorkManager.getInstance(context.applicationContext)
            val periodic = workManager.getWorkInfosForUniqueWork(PERIODIC_WORK_NAME).get()
            val oneTime = workManager.getWorkInfosForUniqueWork(ONE_TIME_WORK_NAME).get()
            persistedState + mapOf<String, Any?>(
                "workManagerQuerySucceeded" to true,
                "periodicExists" to periodic.isNotEmpty(),
                "periodicActive" to periodic.any { it.state.isActive },
                "periodic" to periodic.map(::workInfoState),
                "oneTimeExists" to oneTime.isNotEmpty(),
                "oneTimeActive" to oneTime.any { it.state.isActive },
                "oneTime" to oneTime.map(::workInfoState)
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to query WorkManager alarm watchdog state", e)
            persistedState + mapOf<String, Any?>(
                "workManagerQuerySucceeded" to false,
                "workManagerQueryError" to (e.message ?: e.javaClass.simpleName)
            )
        }
    }

    fun recordRun(context: Context, reason: String, attempt: Int, startedAtMs: Long) {
        prefs(context)
            .edit()
            .putLong(LAST_RUN_AT_MS_KEY, startedAtMs)
            .putString(LAST_RUN_REASON_KEY, reason)
            .putInt(LAST_RUN_ATTEMPT_KEY, attempt)
            .apply()
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private val WorkInfo.State.isActive: Boolean
        get() = this == WorkInfo.State.ENQUEUED ||
            this == WorkInfo.State.RUNNING ||
            this == WorkInfo.State.BLOCKED

    private fun workInfoState(info: WorkInfo): Map<String, Any?> = mapOf(
        "id" to info.id.toString(),
        "state" to info.state.name,
        "runAttemptCount" to info.runAttemptCount,
        "generation" to info.generation,
        "nextScheduleTimeMs" to info.nextScheduleTimeMillis,
        "stopReason" to info.stopReason
    )
}
