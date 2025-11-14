package com.usernode_labs.usernode

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.usernode_labs.usernode.alarm.AlarmMethodChannelHandler

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.usernode.lingash/alarm"
    private lateinit var alarmHandler: AlarmMethodChannelHandler

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        alarmHandler = AlarmMethodChannelHandler(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
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

    private fun handleAlarmIntent(intent: Intent?) {
        intent?.let {
            if (it.action == "com.usernode.lingash.SLOT_ALARM") {
                val slotNumber = it.getIntExtra("slotNumber", -1)
                if (slotNumber != -1) {
                    // Alarm fired - Flutter will handle via AlarmReceiver callback
                }
            }
        }
    }
}
