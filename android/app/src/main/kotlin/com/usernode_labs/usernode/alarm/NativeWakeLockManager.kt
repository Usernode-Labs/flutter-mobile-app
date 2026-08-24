package com.usernode_labs.usernode.alarm

import android.content.Context
import android.os.PowerManager
import android.util.Log
import com.usernode_labs.usernode.session.SessionAuthorityNative

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
    private var capturedOwner: RuntimeOwner? = null

    fun acquire(context: Context, owner: RuntimeOwner): Boolean =
        NativeSchedulingAuthority.process.runIfAdmitted(
            operation = "wakelock.acquire",
            owner = owner,
            admitted = { SessionAuthorityNative.isBackgroundRuntimeAdmitted(context, it) },
        ) {
            val existing = wakeLock
            if (existing?.isHeld == true && capturedOwner == owner) {
                return@runIfAdmitted true
            }
            if (existing?.isHeld == true) releaseLocked()

            val pm = context.applicationContext
                .getSystemService(Context.POWER_SERVICE) as PowerManager
            capturedOwner = owner
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
            wakeLock?.isHeld == true
        }

    fun release(owner: RuntimeOwner): Boolean =
        NativeSchedulingAuthority.process.runIfOwned(
            operation = "wakelock.release",
            owner = owner,
            resourceOwner = { capturedOwner },
        ) {
            releaseLocked()
            true
        }

    fun releaseForReset() {
        NativeSchedulingAuthority.process.serialized("wakelock.release_reset") {
            releaseLocked()
        }
    }

    private fun releaseLocked() {
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
            capturedOwner = null
        }
    }

    fun isHeld(): Boolean =
        NativeSchedulingAuthority.process.serialized("wakelock.is_held") {
            wakeLock?.isHeld == true
        }

    private fun notifyFlutterWakelockState(isHeld: Boolean) {
        try {
            AlarmMethodChannelHandler.getInstance()?.sendEventToFlutter(
                if (isHeld) "android_native_wakelock_acquired" else "android_native_wakelock_released",
                mapOf(
                    "wakelockHeld" to isHeld,
                ) + (capturedOwner?.toMap() ?: emptyMap()),
            )
        } catch (e: Exception) {
            Log.w(TAG, "Failed to send wakelock state change to Flutter", e)
        }
    }
}
