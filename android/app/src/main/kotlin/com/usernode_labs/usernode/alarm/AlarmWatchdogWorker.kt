package com.usernode_labs.usernode.alarm

import android.content.Context
import android.util.Log
import androidx.work.Worker
import androidx.work.WorkerParameters

class AlarmWatchdogWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {
    companion object {
        private const val TAG = "usernode/AlarmWatchdogWorker"
    }

    override fun doWork(): Result {
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
            BackgroundAlarmEngine.sendAlarmEvent(
                applicationContext,
                "android_workmanager_watchdog",
                mapOf(
                    "reason" to reason,
                    "startedAtMs" to startedAtMs,
                    "runAttemptCount" to attempt
                )
            )
            Result.success()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to deliver alarm watchdog event", e)
            Result.retry()
        }
    }
}
