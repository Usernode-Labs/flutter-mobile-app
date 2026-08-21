package com.usernode_labs.usernode.alarm

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class ForegroundServiceManager(private val context: Context) {
    companion object {
        private const val TAG = "usernode/ForegroundServiceMgr"
    }

    fun startForegroundService(
        title: String,
        message: String,
        globalSlot: Int,
        applicationIncarnation: String,
    ): Boolean {
        return try {
            val intent = Intent(context, SlotMonitoringService::class.java).apply {
                action = SlotMonitoringService.ACTION_START_MONITORING
                putExtra("globalSlot", globalSlot)
                putExtra("title", title)
                putExtra("message", message)
                putExtra(
                    ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION,
                    applicationIncarnation,
                )
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }

            Log.i(TAG, "Started foreground service for global slot $globalSlot")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error starting foreground service", e)
            false
        }
    }

    /**
     * Stops the slot-monitoring foreground service.
     *
     * [destroyBackgroundEngine] must be false when the caller may be the cached
     * headless engine itself: [BackgroundAlarmEngine.destroyCachedEngine] runs
     * synchronously on the main looper, so it would tear down the very engine
     * whose Dart continuation is waiting for this call's result. A scoped
     * sign-out repaired from a headless boot is exactly that case; the engine is
     * retired by the next alarm or activity open instead.
     */
    @JvmOverloads
    fun stopForegroundService(destroyBackgroundEngine: Boolean = true): Boolean {
        return try {
            val intent = Intent(context, SlotMonitoringService::class.java).apply {
                action = SlotMonitoringService.ACTION_STOP_MONITORING
            }

            context.stopService(intent)
            if (destroyBackgroundEngine) {
                BackgroundAlarmEngine.destroyCachedEngine("stopForegroundService")
            } else {
                Log.i(TAG, "Keeping the cached engine alive for the calling boundary")
            }

            Log.i(TAG, "Stopped foreground service")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping foreground service", e)
            false
        }
    }
}
