package com.usernode_labs.usernode.alarm

import android.app.Activity
import android.app.AlarmManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AlarmMethodChannelHandler(private val activity: Activity) {

    private val alarmManager: AlarmManager = activity.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val alarmScheduler: AlarmScheduler = AlarmScheduler(activity, alarmManager)
    private val foregroundServiceManager: ForegroundServiceManager = ForegroundServiceManager(activity)

    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasExactAlarmPermission" -> {
                result.success(hasExactAlarmPermission())
            }
            "requestExactAlarmPermission" -> {
                requestExactAlarmPermission()
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
}
