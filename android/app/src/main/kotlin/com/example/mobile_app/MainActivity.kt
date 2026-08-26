package com.usernode_labs.usernode

import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.PixelCopy
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.usernode_labs.usernode.alarm.AlarmMethodChannelHandler
import com.usernode_labs.usernode.alarm.ApplicationIncarnationStore
import com.usernode_labs.usernode.alarm.BackgroundAlarmEngine
import com.usernode_labs.usernode.alarm.EngineLease
import com.usernode_labs.usernode.alarm.EngineRole
import com.usernode_labs.usernode.alarm.SlotMonitoringService
import com.usernode_labs.usernode.shortcuts.HomeShortcutsHandler
import java.io.ByteArrayOutputStream

private const val TAG = "usernode/MainActivity"
private const val ZKPASSPORT_PACKAGE = "app.zkpassport.zkpassport"
class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.usernode.app/alarm"
    private val ZKPASSPORT_CHANNEL = "com.usernode.app/zkpassport"
    private val HOME_SHORTCUTS_CHANNEL = "com.usernode.app/home_shortcuts"
    private val SCREENSHOT_CHANNEL = "com.usernode.app/screenshot"
    private val screenshotMaxBytes = 4 * 1024 * 1024
    private lateinit var alarmHandler: AlarmMethodChannelHandler
    private var alarmEngineLease: EngineLease? = null
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

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        val engineLease = alarmHandler.acquireMethodChannel(EngineRole.INTERACTIVE, channel)
            ?: throw IllegalStateException("Another Flutter engine owns the alarm channel")
        alarmEngineLease = engineLease
        if (!alarmHandler.attachActivity(this, engineLease)) {
            alarmHandler.compareReleaseMethodChannel(engineLease, "activity_attach_failed")
            alarmEngineLease = null
            throw IllegalStateException("Interactive engine could not attach its Activity")
        }

        channel.setMethodCallHandler { call, result ->
            alarmHandler.handleMethodCall(engineLease, call, result)
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

        val homeShortcutsHandler = HomeShortcutsHandler(applicationContext)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            HOME_SHORTCUTS_CHANNEL
        ).setMethodCallHandler { call, result ->
            homeShortcutsHandler.handleMethodCall(call, result)
        }
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SCREENSHOT_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "capture" -> captureCurrentScreen(result)
                else -> result.notImplemented()
            }
        }
        BackgroundAlarmEngine.destroyCachedEngine("ui_activity_onCreate")
    }

    /** Captures the visible app window, including the WebView's real pixels. */
    private fun captureCurrentScreen(result: MethodChannel.Result) {
        val view = window.decorView
        val width = view.width
        val height = view.height
        if (width <= 0 || height <= 0) {
            result.error("capture_unavailable", "The app window is not ready.", null)
            return
        }

        val bitmap = try {
            Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        } catch (error: Throwable) {
            Log.w(TAG, "Could not allocate screenshot bitmap", error)
            result.error("capture_failed", "Could not capture the app screen.", null)
            return
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PixelCopy.request(
                window,
                bitmap,
                { copyResult ->
                    if (copyResult == PixelCopy.SUCCESS) {
                        finishScreenCapture(bitmap, result)
                    } else {
                        bitmap.recycle()
                        Log.w(TAG, "PixelCopy screenshot failed with code $copyResult")
                        result.error(
                            "capture_failed",
                            "Could not capture the app screen.",
                            copyResult,
                        )
                    }
                },
                Handler(Looper.getMainLooper()),
            )
            return
        }

        try {
            view.draw(Canvas(bitmap))
            finishScreenCapture(bitmap, result)
        } catch (error: Throwable) {
            bitmap.recycle()
            Log.w(TAG, "View screenshot failed", error)
            result.error("capture_failed", "Could not capture the app screen.", null)
        }
    }

    private fun finishScreenCapture(bitmap: Bitmap, result: MethodChannel.Result) {
        try {
            val bytes = encodeScreenshot(bitmap)
            if (bytes == null) {
                result.error(
                    "capture_too_large",
                    "The screenshot is larger than 4 MB.",
                    null,
                )
            } else {
                result.success(bytes)
            }
        } catch (error: Throwable) {
            Log.w(TAG, "Screenshot encoding failed", error)
            result.error("capture_failed", "Could not encode the app screen.", null)
        } finally {
            bitmap.recycle()
        }
    }

    /** JPEG quality steps first, then bounded downscaling to meet 4 MB. */
    private fun encodeScreenshot(source: Bitmap): ByteArray? {
        var current = source
        try {
            repeat(5) { pass ->
                for (quality in intArrayOf(85, 70, 55)) {
                    val output = ByteArrayOutputStream()
                    if (!current.compress(Bitmap.CompressFormat.JPEG, quality, output)) {
                        continue
                    }
                    val bytes = output.toByteArray()
                    if (bytes.size <= screenshotMaxBytes) return bytes
                }

                if (pass == 4) return null
                val nextWidth = (current.width * 0.75).toInt().coerceAtLeast(1)
                val nextHeight = (current.height * 0.75).toInt().coerceAtLeast(1)
                if (nextWidth == current.width && nextHeight == current.height) {
                    return null
                }
                val next = Bitmap.createScaledBitmap(
                    current,
                    nextWidth,
                    nextHeight,
                    true,
                )
                if (current !== source) current.recycle()
                current = next
            }
            return null
        } finally {
            if (current !== source) current.recycle()
        }
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
        val ownsAlarmChannel = ::alarmHandler.isInitialized &&
            alarmEngineLease?.let(alarmHandler::isCurrentEngine) == true
        if (ownsAlarmChannel) {
            alarmHandler.compareReleaseMethodChannel(
                alarmEngineLease!!,
                "ui_activity_onDestroy",
            )
        }
        alarmEngineLease = null
        backgroundStopHandler.removeCallbacks(backgroundStopRunnable)
        super.onDestroy()
        Log.i(TAG, "destroyed - foreground service active: ${SlotMonitoringService.isForegroundServiceActive}");
        val replacementActivityAttached = AlarmMethodChannelHandler.getInstance()
            ?.isActivityAttached() == true
        if (SlotMonitoringService.isForegroundServiceActive && !replacementActivityAttached) {
            // A foreground service may outlive the UI engine. Re-enter Dart
            // only through an exact event; engine creation alone grants no
            // lifecycle work and terminal reset leaves no current token.
            val applicationIncarnation =
                ApplicationIncarnationStore(applicationContext).current()
            if (applicationIncarnation != null) {
                BackgroundAlarmEngine.sendAlarmEvent(
                    applicationContext,
                    "android_alarm_recovery_requested",
                    mapOf(
                        "reason" to "activity_destroyed_foreground_service",
                        "source" to "main_activity",
                        ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION to
                            applicationIncarnation,
                    ),
                )
            }
        } else if (SlotMonitoringService.isForegroundServiceActive) {
            Log.i(TAG, "Skipping headless recovery because a replacement Activity is attached")
        }
    }
}
