package com.usernode_labs.usernode.alarm

import android.util.Log
import com.baseflow.permissionhandler.PermissionHandlerPlugin
import com.github.dart_lang.jni.JniPlugin
import com.it_nomads.fluttersecurestorage.FlutterSecureStoragePlugin
import com.mr.flutter.plugin.filepicker.FilePickerPlugin
import dev.fluttercommunity.plus.battery.BatteryPlusPlugin
import dev.fluttercommunity.plus.connectivity.ConnectivityPlugin
import dev.fluttercommunity.plus.device_info.DeviceInfoPlusPlugin
import dev.fluttercommunity.plus.packageinfo.PackageInfoPlugin
import dev.fluttercommunity.plus.wakelock.WakelockPlusPlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugins.firebase.core.FlutterFirebaseCorePlugin
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingPlugin
import io.flutter.plugins.flutter_plugin_android_lifecycle.FlutterAndroidLifecyclePlugin
import io.flutter.plugins.pathprovider.PathProviderPlugin
import io.flutter.plugins.sharedpreferences.SharedPreferencesPlugin
import io.flutter.plugins.urllauncher.UrlLauncherPlugin
import io.sentry.flutter.SentryFlutterPlugin

/**
 * Registers plugins needed by the headless alarm isolate.
 *
 * Keep this list aligned with GeneratedPluginRegistrant, except that
 * WebViewFlutterPlugin must never be added to a headless engine. Its Pigeon
 * channels are process-wide and would replace the visible UI engine's WebView
 * handlers.
 */
object HeadlessPluginRegistrant {
    private const val TAG = "usernode/HeadlessPlugins"

    private val pluginFactories: List<() -> FlutterPlugin> = listOf(
        { BatteryPlusPlugin() },
        { ConnectivityPlugin() },
        { DeviceInfoPlusPlugin() },
        { FilePickerPlugin() },
        { FlutterFirebaseCorePlugin() },
        { FlutterFirebaseMessagingPlugin() },
        { FlutterAndroidLifecyclePlugin() },
        { FlutterSecureStoragePlugin() },
        { JniPlugin() },
        { PackageInfoPlugin() },
        { PathProviderPlugin() },
        { PermissionHandlerPlugin() },
        { SentryFlutterPlugin() },
        { SharedPreferencesPlugin() },
        { UrlLauncherPlugin() },
        { WakelockPlusPlugin() },
    )

    fun registerWith(flutterEngine: FlutterEngine) {
        pluginFactories.forEach { createPlugin ->
            try {
                flutterEngine.plugins.add(createPlugin())
            } catch (exception: Exception) {
                Log.e(TAG, "Error registering headless Flutter plugin", exception)
            }
        }
    }
}
