package com.usernode_labs.usernode.alarm

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant

/**
 * Minimal background Flutter engine to deliver alarm events to Dart
 * when the main Flutter engine is not attached (e.g., app process killed).
 *
 * The engine is lazily created and retained across alarms to avoid
 * repeated cold starts.
 */
object BackgroundAlarmEngine {
    private const val TAG = "BackgroundAlarmEngine"
    private const val CHANNEL = "com.usernode.app/alarm"
    private const val RETRY_DELAY_MS = 2000L
    const val ENGINE_ID = "shared_bg_engine"

    private var engine: FlutterEngine? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    @Synchronized
    private fun ensureEngine(context: Context): FlutterEngine {
        engine?.let { return it }

        // Try cached engine first (may have been created by MainActivity)
        FlutterEngineCache.getInstance().get(ENGINE_ID)?.let {
            Log.i(TAG, "Reusing cached shared FlutterEngine")
            engine = it
            return it
        }

        Log.i(TAG, "Creating background FlutterEngine for alarm delivery (shared)")
        val flutterEngine = FlutterEngine(context.applicationContext)
        // Register plugins so MethodChannel handlers are available
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        flutterEngine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint.createDefault()
        )
        engine = flutterEngine
        FlutterEngineCache.getInstance().put(ENGINE_ID, flutterEngine)
        return flutterEngine
    }

    fun sendAlarmEvent(context: Context, eventType: String, eventData: Map<String, Any?>) {
        mainHandler.post {
            val flutterEngine = ensureEngine(context)
            val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            val args = mapOf(
                "eventType" to eventType,
                "eventData" to eventData
            )
            try {
                Log.i(TAG, "Invoking onBlockProductionEvent via background engine")
                channel.invokeMethod("onBlockProductionEvent", args)
            } catch (e: Exception) {
                Log.w(TAG, "Alarm event send failed; scheduling one retry", e)
                scheduleRetry(context, args)
            }
        }
    }

    private fun scheduleRetry(context: Context, args: Map<String, Any?>) {
        mainHandler.postDelayed({
            try {
                val flutterEngine = ensureEngine(context)
                val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
                Log.i(TAG, "Retrying alarm event delivery via background engine")
                channel.invokeMethod("onBlockProductionEvent", args)
            } catch (e: Exception) {
                Log.e(TAG, "Retry failed for alarm event delivery", e)
            }
        }, RETRY_DELAY_MS)
    }
}

