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
    ): Boolean = NativeSchedulingAuthority.process.runIfCurrent(
        operation = "foreground.start",
        captured = applicationIncarnation,
        current = { ApplicationIncarnationStore(context).current() },
        onRejected = {
            Log.w(TAG, "Refusing foreground start for stale application incarnation")
        },
    ) {
        try {
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
    fun stopForegroundService(
        destroyBackgroundEngine: Boolean,
        applicationIncarnation: String,
    ): Boolean =
        NativeSchedulingAuthority.process.runIfCurrent(
            operation = "foreground.stop",
            captured = applicationIncarnation,
            current = { ApplicationIncarnationStore(context).current() },
            onRejected = {
                Log.w(TAG, "Refusing foreground stop for stale application incarnation")
            },
        ) {
            stopForegroundServiceLocked(destroyBackgroundEngine)
        }

    fun stopForegroundServiceForReset(
        destroyBackgroundEngine: Boolean = true,
    ): Boolean = NativeSchedulingAuthority.process.serialized("foreground.stop_reset") {
        stopForegroundServiceLocked(destroyBackgroundEngine)
    }

    fun startPersistentForegroundService(applicationIncarnation: String): Boolean =
        NativeSchedulingAuthority.process.runIfCurrent(
            operation = "foreground.start_persistent",
            captured = applicationIncarnation,
            current = { ApplicationIncarnationStore(context).current() },
            onRejected = {
                Log.w(TAG, "Refusing persistent start for stale application incarnation")
            },
        ) {
            try {
                val intent = Intent(context, SlotMonitoringService::class.java).apply {
                    action = SlotMonitoringService.ACTION_START_PERSISTENT
                    putExtra(
                        ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION,
                        applicationIncarnation,
                    )
                }
                startService(intent)
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start persistent foreground service", e)
                false
            }
        }

    fun stopPersistentForegroundService(applicationIncarnation: String): Boolean =
        NativeSchedulingAuthority.process.runIfCurrent(
            operation = "foreground.stop_persistent",
            captured = applicationIncarnation,
            current = { ApplicationIncarnationStore(context).current() },
            onRejected = {
                Log.w(TAG, "Refusing persistent stop for stale application incarnation")
            },
        ) {
            stopPersistentForegroundServiceLocked()
        }

    private fun stopForegroundServiceLocked(destroyBackgroundEngine: Boolean): Boolean {
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

    private fun stopPersistentForegroundServiceLocked(): Boolean {
        return try {
            val intent = Intent(context, SlotMonitoringService::class.java).apply {
                action = SlotMonitoringService.ACTION_STOP_PERSISTENT
            }
            context.startService(intent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to stop persistent foreground service", e)
            false
        }
    }

    private fun startService(intent: Intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(intent)
        } else {
            context.startService(intent)
        }
    }
}
