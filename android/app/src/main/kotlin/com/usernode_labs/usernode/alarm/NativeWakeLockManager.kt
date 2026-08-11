package com.usernode_labs.usernode.alarm

import android.content.Context
import android.os.PowerManager
import android.util.Log

/**
 * Holds a native PARTIAL_WAKE_LOCK that does NOT require a foreground Activity.
 *
 * This is intended for background/foreground services to keep the CPU running while work
 * continues even if the UI Activity is destroyed (e.g. "Don't keep activities").
 */
object NativeWakeLockManager {
    private const val TAG = "usernode/NativeWakeLock"
    private const val WAKELOCK_TAG = "usernode:foreground_task"

    @Volatile
    private var wakeLock: PowerManager.WakeLock? = null
    @Volatile
    private var capturedApplicationIncarnation: String? = null

    @Synchronized
    fun acquire(context: Context, applicationIncarnation: String): Boolean {
        if (!ApplicationIncarnationStore(context).matches(applicationIncarnation)) {
            Log.w(TAG, "Refusing wakelock for stale application incarnation")
            return false
        }
        val existing = wakeLock
        if (existing?.isHeld == true &&
            capturedApplicationIncarnation == applicationIncarnation
        ) {
            return true
        }
        if (existing?.isHeld == true) release()

        val pm = context.applicationContext.getSystemService(Context.POWER_SERVICE) as PowerManager
        capturedApplicationIncarnation = applicationIncarnation
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, WAKELOCK_TAG).apply {
            setReferenceCounted(false)
            try {
                acquire()
                Log.i(TAG, "PARTIAL_WAKE_LOCK acquired")
                notifyFlutterWakelockState(isHeld = true)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to acquire PARTIAL_WAKE_LOCK", e)
            }
        }
        return wakeLock?.isHeld == true
    }

    @Synchronized
    fun release() {
        val wl = wakeLock
        if (wl == null) return
        try {
            if (wl.isHeld) {
                wl.release()
                Log.i(TAG, "PARTIAL_WAKE_LOCK released")
                notifyFlutterWakelockState(isHeld = false)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to release PARTIAL_WAKE_LOCK", e)
        } finally {
            wakeLock = null
            capturedApplicationIncarnation = null
        }
    }

    @Synchronized
    fun isHeld(): Boolean = wakeLock?.isHeld == true

    private fun notifyFlutterWakelockState(isHeld: Boolean) {
        try {
            AlarmMethodChannelHandler.getInstance()?.sendEventToFlutter(
                if (isHeld) "android_native_wakelock_acquired" else "android_native_wakelock_released",
                mapOf(
                    "wakelockHeld" to isHeld,
                    ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION to
                        capturedApplicationIncarnation,
                )
            )
        } catch (e: Exception) {
            Log.w(TAG, "Failed to send wakelock state change to Flutter", e)
        }
    }
}
