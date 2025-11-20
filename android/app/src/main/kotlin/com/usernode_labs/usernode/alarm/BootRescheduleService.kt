package com.usernode_labs.usernode.alarm

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import com.usernode_labs.usernode.MainActivity
import com.usernode_labs.usernode.R
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*

/**
 * Background service that handles alarm rescheduling after device reboot
 *
 * This service:
 * 1. Starts as a foreground service (required on Android 8+)
 * 2. Launches a Flutter engine in background
 * 3. Calls Flutter to reschedule all alarms
 * 4. Stops itself when done
 */
class BootRescheduleService : Service() {
    companion object {
        private const val TAG = "BootRescheduleService"
        private const val NOTIFICATION_ID = 9001
        private const val CHANNEL_ID = "boot_reschedule"
        private const val CHANNEL_NAME = "Boot Alarm Rescheduling"
        private const val TIMEOUT_MS = 30000L // 30 seconds max
    }

    private var flutterEngine: FlutterEngine? = null
    private val serviceScope = CoroutineScope(Dispatchers.Main + SupervisorJob())

    override fun onCreate() {
        super.onCreate()
        val bootTime = System.currentTimeMillis()
        Log.i(TAG, "[BootRescheduleService] Service onCreate() - Boot time: $bootTime")
        Log.d(TAG, "[BootRescheduleService] Android API: ${Build.VERSION.SDK_INT}, Manufacturer: ${Build.MANUFACTURER}")

        // Start as foreground service with notification
        try {
            startForeground(NOTIFICATION_ID, createNotification())
            Log.d(TAG, "[BootRescheduleService] Started as foreground service")
        } catch (e: Exception) {
            Log.e(TAG, "[BootRescheduleService] Failed to start foreground service", e)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "[BootRescheduleService] ✓ onStartCommand() - StartId: $startId, Time: ${System.currentTimeMillis()}")
        Log.d(TAG, "[BootRescheduleService] Timeout limit: ${TIMEOUT_MS}ms")

        // Send boot reschedule started event to Flutter
        Log.d(TAG, "[BootRescheduleService] Sending android_boot_reschedule_started event to Flutter")
        AlarmMethodChannelHandler.getInstance()?.sendEventToFlutter("android_boot_reschedule_started", emptyMap())

        // Launch rescheduling in background
        serviceScope.launch {
            val startTime = System.currentTimeMillis()
            Log.d(TAG, "[BootRescheduleService] Launching reschedule coroutine...")

            try {
                withTimeout(TIMEOUT_MS) {
                    rescheduleAlarms()
                }
                val duration = System.currentTimeMillis() - startTime
                Log.i(TAG, "[BootRescheduleService] Rescheduling completed in ${duration}ms")
            } catch (e: TimeoutCancellationException) {
                val duration = System.currentTimeMillis() - startTime
                Log.e(TAG, "[BootRescheduleService] ✗ Rescheduling timed out after ${duration}ms (limit: ${TIMEOUT_MS}ms)")
            } catch (e: Exception) {
                val duration = System.currentTimeMillis() - startTime
                Log.e(TAG, "[BootRescheduleService] ✗ Error during rescheduling after ${duration}ms", e)
            } finally {
                stopSelfAndCleanup()
            }
        }

        Log.d(TAG, "[BootRescheduleService] Returning START_NOT_STICKY")
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? {
        Log.d(TAG, "[BootRescheduleService] onBind() called (returning null)")
        return null
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.i(TAG, "[BootRescheduleService] onDestroy() - Cleaning up resources")

        serviceScope.cancel()
        Log.d(TAG, "[BootRescheduleService] Service scope cancelled")

        flutterEngine?.destroy()
        flutterEngine = null
        Log.d(TAG, "[BootRescheduleService] Flutter engine destroyed")

        Log.i(TAG, "[BootRescheduleService] ✗ Service destroyed")
    }

    private suspend fun rescheduleAlarms() = withContext(Dispatchers.Main) {
        Log.i(TAG, "[BootRescheduleService] Starting alarm rescheduling process...")

        // Create a Flutter engine in background
        Log.d(TAG, "[BootRescheduleService] Creating Flutter engine...")
        flutterEngine = FlutterEngine(applicationContext)
        Log.d(TAG, "[BootRescheduleService] Flutter engine created")

        // Execute Dart entrypoint
        Log.d(TAG, "[BootRescheduleService] Executing Dart entrypoint...")
        flutterEngine?.dartExecutor?.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        Log.d(TAG, "[BootRescheduleService] Dart entrypoint executed")

        // Wait for engine to initialize
        Log.d(TAG, "[BootRescheduleService] Waiting 2s for Flutter engine initialization...")
        delay(2000)
        Log.d(TAG, "[BootRescheduleService] Flutter engine should be ready")

        // Create method channel to communicate with Flutter
        Log.d(TAG, "[BootRescheduleService] Creating method channel...")
        val channel = MethodChannel(
            flutterEngine!!.dartExecutor.binaryMessenger,
            "com.usernode.app/alarm"
        )
        Log.d(TAG, "[BootRescheduleService] Method channel created")

        // Call Flutter to reschedule alarms
        Log.d(TAG, "[BootRescheduleService] Invoking rescheduleAfterBoot method...")
        var slotsRescheduled = 0
        var rescheduleSuccess = false

        suspendCancellableCoroutine<Unit> { continuation ->
            channel.invokeMethod("rescheduleAfterBoot", null, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    Log.i(TAG, "[BootRescheduleService] ✓ Alarms rescheduled successfully - Result: $result")
                    rescheduleSuccess = true
                    // Result might contain number of slots rescheduled
                    if (result is Int) {
                        slotsRescheduled = result
                    }
                    continuation.resume(Unit) {}
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.e(TAG, "[BootRescheduleService] ✗ Failed to reschedule alarms - Code: $errorCode, Message: $errorMessage")
                    rescheduleSuccess = false
                    continuation.resume(Unit) {}
                }

                override fun notImplemented() {
                    Log.w(TAG, "[BootRescheduleService] ⚠ rescheduleAfterBoot not implemented in Flutter")
                    rescheduleSuccess = false
                    continuation.resume(Unit) {}
                }
            })
        }

        // Send boot reschedule completed event to Flutter
        Log.d(TAG, "[BootRescheduleService] Sending android_boot_reschedule_completed event to Flutter")
        val eventData = mapOf(
            "slotsRescheduled" to slotsRescheduled,
            "success" to rescheduleSuccess
        )
        AlarmMethodChannelHandler.getInstance()?.sendEventToFlutter("android_boot_reschedule_completed", eventData)
    }

    private fun stopSelfAndCleanup() {
        Log.i(TAG, "[BootRescheduleService] Stopping service and cleaning up...")

        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
            Log.d(TAG, "[BootRescheduleService] Foreground service stopped")
        } catch (e: Exception) {
            Log.e(TAG, "[BootRescheduleService] Error stopping foreground", e)
        }

        try {
            stopSelf()
            Log.d(TAG, "[BootRescheduleService] stopSelf() called")
        } catch (e: Exception) {
            Log.e(TAG, "[BootRescheduleService] Error calling stopSelf()", e)
        }
    }

    private fun createNotification(): Notification {
        createNotificationChannel()

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Usernode")
            .setContentText("Restoring block production alarms...")
            .setSmallIcon(R.drawable.launch_background)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows when restoring alarms after device reboot"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}
