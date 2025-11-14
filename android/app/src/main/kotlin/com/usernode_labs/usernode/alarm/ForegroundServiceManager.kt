package com.usernode_labs.usernode.alarm

import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class ForegroundServiceManager(private val context: Context) {
    companion object {
        private const val TAG = "ForegroundServiceMgr"
    }

    fun startForegroundService(title: String, message: String, slotNumber: Int): Boolean {
        return try {
            val intent = Intent(context, SlotMonitoringService::class.java).apply {
                action = SlotMonitoringService.ACTION_START_MONITORING
                putExtra("slotNumber", slotNumber)
                putExtra("title", title)
                putExtra("message", message)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }

            Log.i(TAG, "Started foreground service for slot $slotNumber")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error starting foreground service", e)
            false
        }
    }

    fun stopForegroundService(): Boolean {
        return try {
            val intent = Intent(context, SlotMonitoringService::class.java).apply {
                action = SlotMonitoringService.ACTION_STOP_MONITORING
            }

            context.stopService(intent)

            Log.i(TAG, "Stopped foreground service")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping foreground service", e)
            false
        }
    }
}
