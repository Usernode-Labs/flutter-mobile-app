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

class AlarmMethodChannelHandler(private val activity: Activity) {

    private val alarmManager: AlarmManager = activity.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val alarmScheduler: AlarmScheduler = AlarmScheduler(activity, alarmManager)
    private val foregroundServiceManager: ForegroundServiceManager = ForegroundServiceManager(activity)
    private val powerManager: PowerManager = activity.getSystemService(Context.POWER_SERVICE) as PowerManager

    private var methodChannel: MethodChannel? = null

    companion object {
        private const val TAG = "AlarmMethodChannelHandler"
        private const val REQUEST_POST_NOTIFICATIONS = 1001

        // Singleton instance for accessing from services/receivers
        @Volatile
        private var instance: AlarmMethodChannelHandler? = null

        fun getInstance(): AlarmMethodChannelHandler? = instance

        internal fun setInstance(handler: AlarmMethodChannelHandler) {
            instance = handler
        }
    }

    init {
        setInstance(this)
        Log.d(TAG, "[AlarmMethodChannelHandler] Handler initialized")
    }

    /// Set the method channel for bidirectional communication
    fun setMethodChannel(channel: MethodChannel) {
        methodChannel = channel
        Log.d(TAG, "[AlarmMethodChannelHandler] Method channel set")
    }

    /// Send a block production event to Flutter
    fun sendEventToFlutter(eventType: String, eventData: Map<String, Any?>) {
        if (methodChannel == null) {
            Log.w(TAG, "[AlarmMethodChannelHandler] Cannot send event '$eventType' - method channel not set")
            return
        }

        Log.d(TAG, "[AlarmMethodChannelHandler] Sending event to Flutter: $eventType")

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
                requestExactAlarmPermission()
                result.success(true)
            }
            "hasPostNotificationsPermission" -> {
                result.success(hasPostNotificationsPermission())
            }
            "requestPostNotificationsPermission" -> {
                requestPostNotificationsPermission()
                result.success(true)
            }
            "requestBatteryOptimizationExemption" -> {
                requestBatteryOptimizationExemption()
                result.success(true)
            }
            "scheduleExactAlarm" -> {
                val alarmId = call.argument<String>("alarmId")
                val alarmTimeMs = call.argument<Long>("alarmTimeMs")
                val slotNumber = call.argument<Int>("slotNumber")
                val data = call.argument<Map<String, Any>>("data")

                if (alarmId == null || alarmTimeMs == null || slotNumber == null) {
                    result.error("INVALID_ARGS", "Missing required arguments", null)
                    return
                }

                val success = alarmScheduler.scheduleExactAlarm(
                    alarmId = alarmId,
                    alarmTimeMs = alarmTimeMs,
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
            "isBatteryOptimizationDisabled" -> {
                result.success(isBatteryOptimizationDisabled())
            }
            "openBatterySettings" -> {
                openBatteryOptimizationSettings()
                result.success(true)
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
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun hasExactAlarmPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true // No permission needed before Android 12
        }
    }

    private fun requestExactAlarmPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!alarmManager.canScheduleExactAlarms()) {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                activity.startActivity(intent)
            } else {
                // Permission already granted
                Log.d(TAG, "[AlarmMethodChannelHandler] Exact alarm permission already granted")
                sendEventToFlutter("android_exact_alarm_permission_granted", emptyMap())
            }
        }
    }

    // Call this method to check and notify permission status
    fun checkAndNotifyExactAlarmPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val hasPermission = alarmManager.canScheduleExactAlarms()
            Log.d(TAG, "[AlarmMethodChannelHandler] Exact alarm permission check: $hasPermission")
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
                activity,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true // Not required before Android 13
        }
    }

    private fun requestPostNotificationsPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (!hasPostNotificationsPermission()) {
                Log.d(TAG, "[AlarmMethodChannelHandler] Requesting POST_NOTIFICATIONS permission")
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQUEST_POST_NOTIFICATIONS
                )
            } else {
                // Permission already granted
                Log.d(TAG, "[AlarmMethodChannelHandler] POST_NOTIFICATIONS permission already granted")
                sendEventToFlutter("android_post_notifications_permission_granted", emptyMap())
            }
        } else {
            // Not required before Android 13
            sendEventToFlutter("android_post_notifications_permission_granted", emptyMap())
        }
    }

    // Call this method to check and notify POST_NOTIFICATIONS permission status
    fun checkAndNotifyPostNotificationsPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val hasPermission = hasPostNotificationsPermission()
            Log.d(TAG, "[AlarmMethodChannelHandler] POST_NOTIFICATIONS permission check: $hasPermission")
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
                Log.d(TAG, "[AlarmMethodChannelHandler] POST_NOTIFICATIONS permission result: $granted")
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
            val powerManager = activity.getSystemService(Context.POWER_SERVICE) as PowerManager
            return powerManager.isIgnoringBatteryOptimizations(activity.packageName)
        }
        return true
    }

    private fun openBatteryOptimizationSettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
            activity.startActivity(intent)
        }
    }

    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!powerManager.isIgnoringBatteryOptimizations(activity.packageName)) {
                Log.d(TAG, "[AlarmMethodChannelHandler] Requesting battery optimization exemption")
                try {
                    // Direct exemption request - shows app-specific dialog
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                        data = Uri.parse("package:${activity.packageName}")
                    }
                    activity.startActivity(intent)
                } catch (e: Exception) {
                    Log.e(TAG, "[AlarmMethodChannelHandler] Failed to request battery optimization exemption", e)
                    // Fallback to general settings page
                    openBatteryOptimizationSettings()
                }
            } else {
                // Already exempted
                Log.d(TAG, "[AlarmMethodChannelHandler] Battery optimization already disabled")
                sendEventToFlutter("android_battery_optimization_disabled", emptyMap())
            }
        }
    }

    // Call this method to check and notify battery optimization status
    fun checkAndNotifyBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val isDisabled = powerManager.isIgnoringBatteryOptimizations(activity.packageName)
            Log.d(TAG, "[AlarmMethodChannelHandler] Battery optimization disabled: $isDisabled")
            if (isDisabled) {
                sendEventToFlutter("android_battery_optimization_disabled", emptyMap())
            }
        }
    }

    private fun isForegroundServiceRunning(): Boolean {
        val activityManager = activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        @Suppress("DEPRECATION")
        for (service in activityManager.getRunningServices(Int.MAX_VALUE)) {
            if (SlotMonitoringService::class.java.name == service.service.className) {
                return true
            }
        }
        return false
    }

    private fun isWakelockHeld(): Boolean {
        // Check if device is holding any partial wakelocks
        // Note: We can't directly check app-specific wakelocks without root
        // Return approximate status based on power manager state
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            !powerManager.isDeviceIdleMode && !powerManager.isPowerSaveMode
        } else {
            !powerManager.isPowerSaveMode
        }
    }

    private fun getBackgroundTaskStats(): Map<String, Any> {
        val prefs = activity.getSharedPreferences("background_task_stats", Context.MODE_PRIVATE)
        return mapOf(
            "execution_count" to prefs.getInt("execution_count", 0),
            "last_execution_time" to prefs.getLong("last_execution_time", 0),
            "success_count" to prefs.getInt("success_count", 0),
            "failure_count" to prefs.getInt("failure_count", 0)
        )
    }

    private fun incrementBackgroundTaskCount() {
        val prefs = activity.getSharedPreferences("background_task_stats", Context.MODE_PRIVATE)
        val currentCount = prefs.getInt("execution_count", 0)
        prefs.edit().apply {
            putInt("execution_count", currentCount + 1)
            putLong("last_execution_time", System.currentTimeMillis())
            apply()
        }
    }
}
