package com.usernode_labs.usernode

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.usernode_labs.usernode.alarm.AlarmMethodChannelHandler
import com.usernode_labs.usernode.alarm.BackgroundAlarmEngine
import com.usernode_labs.usernode.alarm.SlotMonitoringService

private const val TAG = "usernode/MainActivity"
private const val ZKPASSPORT_PACKAGE = "app.zkpassport.zkpassport"
class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.usernode.app/alarm"
    private val ZKPASSPORT_CHANNEL = "com.usernode.app/zkpassport"
    private lateinit var alarmHandler: AlarmMethodChannelHandler
    private val backgroundStopHandler = Handler(Looper.getMainLooper())
    private val backgroundStopTimeoutMs = 5 * 60 * 1000L
    private val backgroundStopRunnable = Runnable {
        finish()
    }

    override fun provideFlutterEngine(context: android.content.Context): FlutterEngine? {
        return null
    }

    override fun shouldDestroyEngineWithHost(): Boolean {
        return true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        alarmHandler = AlarmMethodChannelHandler.getOrCreate(applicationContext)
        alarmHandler.attachActivity(this)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        alarmHandler.setMethodChannel(channel)

        channel.setMethodCallHandler { call, result ->
            alarmHandler.handleMethodCall(call, result)
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ZKPASSPORT_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isInstalled" -> result.success(isZkPassportInstalled())
                "launch" -> {
                    val url = call.argument<String>("url")
                    if (url.isNullOrBlank()) {
                        result.error("invalid_url", "Missing zkPassport launch URL.", null)
                    } else {
                        result.success(launchZkPassport(url))
                    }
                }
                else -> result.notImplemented()
            }
        }
        BackgroundAlarmEngine.destroyCachedEngine("ui_activity_onCreate")
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        Log.i(TAG, "created - foreground service active: ${SlotMonitoringService.isForegroundServiceActive}");
        // Enforce a single-engine policy: if a headless/background engine is running
        // (e.g., from alarms/boot reschedule), kill it BEFORE FlutterActivity creates
        // the UI engine to avoid two engines being alive simultaneously.
        BackgroundAlarmEngine.destroyCachedEngine("ui_activity_onCreate")
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
        backgroundStopHandler.removeCallbacks(backgroundStopRunnable)
        // Check and notify permission status when app resumes
        // This catches permission changes made in system settings
        if (::alarmHandler.isInitialized) {
            alarmHandler.checkAndNotifyPostNotificationsPermission()
            alarmHandler.checkAndNotifyExactAlarmPermission()
            alarmHandler.checkAndNotifyBatteryOptimization()
        }
    }

    override fun onRestart() {
        super.onRestart()
        backgroundStopHandler.removeCallbacks(backgroundStopRunnable)
    }

    override fun onStop() {
        super.onStop()
        backgroundStopHandler.removeCallbacks(backgroundStopRunnable)
        // stop activity by at most after 10 minutes of being in the background.
        backgroundStopHandler.postDelayed(backgroundStopRunnable, backgroundStopTimeoutMs)
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
                val globalSlot = it.getIntExtra(
                    "globalSlot",
                    it.getIntExtra("slotNumber", -1)
                )
                if (globalSlot != -1) {
                    // Alarm fired - Flutter will handle via AlarmReceiver callback
                }
            }
        }
    }

    private fun isZkPassportInstalled(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                packageManager.getPackageInfo(
                    ZKPASSPORT_PACKAGE,
                    PackageManager.PackageInfoFlags.of(0)
                )
            } else {
                @Suppress("DEPRECATION")
                packageManager.getPackageInfo(ZKPASSPORT_PACKAGE, 0)
            }
            true
        } catch (_: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun launchZkPassport(url: String): Boolean {
        if (!isZkPassportInstalled()) {
            return false
        }

        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            setPackage(ZKPASSPORT_PACKAGE)
        }

        return try {
            startActivity(intent)
            true
        } catch (e: ActivityNotFoundException) {
            Log.w(TAG, "zkPassport is installed but cannot handle launch URL", e)
            false
        } catch (e: Exception) {
            Log.w(TAG, "Failed to launch zkPassport", e)
            false
        }
    }

    override fun onDestroy() {
        if (::alarmHandler.isInitialized) {
            alarmHandler.clearMethodChannel("ui_activity_onDestroy")
            alarmHandler.detachActivity(this)
        }
        backgroundStopHandler.removeCallbacks(backgroundStopRunnable)
        super.onDestroy()
        Log.i(TAG, "destroyed - foreground service active: ${SlotMonitoringService.isForegroundServiceActive}");
        if (SlotMonitoringService.isForegroundServiceActive) {
            // Activity destroyed => keep a background engine alive for the running foreground service.
            BackgroundAlarmEngine.createAndCacheNewEngine(
                context = applicationContext,
                reason = "activity_destroyed_foreground_service",
                registerPlugins = true
            )
        }
    }
}
