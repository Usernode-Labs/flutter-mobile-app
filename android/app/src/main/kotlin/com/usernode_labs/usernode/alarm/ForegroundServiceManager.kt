package com.usernode_labs.usernode.alarm

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import com.usernode_labs.usernode.session.SessionAuthorityNative

class ForegroundServiceManager(private val context: Context) {
    companion object {
        private const val TAG = "usernode/ForegroundServiceMgr"
    }

    fun startForegroundService(
        title: String,
        message: String,
        globalSlot: Int,
        owner: RuntimeOwner,
    ): Boolean = NativeSchedulingAuthority.process.runIfAdmitted(
        operation = "foreground.start",
        owner = owner,
        admitted = { SessionAuthorityNative.isBackgroundRuntimeAdmitted(context, it) },
    ) {
        try {
            val intent = Intent(context, SlotMonitoringService::class.java).apply {
                action = SlotMonitoringService.ACTION_START_MONITORING
                putExtra("globalSlot", globalSlot)
                putExtra("title", title)
                putExtra("message", message)
                owner.putInto(this)
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

    fun stopForegroundService(owner: RuntimeOwner): Boolean =
        sendOwnedCommand(SlotMonitoringService.ACTION_STOP_MONITORING, owner)

    fun stopForegroundServiceForReset(): Boolean =
        NativeSchedulingAuthority.process.serialized("foreground.stop_reset") {
            try {
                context.stopService(Intent(context, SlotMonitoringService::class.java))
                true
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping foreground service for reset", e)
                false
            }
        }

    fun startPersistentForegroundService(owner: RuntimeOwner): Boolean =
        NativeSchedulingAuthority.process.runIfAdmitted(
            operation = "foreground.start_persistent",
            owner = owner,
            admitted = { SessionAuthorityNative.isBackgroundRuntimeAdmitted(context, it) },
        ) {
            try {
                val intent = Intent(context, SlotMonitoringService::class.java).apply {
                    action = SlotMonitoringService.ACTION_START_PERSISTENT
                    owner.putInto(this)
                }
                startService(intent)
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start persistent foreground service", e)
                false
            }
        }

    fun stopPersistentForegroundService(owner: RuntimeOwner): Boolean =
        sendOwnedCommand(SlotMonitoringService.ACTION_STOP_PERSISTENT, owner)

    private fun sendOwnedCommand(action: String, owner: RuntimeOwner): Boolean =
        NativeSchedulingAuthority.process.serialized("foreground.command") {
            try {
                val intent = Intent(context, SlotMonitoringService::class.java).apply {
                    this.action = action
                    owner.putInto(this)
                }
                startService(intent)
                true
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send foreground service command", e)
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
