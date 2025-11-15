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
        Log.i(TAG, "BootRescheduleService created")

        // Start as foreground service with notification
        startForeground(NOTIFICATION_ID, createNotification())
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "BootRescheduleService started")

        // Launch rescheduling in background
        serviceScope.launch {
            try {
                withTimeout(TIMEOUT_MS) {
                    rescheduleAlarms()
                }
            } catch (e: TimeoutCancellationException) {
                Log.e(TAG, "Rescheduling timed out after ${TIMEOUT_MS}ms")
            } catch (e: Exception) {
                Log.e(TAG, "Error during rescheduling", e)
            } finally {
                stopSelfAndCleanup()
            }
        }

        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        super.onDestroy()
        serviceScope.cancel()
        flutterEngine?.destroy()
        flutterEngine = null
        Log.i(TAG, "BootRescheduleService destroyed")
    }

    private suspend fun rescheduleAlarms() = withContext(Dispatchers.Main) {
        Log.i(TAG, "Starting alarm rescheduling...")

        // Create a Flutter engine in background
        flutterEngine = FlutterEngine(applicationContext)

        // Execute Dart entrypoint
        flutterEngine?.dartExecutor?.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )

        // Wait for engine to initialize
        delay(2000)

        // Create method channel to communicate with Flutter
        val channel = MethodChannel(
            flutterEngine!!.dartExecutor.binaryMessenger,
            "com.usernode.app/alarm"
        )

        // Call Flutter to reschedule alarms
        suspendCancellableCoroutine<Unit> { continuation ->
            channel.invokeMethod("rescheduleAfterBoot", null, object : MethodChannel.Result {
                override fun success(result: Any?) {
                    Log.i(TAG, "✓ Alarms rescheduled successfully")
                    continuation.resume(Unit) {}
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    Log.e(TAG, "✗ Failed to reschedule alarms: $errorMessage")
                    continuation.resume(Unit) {}
                }

                override fun notImplemented() {
                    Log.w(TAG, "⚠ rescheduleAfterBoot not implemented in Flutter")
                    continuation.resume(Unit) {}
                }
            })
        }
    }

    private fun stopSelfAndCleanup() {
        Log.i(TAG, "Stopping service and cleaning up...")
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
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
