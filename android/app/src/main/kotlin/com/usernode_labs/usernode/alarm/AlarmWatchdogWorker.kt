package com.usernode_labs.usernode.alarm

import android.content.Context
import android.util.Log
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import com.usernode_labs.usernode.session.NativeProducerWakeCoordinator
import com.usernode_labs.usernode.session.ProducerWakeOutcome
import com.usernode_labs.usernode.session.ProducerWakeSource

class AlarmWatchdogWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {
    companion object {
        private const val TAG = "usernode/AlarmWatchdogWorker"
    }

    override suspend fun doWork(): Result {
        val applicationIncarnation = inputData.getString(
            ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION,
        )
        val incarnationStore = ApplicationIncarnationStore(applicationContext)
        if (!incarnationStore.matches(applicationIncarnation)) {
            Log.i(TAG, "Ignoring watchdog work for stale application incarnation")
            return Result.success()
        }
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
            val outcome = withContext(Dispatchers.IO) {
                NativeProducerWakeCoordinator.runBlocking(
                    applicationContext,
                    ProducerWakeSource.WATCHDOG,
                )
            }
            if (outcome != ProducerWakeOutcome.Retry) {
                Result.success()
            } else if (!incarnationStore.matches(applicationIncarnation)) {
                Log.i(TAG, "Application incarnation changed while watchdog ran")
                Result.success()
            } else if (!AlarmWatchdogScheduler.isEnabled(applicationContext)) {
                Log.i(TAG, "Alarm watchdog was disabled while running; skipping retry")
                Result.success()
            } else {
                Log.w(TAG, "Native producer watchdog requested a retry")
                Result.retry()
            }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.e(TAG, "Failed to deliver alarm watchdog event", e)
            if (incarnationStore.matches(applicationIncarnation)) {
                Result.retry()
            } else {
                Result.success()
            }
        }
    }
}
