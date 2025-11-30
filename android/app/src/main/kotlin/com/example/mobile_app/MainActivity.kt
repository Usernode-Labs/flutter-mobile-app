package com.usernode_labs.usernode

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.usernode_labs.usernode.alarm.AlarmMethodChannelHandler

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.usernode.app/alarm"
    private lateinit var alarmHandler: AlarmMethodChannelHandler

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        alarmHandler = AlarmMethodChannelHandler(this)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        alarmHandler.setMethodChannel(channel)

        channel.setMethodCallHandler { call, result ->
            alarmHandler.handleMethodCall(call, result)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Handle alarm intent if launched from alarm receiver
        handleAlarmIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleAlarmIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        // Check and notify permission status when app resumes
        // This catches permission changes made in system settings
        if (::alarmHandler.isInitialized) {
            alarmHandler.checkAndNotifyPostNotificationsPermission()
            alarmHandler.checkAndNotifyExactAlarmPermission()
            alarmHandler.checkAndNotifyBatteryOptimization()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (::alarmHandler.isInitialized) {
            alarmHandler.onRequestPermissionsResult(requestCode, permissions, grantResults)
        }
    }

    private fun handleAlarmIntent(intent: Intent?) {
        intent?.let {
            if (it.action == "com.usernode.app.SLOT_ALARM") {
                val slotNumber = it.getIntExtra("slotNumber", -1)
                if (slotNumber != -1) {
                    // Alarm fired - Flutter will handle via AlarmReceiver callback
                }
            }
        }
    }

    override fun onBackPressed() {
        // When the Flutter navigation stack can't handle a back press
        // (i.e., on the root route), move the task to the background
        // instead of finishing the activity. This keeps the app running.
        moveTaskToBack(true)
    }
}
