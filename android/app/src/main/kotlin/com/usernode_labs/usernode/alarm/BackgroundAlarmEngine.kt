package com.usernode_labs.usernode.alarm

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicInteger
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Minimal background Flutter engine to deliver alarm events to Dart
 * when the main Flutter engine is not attached (e.g., app process killed).
 *
 * Engine lifecycle rules (refactor):
 * - Never reuse a cached engine across app opens or alarms.
 * - When a new engine is needed (Activity open or alarm fired), destroy+evict any cached engine
 *   and create a fresh one, then store it in cache.
 * - When the app is suspended or Activity is destroyed, destroy+evict the cached engine.
 */
object BackgroundAlarmEngine {
    private const val TAG = "usernode/BackgroundAlarmEngine"
    private const val CHANNEL = "com.usernode.app/alarm"
    private const val WATCHDOG_DELIVERY_TIMEOUT_MS = 2L * 60L * 1000L

    /**
     * Cache key for the *background/headless* engine only.
     *
     * IMPORTANT: Do not share this ID with the app's UI [FlutterActivity] engine.
     * If a background alarm destroys/evicts the cached engine while the UI is visible,
     * touches can crash with "FlutterJNI is not attached".
     */
    const val ENGINE_ID = "bg_alarm_engine"

    private val mainHandler = Handler(Looper.getMainLooper())
    private val watchdogDeliveriesInProgress = AtomicInteger(0)

    fun isWatchdogDeliveryInProgress(): Boolean = watchdogDeliveriesInProgress.get() > 0

    @Synchronized
    private fun getCachedEngine(): FlutterEngine? {
        return FlutterEngineCache.getInstance().get(ENGINE_ID)
    }

    /**
     * Destroy and evict any cached engine.
     *
     * Safe to call multiple times.
     */
    @Synchronized
    fun destroyCachedEngine(reason: String) {
        val doDestroy = {
            try {
                val cache = FlutterEngineCache.getInstance()
                val cached = cache.get(ENGINE_ID)
                cache.remove(ENGINE_ID)
                if (cached != null) {
                    try {
                        Log.i(TAG, "Destroying cached FlutterEngine (reason=$reason)")
                        // Ensure no one tries to invoke on a stale messenger after destroy.
                        AlarmMethodChannelHandler.getInstance()?.clearMethodChannel("engine_destroyed:$reason")
                        cached.destroy()
                    } catch (e: Exception) {
                        Log.w(TAG, "Error destroying FlutterEngine (reason=$reason)", e)
                    }
                }
            } finally {
                // no-op (cache-only)
            }
        }

        if (Looper.myLooper() == Looper.getMainLooper()) {
            doDestroy()
        } else {
            mainHandler.post { doDestroy() }
        }
    }

    /**
     * Create a brand-new engine, evicting/destroying any previously cached engine first.
     *
     * - For background usage, set [registerPlugins] = true.
     * - For Activity engines, prefer [registerPlugins] = false and let FlutterActivity register.
     */
    @Synchronized
    fun createAndCacheNewEngine(
        context: Context,
        reason: String,
        registerPlugins: Boolean = true,
    ): FlutterEngine {
        // Ensure we never reuse a cached engine across opens/alarms.
        destroyCachedEngine("before_create:$reason")

        Log.i(TAG, "Creating new FlutterEngine (reason=$reason)")
        // Headless engines must not auto-register plugins: the generated
        // registrant includes WebViewFlutterPlugin, whose process-wide Pigeon
        // channels can replace the visible UI engine's WebView handlers.
        val flutterEngine = FlutterEngine(
            context.applicationContext,
            null,
            false,
        )
        if (registerPlugins) {
            HeadlessPluginRegistrant.registerWith(flutterEngine)
        }
        // Set up method channel handler BEFORE executing Dart entrypoint
        // This ensures the handler is registered when Dart code starts running
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        val handler = AlarmMethodChannelHandler.getOrCreate(context.applicationContext)
        handler.setMethodChannel(channel)
        
        // Register the method call handler so Dart can invoke methods on this channel
        channel.setMethodCallHandler { call, result ->
            handler.handleMethodCall(call, result)
        }
        
        Log.d(TAG, "Method channel handler registered for background engine")
        
        try {
            val flutterLoader = FlutterInjector.instance().flutterLoader()
            flutterLoader.startInitialization(context.applicationContext)
            flutterLoader.ensureInitializationComplete(context.applicationContext, null)
            val bundlePath = flutterLoader.findAppBundlePath()
            Log.d(TAG, "Bundle path: $bundlePath, creating entrypoint for 'headlessMain'")
            
            // Use 2-parameter constructor: bundle path and function name
            // Flutter will search for the function with @pragma('vm:entry-point') annotation
            val headlessEntrypoint = DartExecutor.DartEntrypoint(
                bundlePath,
                "headlessMain"
            )
            
            Log.d(TAG, "Executing headless Dart entrypoint: headlessMain")
            flutterEngine.dartExecutor.executeDartEntrypoint(headlessEntrypoint)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to execute Dart entrypoint headlessMain", e)
            throw e
        }

        FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
        return flutterEngine
    }

    fun sendAlarmEvent(context: Context, eventType: String, eventData: Map<String, Any?>) {
        sendAlarmEvent(context, eventType, eventData, completion = null)
    }

    suspend fun sendAlarmEventAwaitAcknowledgement(
        context: Context,
        eventType: String,
        eventData: Map<String, Any?>,
    ): Boolean {
        watchdogDeliveriesInProgress.incrementAndGet()
        return try {
            withTimeoutOrNull(WATCHDOG_DELIVERY_TIMEOUT_MS) {
                suspendCancellableCoroutine { continuation ->
                    sendAlarmEvent(context, eventType, eventData) { acknowledged ->
                        if (continuation.isActive) {
                            continuation.resume(acknowledged)
                        }
                    }
                }
            } ?: false
        } finally {
            watchdogDeliveriesInProgress.decrementAndGet()
        }
    }

    private fun sendAlarmEvent(
        context: Context,
        eventType: String,
        eventData: Map<String, Any?>,
        completion: ((Boolean) -> Unit)?,
    ) {
        if (!eventMatchesCurrentIncarnation(context, eventType, eventData)) {
            Log.w(TAG, "Ignoring stale alarm event before engine creation: $eventType")
            completion?.invoke(false)
            return
        }
        val posted = mainHandler.post {
            try {
                if (!eventMatchesCurrentIncarnation(context, eventType, eventData)) {
                    Log.w(TAG, "Ignoring stale queued alarm event: $eventType")
                    completion?.invoke(false)
                    return@post
                }
                // Check if activity is attached - if so, engine is already up so no need to create background one.
                val handler = AlarmMethodChannelHandler.getInstance()
                if (handler != null && handler.isActivityAttached()) {
                    Log.d(TAG, "Activity is attached, sending alarm event via Activity's method channel")
                    try {
                        handler.sendEventToFlutter(eventType, eventData, completion)
                        return@post
                    } catch (e: Exception) {
                        Log.w(TAG, "Failed to send event via Activity channel, falling back to background engine", e)
                    }
                }

                // UI-only permission signals carry no lifecycle authority.
                // They may update an attached UI engine, but must never create
                // a headless engine on their own.
                val captured = eventData[
                    ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION
                ] as? String
                if (!ApplicationIncarnationStore(context).matches(captured)) {
                    Log.d(TAG, "Dropping unscoped event without an attached Activity: $eventType")
                    completion?.invoke(false)
                    return@post
                }

                // Activity not attached => create a background engine
                createAndCacheNewEngine(
                    context = context,
                    reason = "alarm_event:$eventType",
                    registerPlugins = true,
                )
                AlarmMethodChannelHandler.getOrCreate(context.applicationContext)
                    .sendEventToFlutter(eventType, eventData, completion)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to deliver alarm event: $eventType", e)
                completion?.invoke(false)
            }
        }
        if (!posted) {
            completion?.invoke(false)
        }
    }

    private fun eventMatchesCurrentIncarnation(
        context: Context,
        eventType: String,
        eventData: Map<String, Any?>,
    ): Boolean {
        if (!eventType.startsWith("android_") ||
            eventType == "android_post_notifications_permission_granted" ||
            eventType == "android_post_notifications_permission_denied" ||
            eventType == "android_exact_alarm_permission_granted" ||
            eventType == "android_exact_alarm_permission_denied" ||
            eventType == "android_battery_optimization_disabled"
        ) {
            return true
        }
        val captured = eventData[
            ApplicationIncarnationStore.EXTRA_APPLICATION_INCARNATION
        ] as? String
        return ApplicationIncarnationStore(context).matches(captured)
    }
}
