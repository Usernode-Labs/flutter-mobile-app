package com.usernode_labs.usernode.alarm

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.CancellationException

class AlarmWatchdogWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {
    companion object {
        private const val TAG = "usernode/AlarmWatchdogWorker"
    }

    override suspend fun doWork(): Result {
        if (!AlarmWatchdogScheduler.isEnabled(applicationContext)) {
            Log.i(TAG, "Alarm watchdog is disabled; ignoring queued work")
            return Result.success()
        }

        val startedAtMs = System.currentTimeMillis()
        val reason = inputData.getString("reason") ?: "workmanager"
        val attempt = runAttemptCount

        Log.i(TAG, "Alarm watchdog worker started (reason=$reason, attempt=$attempt)")
        AlarmWatchdogScheduler.recordRun(
            applicationContext,
            reason = reason,
            attempt = attempt,
            startedAtMs = startedAtMs
        )

        return try {
            val acknowledged = BackgroundAlarmEngine.sendAlarmEventAwaitAcknowledgement(
                applicationContext,
                "android_workmanager_watchdog",
                mapOf(
                    "reason" to reason,
                    "startedAtMs" to startedAtMs,
                    "runAttemptCount" to attempt
                )
            )
            if (acknowledged) {
                Result.success()
            } else if (!AlarmWatchdogScheduler.isEnabled(applicationContext)) {
                Log.i(TAG, "Alarm watchdog was disabled while running; skipping retry")
                Result.success()
            } else {
                Log.w(TAG, "Alarm watchdog event was not acknowledged; retrying")
                Result.retry()
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "Failed to deliver alarm watchdog event", e)
            Result.retry()
        }
    }
}
