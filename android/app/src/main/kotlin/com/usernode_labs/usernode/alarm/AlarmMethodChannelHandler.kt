package com.usernode_labs.usernode.alarm

import android.Manifest
import android.app.Activity
import android.app.ActivityManager
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import android.webkit.CookieManager
import android.webkit.WebStorage
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.webkit.WebStorageCompat
import androidx.webkit.WebViewFeature
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

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
    private val applicationIncarnationStore = ApplicationIncarnationStore(appContext)
    private val powerManager: PowerManager = appContext.getSystemService(Context.POWER_SERVICE) as PowerManager

    private var methodChannel: MethodChannel? = null
    private val flutterAlarmEventBuffer = FlutterAlarmEventBuffer()
    private var lastKnownExactAlarmPermission: Boolean? = null
    private val methodScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

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

    fun isActivityAttached(activity: Activity): Boolean {
        return activityRef?.get() === activity
    }

    /// Set the method channel for bidirectional communication
    fun setMethodChannel(channel: MethodChannel) {
        methodChannel = channel
        Log.d(TAG, "Method channel set")
        flushPendingEvents("method_channel_set")
    }

    fun clearMethodChannel(reason: String) {
        methodChannel = null
        flutterAlarmEventBuffer.markFlutterNotReady()
        Log.d(TAG, "Method channel cleared (reason=$reason)")
    }

    fun markFlutterReadyForAlarmEvents(): Boolean {
        Log.d(TAG, "Flutter marked alarm channel ready")
        val pendingEvents = flutterAlarmEventBuffer.markFlutterReady()
        flushEventsToCurrentChannel(pendingEvents, "flutter_ready")
        return true
    }

    /// Send a block production event to Flutter
    fun sendEventToFlutter(
        eventType: String,
        eventData: Map<String, Any?>,
        completion: ((Boolean) -> Unit)? = null,
    ) {
        if (requiresApplicationIncarnation(eventType)) {
            val captured = eventData[
                ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION
            ] as? String
            if (!applicationIncarnationStore.matches(captured)) {
                Log.w(TAG, "Dropping stale native event: $eventType")
                completion?.invoke(false)
                return
            }
        }
        val event = flutterAlarmEventBuffer.enqueueOrDispatch(eventType, eventData, completion)
        if (event == null) {
            Log.d(TAG, "Queued event for Flutter: $eventType")
            return
        }

        flushEventsToCurrentChannel(listOf(event), "immediate_dispatch")
    }

    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "ensureApplicationIncarnation" -> {
                result.success(applicationIncarnationStore.ensure())
            }
            "invalidateApplicationIncarnation" -> {
                result.success(applicationIncarnationStore.invalidate())
            }
            "rotateApplicationIncarnation" -> {
                result.success(applicationIncarnationStore.rotate())
            }
            "clearSessionNotifications" -> {
                result.success(clearSessionNotifications())
            }
            "clearWebSessionData" -> {
                clearWebSessionData(result)
            }
            "clearNativeResetState" -> {
                result.success(clearNativeResetState())
            }
            "enterTerminalReset" -> {
                val clearApplicationData =
                    call.argument<Boolean>("clearApplicationData") ?: true
                result.success(null)
                enterTerminalReset(clearApplicationData)
            }
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
                val applicationIncarnation = currentIncarnationFromCall(call)
                if (applicationIncarnation == null) {
                    result.success(false)
                    return
                }
                val alarmId = call.argument<String>("alarmId")
                val delayMs = call.argument<Number>("delayMs")?.toLong()
                val globalSlot = call.argument<Number>("globalSlot")?.toInt()
                    ?: call.argument<Number>("slotNumber")?.toInt()
                val data = call.argument<Map<String, Any>>("data")

                if (alarmId == null || globalSlot == null || delayMs == null) {
                    result.error("INVALID_ARGS", "Missing required alarmId/globalSlot/delayMs arguments", null)
                    return
                }

                val success = alarmScheduler.scheduleExactAlarm(
                    alarmId = alarmId,
                    delayMs = delayMs,
                    globalSlot = globalSlot,
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
            "hasScheduledAlarm" -> {
                val alarmId = call.argument<String>("alarmId")
                if (alarmId == null) {
                    result.error("INVALID_ARGS", "Missing alarmId", null)
                    return
                }

                result.success(alarmScheduler.hasScheduledAlarm(alarmId))
            }
            "getAlarmDebugState" -> {
                val alarmId = call.argument<String>("alarmId")
                if (alarmId == null) {
                    result.error("INVALID_ARGS", "Missing alarmId", null)
                    return
                }

                result.success(alarmScheduler.getAlarmDebugState(alarmId))
            }
            "startForegroundService" -> {
                val applicationIncarnation = currentIncarnationFromCall(call)
                if (applicationIncarnation == null) {
                    result.success(false)
                    return
                }
                val title = call.argument<String>("title")
                val message = call.argument<String>("message")
                val globalSlot = call.argument<Number>("globalSlot")?.toInt()
                    ?: call.argument<Number>("slotNumber")?.toInt()

                if (title == null || message == null || globalSlot == null) {
                    result.error("INVALID_ARGS", "Missing required arguments", null)
                    return
                }

                val success = foregroundServiceManager.startForegroundService(
                    title = title,
                    message = message,
                    globalSlot = globalSlot,
                    applicationIncarnation = applicationIncarnation,
                )
                result.success(success)
            }
            "stopForegroundService" -> {
                val success = foregroundServiceManager.stopForegroundService()
                result.success(success)
            }
            "startPersistentForegroundService" -> {
                val applicationIncarnation = currentIncarnationFromCall(call)
                if (applicationIncarnation == null) {
                    result.success(false)
                    return
                }
                Log.d(TAG, "Starting persistent foreground service")
                val intent = Intent(appContext, SlotMonitoringService::class.java).apply {
                    action = SlotMonitoringService.ACTION_START_PERSISTENT
                    putExtra(
                        ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION,
                        applicationIncarnation,
                    )
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
            "openNotificationSettings" -> {
                result.success(openAppNotificationSettings())
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
                val applicationIncarnation = currentIncarnationFromCall(call)
                result.success(
                    applicationIncarnation != null &&
                        NativeWakeLockManager.acquire(appContext, applicationIncarnation)
                )
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
            "markFlutterReadyForAlarmEvents" -> {
                result.success(markFlutterReadyForAlarmEvents())
            }
            "wasForceStoppedOnStartup" -> {
                result.success(wasForceStoppedOnStartup())
            }
            "ensureAlarmWatchdogScheduled" -> {
                val applicationIncarnation = currentIncarnationFromCall(call)
                if (applicationIncarnation == null) {
                    result.success(false)
                    return
                }
                val reason = call.argument<String>("reason") ?: "dart"
                result.success(
                    AlarmWatchdogScheduler.ensurePeriodic(
                        appContext,
                        reason,
                        applicationIncarnation,
                    )
                )
            }
            "requestAlarmWatchdogRun" -> {
                val applicationIncarnation = currentIncarnationFromCall(call)
                if (applicationIncarnation == null) {
                    result.success(false)
                    return
                }
                val reason = call.argument<String>("reason") ?: "dart"
                result.success(
                    AlarmWatchdogScheduler.enqueueOneTime(
                        appContext,
                        reason,
                        applicationIncarnation,
                    )
                )
            }
            "cancelAlarmWatchdog" -> {
                result.success(AlarmWatchdogScheduler.cancel(appContext))
            }
            "getAlarmWatchdogState" -> {
                methodScope.launch {
                    try {
                        result.success(AlarmWatchdogScheduler.state(appContext))
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to query alarm watchdog state", e)
                        result.error("WATCHDOG_STATE_ERROR", e.message, null)
                    }
                }
            }
            "isAlarmWatchdogDeliveryInProgress" -> {
                result.success(BackgroundAlarmEngine.isWatchdogDeliveryInProgress())
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun currentIncarnationFromCall(call: MethodCall): String? {
        val captured = call.argument<String>(
            ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION,
        )
        if (applicationIncarnationStore.matches(captured)) return captured
        Log.w(TAG, "Rejected ${call.method} for stale application incarnation")
        return null
    }

    private fun requiresApplicationIncarnation(eventType: String): Boolean {
        if (!eventType.startsWith("android_")) return false
        return eventType != "android_post_notifications_permission_granted" &&
            eventType != "android_post_notifications_permission_denied" &&
            eventType != "android_exact_alarm_permission_granted" &&
            eventType != "android_exact_alarm_permission_denied" &&
            eventType != "android_battery_optimization_disabled"
    }

    /**
     * Deletes everything the WebView holds for the retired session.
     *
     * The framework `WebStorage.deleteAllData()` has no completion callback and
     * makes no guarantee about the network cache or installed service workers —
     * and this app deliberately enables service workers for the SV shell — so it
     * cannot back a security boundary. `WebStorageCompat.deleteBrowsingData`
     * (androidx.webkit 1.13.0+) covers cache, cookies, JS-readable storage and
     * service workers, and reports completion.
     *
     * When that API is unavailable this reports failure rather than a partial
     * wipe: a scoped sign-out must not be acknowledged on a jar that may still
     * re-authenticate the next page load. The Dart side escalates to the
     * terminal reset, whose clear-application-data wipe does cover it.
     */
    private fun clearWebSessionData(result: MethodChannel.Result) {
        if (!WebViewFeature.isFeatureSupported(WebViewFeature.DELETE_BROWSING_DATA)) {
            Log.e(
                TAG,
                "Comprehensive WebView deletion is unsupported by the installed " +
                    "WebView; refusing to report a partial session clear"
            )
            result.success(false)
            return
        }
        val answered = AtomicBoolean(false)
        fun answer(success: Boolean) {
            if (answered.compareAndSet(false, true)) result.success(success)
        }
        try {
            Handler(Looper.getMainLooper()).post {
                try {
                    WebStorageCompat.deleteBrowsingData(WebStorage.getInstance()) {
                        // Cookies live in their own store; flush them to disk so the
                        // deletion survives a process death immediately after this.
                        val cookies = CookieManager.getInstance()
                        cookies.removeAllCookies {
                            cookies.flush()
                            answer(true)
                        }
                    }
                } catch (error: Exception) {
                    Log.e(TAG, "Failed to clear WebView browsing data", error)
                    answer(false)
                }
            }
        } catch (error: Exception) {
            Log.e(TAG, "Failed to clear WebView session data", error)
            answer(false)
        }
    }

    /**
     * Removes the notifications this app has already posted. A scoped sign-out
     * keeps the process, so nothing else would take the retired session's
     * Social/slot text off the tray or lock screen.
     */
    private fun clearSessionNotifications(): Boolean {
        return try {
            (appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .cancelAll()
            true
        } catch (error: Exception) {
            Log.e(TAG, "Failed to clear session notifications", error)
            false
        }
    }

    private fun clearNativeResetState(): Boolean {
        var durableStateCleared = alarmScheduler.cancelAllAlarms("terminal_reset")
        durableStateCleared =
            AlarmWatchdogScheduler.cancel(appContext) && durableStateCleared
        durableStateCleared =
            foregroundServiceManager.stopForegroundService() && durableStateCleared
        appContext.stopService(Intent(appContext, SlotMonitoringService::class.java))
        NativeWakeLockManager.release()
        (appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
            .cancelAll()
        for (name in listOf("alarm_prefs", "alarm_watchdog_prefs", "background_task_stats")) {
            durableStateCleared = appContext.getSharedPreferences(name, Context.MODE_PRIVATE)
                .edit()
                .clear()
                .commit() && durableStateCleared
        }
        durableStateCleared = applicationIncarnationStore.clear() && durableStateCleared
        flutterAlarmEventBuffer.clear()
        BackgroundAlarmEngine.destroyCachedEngine("terminal_reset")
        return durableStateCleared
    }

    private fun enterTerminalReset(clearApplicationData: Boolean) {
        BackgroundAlarmEngine.destroyCachedEngine("terminal_reset")
        activityRef?.get()?.finishAffinity()
        Handler(Looper.getMainLooper()).post {
            if (clearApplicationData) {
                val activityManager =
                    appContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                if (activityManager.clearApplicationUserData()) return@post
            }
            android.os.Process.killProcess(android.os.Process.myPid())
        }
    }

    private fun hasExactAlarmPermission(): Boolean {
        val hasPermission = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            alarmManager.canScheduleExactAlarms()
        } else {
            true // No permission needed before Android 12
        }
        lastKnownExactAlarmPermission = hasPermission
        return hasPermission
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
                lastKnownExactAlarmPermission = true
                sendEventToFlutter(
                    "android_exact_alarm_permission_granted",
                    mapOf(
                        "source" to "request_already_granted",
                        "stateChanged" to false
                    )
                )
            }
        }
        return true
    }

    // Call this method to check and notify permission status
    fun checkAndNotifyExactAlarmPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val hasPermission = alarmManager.canScheduleExactAlarms()
            val previous = lastKnownExactAlarmPermission
            val stateChanged = previous != null && previous != hasPermission
            lastKnownExactAlarmPermission = hasPermission
            Log.d(TAG, "Exact alarm permission check: $hasPermission")
            if (hasPermission) {
                sendEventToFlutter(
                    "android_exact_alarm_permission_granted",
                    mapOf(
                        "source" to "resume_permission_check",
                        "stateChanged" to stateChanged
                    )
                )
            } else {
                sendEventToFlutter(
                    "android_exact_alarm_permission_denied",
                    mapOf(
                        "source" to "resume_permission_check",
                        "stateChanged" to stateChanged
                    )
                )
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

    private fun openAppNotificationSettings(): Boolean {
        val activity = activityRef?.get()
        if (activity == null) {
            Log.w(TAG, "Cannot open notification settings - no Activity attached")
            return false
        }
        return try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, appContext.packageName)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            } else {
                // Pre-26 has no per-app notification settings action; the app
                // details page hosts the notification toggle there.
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", appContext.packageName, null)
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            }
            activity.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open app notification settings", e)
            false
        }
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

    private fun wasForceStoppedOnStartup(): Boolean {
        if (Build.VERSION.SDK_INT < 35) {
            return false
        }

        return try {
            val activityManager = appContext.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val method = activityManager.javaClass.getMethod(
                "getHistoricalProcessStartReasons",
                Int::class.javaPrimitiveType!!
            )
            val startReasons = method.invoke(activityManager, 0) as? List<*> ?: return false
            startReasons.any { info ->
                try {
                    val wasForceStopped = info?.javaClass
                        ?.getMethod("wasForceStopped")
                        ?.invoke(info) as? Boolean
                    wasForceStopped == true
                } catch (e: Exception) {
                    false
                }
            }
        } catch (e: Exception) {
            Log.d(TAG, "Unable to inspect ApplicationStartInfo.wasForceStopped", e)
            false
        }
    }

    private fun flushPendingEvents(reason: String) {
        val pendingEvents = flutterAlarmEventBuffer.drainIfReady()
        flushEventsToCurrentChannel(pendingEvents, reason)
    }

    private fun flushEventsToCurrentChannel(
        events: List<FlutterAlarmEvent>,
        reason: String,
    ) {
        if (events.isEmpty()) {
            return
        }

        val channel = methodChannel
        if (channel == null) {
            Log.w(TAG, "Cannot flush ${events.size} event(s) - method channel not set (reason=$reason)")
            events.forEach { it.completion?.invoke(false) }
            return
        }

        if (events.size > 1) {
            Log.i(TAG, "Flushing ${events.size} pending event(s) to Flutter (reason=$reason)")
        }

        for (event in events) {
            Log.d(TAG, "Sending event to Flutter: ${event.eventType}")
            val args = mapOf(
                "eventType" to event.eventType,
                "eventData" to event.eventData
            )
            val completion = event.completion
            if (completion == null) {
                channel.invokeMethod("onBlockProductionEvent", args)
                continue
            }

            channel.invokeMethod(
                "onBlockProductionEvent",
                args,
                object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        completion(result == true)
                    }

                    override fun error(
                        errorCode: String,
                        errorMessage: String?,
                        errorDetails: Any?,
                    ) {
                        Log.w(
                            TAG,
                            "Flutter rejected ${event.eventType}: $errorCode $errorMessage",
                        )
                        completion(false)
                    }

                    override fun notImplemented() {
                        Log.w(TAG, "Flutter did not implement ${event.eventType}")
                        completion(false)
                    }
                },
            )
        }
    }
}
