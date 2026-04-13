package com.usernode_labs.usernode.alarm

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

/**
 * Android-side handler for the `com.usernode.app/alarm` channel.
 *
 * This is **not Activity-focused**:
 * - Constructed with an application [Context] so it can exist in background-only processes.
 * - Optionally an [Activity] can be attached for UI-only operations (permission prompts / settings).
 */
class AlarmMethodChannelHandler(context: Context) {

    private val appContext: Context = context.applicationContext

    // Activity is optional; only required for UI-only flows like permission prompts.
    @Volatile
    private var activityRef: WeakReference<Activity>? = null

    private val alarmManager: AlarmManager = appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val alarmScheduler: AlarmScheduler = AlarmScheduler(appContext, alarmManager)
    private val foregroundServiceManager: ForegroundServiceManager = ForegroundServiceManager(appContext)
    private val powerManager: PowerManager = appContext.getSystemService(Context.POWER_SERVICE) as PowerManager

    private var methodChannel: MethodChannel? = null

    companion object {
        private const val TAG = "usernode/AlarmMethodChannelHandler"
        private const val REQUEST_POST_NOTIFICATIONS = 1001

        // Singleton instance for accessing from services/receivers
        @Volatile
        private var instance: AlarmMethodChannelHandler? = null

        fun getInstance(): AlarmMethodChannelHandler? = instance

        /**
         * Get the singleton if present, otherwise create it.
         *
         * Safe to call from services/receivers where no Activity exists.
         */
        fun getOrCreate(context: Context): AlarmMethodChannelHandler {
            val existing = instance
            if (existing != null) return existing
            synchronized(this) {
                val again = instance
                if (again != null) return again
                return AlarmMethodChannelHandler(context).also { instance = it }
            }
        }

        internal fun setInstance(handler: AlarmMethodChannelHandler) {
            instance = handler
        }
    }

    init {
        setInstance(this)
        Log.d(TAG, "Handler initialized")
    }

    fun attachActivity(activity: Activity) {
        activityRef = WeakReference(activity)
        Log.d(TAG, "Activity attached (${activity::class.java.simpleName})")
    }

    fun detachActivity(activity: Activity? = null) {
        val current = activityRef?.get()
        if (activity == null || current === activity) {
            activityRef = null
            Log.d(TAG, "Activity detached")
        }
    }

    /**
     * Check if an Activity is currently attached.
     * 
     * @return true if an Activity is attached and not garbage collected, false otherwise
     */
    fun isActivityAttached(): Boolean {
        return activityRef?.get() != null
    }

    /// Set the method channel for bidirectional communication
    fun setMethodChannel(channel: MethodChannel) {
        methodChannel = channel
        Log.d(TAG, "Method channel set")
    }

    fun clearMethodChannel(reason: String) {
        methodChannel = null
        Log.d(TAG, "Method channel cleared (reason=$reason)")
    }

    /// Send a block production event to Flutter
    fun sendEventToFlutter(eventType: String, eventData: Map<String, Any?>) {
        if (methodChannel == null) {
            Log.w(TAG, "Cannot send event '$eventType' - method channel not set")
            return
        }

        Log.d(TAG, "Sending event to Flutter: $eventType")

        val args = mapOf(
            "eventType" to eventType,
            "eventData" to eventData
        )

        methodChannel?.invokeMethod("onBlockProductionEvent", args)
    }

    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasExactAlarmPermission" -> {
                result.success(hasExactAlarmPermission())
            }
            "requestExactAlarmPermission" -> {
                result.success(requestExactAlarmPermission())
            }
            "hasPostNotificationsPermission" -> {
                result.success(hasPostNotificationsPermission())
            }
            "requestPostNotificationsPermission" -> {
                result.success(requestPostNotificationsPermission())
            }
            "requestBatteryOptimizationExemption" -> {
                result.success(requestBatteryOptimizationExemption())
            }
            "scheduleExactAlarm" -> {
                val alarmId = call.argument<String>("alarmId")
                val delayMs = call.argument<Number>("delayMs")?.toLong()
                val slotNumber = call.argument<Int>("slotNumber")
                val data = call.argument<Map<String, Any>>("data")

                if (alarmId == null || slotNumber == null || delayMs == null) {
                    result.error("INVALID_ARGS", "Missing required delayMs argument", null)
                    return
                }

                val success = alarmScheduler.scheduleExactAlarm(
                    alarmId = alarmId,
                    delayMs = delayMs,
                    slotNumber = slotNumber,
                    data = data ?: emptyMap()
                )
                result.success(success)
            }
            "cancelAlarm" -> {
                val alarmId = call.argument<String>("alarmId")
                if (alarmId == null) {
                    result.error("INVALID_ARGS", "Missing alarmId", null)
                    return
                }

                val success = alarmScheduler.cancelAlarm(alarmId)
                result.success(success)
            }
            "cancelAllAlarms" -> {
                val success = alarmScheduler.cancelAllAlarms()
                result.success(success)
            }
            "startForegroundService" -> {
                val title = call.argument<String>("title")
                val message = call.argument<String>("message")
                val slotNumber = call.argument<Int>("slotNumber")

                if (title == null || message == null || slotNumber == null) {
                    result.error("INVALID_ARGS", "Missing required arguments", null)
                    return
                }

                val success = foregroundServiceManager.startForegroundService(
                    title = title,
                    message = message,
                    slotNumber = slotNumber
                )
                result.success(success)
            }
            "stopForegroundService" -> {
                val success = foregroundServiceManager.stopForegroundService()
                result.success(success)
            }
            "startPersistentForegroundService" -> {
                Log.d(TAG, "Starting persistent foreground service")
                val intent = Intent(appContext, SlotMonitoringService::class.java).apply {
                    action = SlotMonitoringService.ACTION_START_PERSISTENT
                }
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        appContext.startForegroundService(intent)
                    } else {
                        appContext.startService(intent)
                    }
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start persistent foreground service", e)
                    result.success(false)
                }
            }
            "stopPersistentForegroundService" -> {
                Log.d(TAG, "Stopping persistent foreground service")
                val intent = Intent(appContext, SlotMonitoringService::class.java).apply {
                    action = SlotMonitoringService.ACTION_STOP_PERSISTENT
                }
                try {
                    appContext.startService(intent)
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to stop persistent foreground service", e)
                    result.success(false)
                }
            }
            "isPersistentForegroundRunning" -> {
                val isRunning = SlotMonitoringService.isPersistentModeActive
                Log.d(TAG, "isPersistentForegroundRunning: $isRunning")
                result.success(isRunning)
            }
            "isBatteryOptimizationDisabled" -> {
                result.success(isBatteryOptimizationDisabled())
            }
            "openBatterySettings" -> {
                result.success(openBatteryOptimizationSettings())
            }
            "getDeviceManufacturer" -> {
                result.success(Build.MANUFACTURER)
            }
            "isForegroundServiceRunning" -> {
                result.success(isForegroundServiceRunning())
            }
            "isWakelockHeld" -> {
                result.success(isWakelockHeld())
            }
            "getBackgroundTaskStats" -> {
                result.success(getBackgroundTaskStats())
            }
            "incrementBackgroundTaskCount" -> {
                incrementBackgroundTaskCount()
                result.success(true)
            }
            "acquireWakelock" -> {
                NativeWakeLockManager.acquire(appContext)
                result.success(true)
            }
            "releaseWakelock" -> {
                NativeWakeLockManager.release()
                result.success(true)

                // // Treat wakelock release as "app suspended" for engine lifecycle:
                // // destroy engine + remove from cache so next open/alarm starts fresh.
                // Handler(Looper.getMainLooper()).post {
                //     BackgroundAlarmEngine.destroyCachedEngine("wakelock_release")
                // }
            }
            "restartActivity" -> {
                result.success(restartActivity())
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun restartActivity(): Boolean {
        val activity = activityRef?.get()
        if (activity == null) {
            Log.w(TAG, "Cannot restart activity - no Activity attached")
            return false
        }

        return try {
            val launchIntent = appContext.packageManager.getLaunchIntentForPackage(appContext.packageName)
            if (launchIntent == null) {
                Log.e(TAG, "Cannot restart activity - no launch intent available")
                return false
            }

            BackgroundAlarmEngine.destroyCachedEngine("app_reset_restart")
            launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK)
            appContext.startActivity(launchIntent)
            activity.finishAffinity()
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restart activity", e)
            false
        }
    }

    private fun hasExactAlarmPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true // No permission needed before Android 12
        }
    }

    private fun requestExactAlarmPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!alarmManager.canScheduleExactAlarms()) {
                val activity = activityRef?.get()
                if (activity == null) {
                    Log.w(TAG, "Cannot request exact alarm permission - no Activity attached")
                    return false
                }
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                activity.startActivity(intent)
            } else {
                // Permission already granted
                Log.d(TAG, "Exact alarm permission already granted")
                sendEventToFlutter("android_exact_alarm_permission_granted", emptyMap())
            }
        }
        return true
    }

    // Call this method to check and notify permission status
    fun checkAndNotifyExactAlarmPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val hasPermission = alarmManager.canScheduleExactAlarms()
            Log.d(TAG, "Exact alarm permission check: $hasPermission")
            if (hasPermission) {
                sendEventToFlutter("android_exact_alarm_permission_granted", emptyMap())
            } else {
                sendEventToFlutter("android_exact_alarm_permission_denied", emptyMap())
            }
        }
    }

    private fun hasPostNotificationsPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                appContext,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true // Not required before Android 13
        }
    }

    private fun requestPostNotificationsPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (!hasPostNotificationsPermission()) {
                val activity = activityRef?.get()
                if (activity == null) {
                    Log.w(TAG, "Cannot request POST_NOTIFICATIONS permission - no Activity attached")
                    return false
                }
                Log.d(TAG, "Requesting POST_NOTIFICATIONS permission")
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQUEST_POST_NOTIFICATIONS
                )
            } else {
                // Permission already granted
                Log.d(TAG, "POST_NOTIFICATIONS permission already granted")
                sendEventToFlutter("android_post_notifications_permission_granted", emptyMap())
            }
        } else {
            // Not required before Android 13
            sendEventToFlutter("android_post_notifications_permission_granted", emptyMap())
        }
        return true
    }

    // Call this method to check and notify POST_NOTIFICATIONS permission status
    fun checkAndNotifyPostNotificationsPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val hasPermission = hasPostNotificationsPermission()
            Log.d(TAG, "POST_NOTIFICATIONS permission check: $hasPermission")
            if (hasPermission) {
                sendEventToFlutter("android_post_notifications_permission_granted", emptyMap())
            } else {
                sendEventToFlutter("android_post_notifications_permission_denied", emptyMap())
            }
        } else {
            // Not required before Android 13
            sendEventToFlutter("android_post_notifications_permission_granted", emptyMap())
        }
    }

    // Handle permission request result
    fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        when (requestCode) {
            REQUEST_POST_NOTIFICATIONS -> {
                val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
                Log.d(TAG, "POST_NOTIFICATIONS permission result: $granted")
                if (granted) {
                    sendEventToFlutter("android_post_notifications_permission_granted", emptyMap())
                } else {
                    sendEventToFlutter("android_post_notifications_permission_denied", emptyMap())
                }
            }
        }
    }

    private fun isBatteryOptimizationDisabled(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return powerManager.isIgnoringBatteryOptimizations(appContext.packageName)
        }
        return true
    }

    private fun openBatteryOptimizationSettings(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val activity = activityRef?.get()
            if (activity == null) {
                Log.w(TAG, "Cannot open battery settings - no Activity attached")
                return false
            }
            try {
                // Open this app's detail page so the user can adjust battery settings
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", appContext.packageName, null)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                activity.startActivity(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to open app details settings", e)
                // Fallback to the general battery optimization settings screen
                try {
                    val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    activity.startActivity(fallbackIntent)
                } catch (fallback: Exception) {
                    Log.e(TAG, "Failed to open battery optimization settings", fallback)
                    return false
                }
            }
        }
        return true
    }

    private fun requestBatteryOptimizationExemption(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val activity = activityRef?.get()
            if (activity == null) {
                Log.w(TAG, "Cannot request battery optimization exemption - no Activity attached")
                return false
            }
            if (!powerManager.isIgnoringBatteryOptimizations(appContext.packageName)) {
                Log.d(TAG, "Requesting battery optimization exemption")
                try {
                    // Direct exemption request - shows app-specific dialog
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:${appContext.packageName}")
                    }
                    activity.startActivity(intent)
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to request battery optimization exemption", e)
                    // Fallback to general settings page
                    if (!openBatteryOptimizationSettings()) return false
                }
            } else {
                // Already exempted
                Log.d(TAG, "Battery optimization already disabled")
                sendEventToFlutter("android_battery_optimization_disabled", emptyMap())
            }
        }
        return true
    }

    // Call this method to check and notify battery optimization status
    fun checkAndNotifyBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val isDisabled = powerManager.isIgnoringBatteryOptimizations(appContext.packageName)
            Log.d(TAG, "Battery optimization disabled: $isDisabled")
            if (isDisabled) {
                sendEventToFlutter("android_battery_optimization_disabled", emptyMap())
            }
        }
    }

    private fun isForegroundServiceRunning(): Boolean {
        val activityManager = appContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        @Suppress("DEPRECATION")
        for (service in activityManager.getRunningServices(Int.MAX_VALUE)) {
            if (SlotMonitoringService::class.java.name == service.service.className) {
                return true
            }
        }
        return false
    }

    private fun isWakelockHeld(): Boolean {
        return NativeWakeLockManager.isHeld()
    }

    private fun getBackgroundTaskStats(): Map<String, Any> {
        val prefs = appContext.getSharedPreferences("background_task_stats", Context.MODE_PRIVATE)
        return mapOf(
            "execution_count" to prefs.getInt("execution_count", 0),
            "last_execution_time" to prefs.getLong("last_execution_time", 0),
            "success_count" to prefs.getInt("success_count", 0),
            "failure_count" to prefs.getInt("failure_count", 0)
        )
    }

    private fun incrementBackgroundTaskCount() {
        val prefs = appContext.getSharedPreferences("background_task_stats", Context.MODE_PRIVATE)
        val currentCount = prefs.getInt("execution_count", 0)
        prefs.edit().apply {
            putInt("execution_count", currentCount + 1)
            putLong("last_execution_time", System.currentTimeMillis())
            apply()
        }
    }
}
