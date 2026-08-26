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
    private var cachedEngineLease: EngineLease? = null

    fun isWatchdogDeliveryInProgress(): Boolean = watchdogDeliveriesInProgress.get() > 0

    /**
     * Destroy and evict any cached engine.
     *
     * Safe to call multiple times.
     */
    fun destroyCachedEngine(reason: String) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            destroyCachedEngineOnMain(reason)
        } else {
            mainHandler.post { destroyCachedEngineOnMain(reason) }
        }
    }

    private fun destroyCachedEngineOnMain(reason: String) {
        checkMainLooper()
        // Take/release the lease independently of the cache entry. A failed
        // cache access or put must not leave the channel authoritative.
        val lease = cachedEngineLease
        cachedEngineLease = null
        if (lease != null) {
            try {
                AlarmMethodChannelHandler.getInstance()
                    ?.compareReleaseMethodChannel(lease, "engine_destroyed:$reason")
            } catch (failure: Throwable) {
                Log.w(TAG, "Could not release alarm channel (reason=$reason)", failure)
            }
        }

        val cache = try {
            FlutterEngineCache.getInstance()
        } catch (failure: Throwable) {
            Log.w(TAG, "Could not access FlutterEngine cache (reason=$reason)", failure)
            return
        }
        val cached = try {
            cache.get(ENGINE_ID)
        } catch (failure: Throwable) {
            Log.w(TAG, "Could not read cached FlutterEngine (reason=$reason)", failure)
            null
        }
        try {
            cache.remove(ENGINE_ID)
        } catch (failure: Throwable) {
            Log.w(TAG, "Could not evict cached FlutterEngine (reason=$reason)", failure)
        }

        if (cached == null) return
        Log.i(TAG, "Destroying cached FlutterEngine (reason=$reason)")
        try {
            cached.destroy()
        } catch (failure: Throwable) {
            Log.w(TAG, "Error destroying FlutterEngine (reason=$reason)", failure)
        }
    }

    /**
     * Create a brand-new engine, evicting/destroying any previously cached engine first.
     */
    private fun createAndCacheNewEngine(
        context: Context,
        reason: String,
    ): FlutterEngine {
        checkMainLooper()
        // Replacement is one main-looper transaction: no asynchronous half
        // destroy can overtake construction of its successor.
        destroyCachedEngineOnMain("before_create:$reason")

        val appContext = context.applicationContext
        val cache = FlutterEngineCache.getInstance()
        var flutterEngine: FlutterEngine? = null
        var handler: AlarmMethodChannelHandler? = null
        var engineLease: EngineLease? = null
        try {
            Log.i(TAG, "Creating new FlutterEngine (reason=$reason)")
            // Headless engines must not auto-register plugins: the generated
            // registrant includes WebViewFlutterPlugin, whose process-wide
            // Pigeon channels can replace the visible UI engine's handlers.
            val candidate = FlutterEngine(
                appContext,
                null,
                false,
            )
            flutterEngine = candidate
            HeadlessPluginRegistrant.registerWith(candidate)

            // Bind the exact engine before Dart starts, then capture that lease
            // in every callback registered on its messenger.
            val channel = MethodChannel(candidate.dartExecutor.binaryMessenger, CHANNEL)
            val localHandler = AlarmMethodChannelHandler.getOrCreate(appContext)
            handler = localHandler
            val localLease = localHandler.acquireMethodChannel(EngineRole.HEADLESS, channel)
                ?: throw IllegalStateException("Another Flutter engine owns the alarm channel")
            engineLease = localLease
            cachedEngineLease = localLease
            channel.setMethodCallHandler { call, result ->
                localHandler.handleMethodCall(localLease, call, result)
            }
            Log.d(TAG, "Method channel handler registered for background engine")

            val flutterLoader = FlutterInjector.instance().flutterLoader()
            flutterLoader.startInitialization(appContext)
            flutterLoader.ensureInitializationComplete(appContext, null)
            val bundlePath = flutterLoader.findAppBundlePath()
            Log.d(TAG, "Bundle path: $bundlePath, creating entrypoint for 'headlessMain'")

            // Use 2-parameter constructor: bundle path and function name
            // Flutter will search for the function with @pragma('vm:entry-point') annotation
            val headlessEntrypoint = DartExecutor.DartEntrypoint(
                bundlePath,
                "headlessMain"
            )

            Log.d(TAG, "Executing headless Dart entrypoint: headlessMain")
            candidate.dartExecutor.executeDartEntrypoint(headlessEntrypoint)

            cache.put(ENGINE_ID, candidate)
            return candidate
        } catch (failure: Throwable) {
            Log.e(TAG, "Headless FlutterEngine transaction failed (reason=$reason)", failure)
            val localLease = engineLease
            if (localLease != null) {
                try {
                    handler?.compareReleaseMethodChannel(
                        localLease,
                        "engine_create_failed:$reason",
                    )
                } catch (cleanupFailure: Throwable) {
                    failure.addSuppressed(cleanupFailure)
                }
                if (cachedEngineLease === localLease) {
                    cachedEngineLease = null
                }
            }
            // A cache put may have succeeded before throwing; always evict.
            try {
                cache.remove(ENGINE_ID)
            } catch (cleanupFailure: Throwable) {
                failure.addSuppressed(cleanupFailure)
            }
            flutterEngine?.let { failedEngine ->
                try {
                    failedEngine.destroy()
                } catch (destroyFailure: Throwable) {
                    failure.addSuppressed(destroyFailure)
                }
            }
            throw failure
        }
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

    private fun checkMainLooper() {
        check(Looper.myLooper() == Looper.getMainLooper()) {
            "Headless FlutterEngine lifecycle must run on the main looper"
        }
    }
}
