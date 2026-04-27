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
import io.flutter.plugins.GeneratedPluginRegistrant

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
    private const val RETRY_DELAY_MS = 2000L
    /**
     * Cache key for the *background/headless* engine only.
     *
     * IMPORTANT: Do not share this ID with the app's UI [FlutterActivity] engine.
     * If a background alarm destroys/evicts the cached engine while the UI is visible,
     * touches can crash with "FlutterJNI is not attached".
     */
    const val ENGINE_ID = "bg_alarm_engine"

    private val mainHandler = Handler(Looper.getMainLooper())

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
        val flutterEngine = FlutterEngine(context.applicationContext)
        if (registerPlugins) {
            // Register plugins so MethodChannel handlers are available in background contexts.
            GeneratedPluginRegistrant.registerWith(flutterEngine)
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
        mainHandler.post {
            // Check if activity is attached - if so, engine is already up so no need to create background one.
            val handler = AlarmMethodChannelHandler.getInstance()
            if (handler != null && handler.isActivityAttached()) {
                Log.d(TAG, "Activity is attached, sending alarm event via Activity's method channel")
                try {
                    handler.sendEventToFlutter(eventType, eventData)
                    return@post
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to send event via Activity channel, falling back to background engine", e)
                }
            }

            // Activity not attached => create a background engine
            createAndCacheNewEngine(
                context = context,
                reason = "alarm_event:$eventType",
                registerPlugins = true,
            )
            AlarmMethodChannelHandler.getOrCreate(context.applicationContext)
                .sendEventToFlutter(eventType, eventData)
        }
    }

    private fun scheduleRetry(context: Context, args: Map<String, Any?>) {
        mainHandler.postDelayed({
            try {
                // Check if activity is attached - if so, use the handler's method channel instead
                val handler = AlarmMethodChannelHandler.getInstance()
                if (handler != null && handler.isActivityAttached()) {
                    Log.i(TAG, "Activity is attached, retrying alarm event via Activity's method channel")
                    val eventType = args["eventType"] as? String ?: "unknown"
                    val eventData = args["eventData"] as? Map<String, Any?> ?: emptyMap()
                    handler.sendEventToFlutter(eventType, eventData)
                    return@postDelayed
                }

                // Activity not attached => use background engine
                getCachedEngine()
                    ?: createAndCacheNewEngine(
                        context = context,
                        reason = "alarm_event_retry",
                        registerPlugins = true,
                    )
                val eventType = args["eventType"] as? String ?: "unknown"
                val eventData = args["eventData"] as? Map<String, Any?> ?: emptyMap()
                Log.i(TAG, "Retrying alarm event delivery via background engine")
                AlarmMethodChannelHandler.getOrCreate(context.applicationContext)
                    .sendEventToFlutter(eventType, eventData)
            } catch (e: Exception) {
                Log.e(TAG, "Retry failed for alarm event delivery", e)
            }
        }, RETRY_DELAY_MS)
    }
}
