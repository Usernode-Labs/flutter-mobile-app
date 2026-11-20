package com.onhomeroom.app.webview

import android.Manifest
import android.app.Activity
import android.app.AlertDialog
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.net.Uri
import android.os.Message
import android.provider.Settings
import android.util.Log
import android.view.View
import android.webkit.ConsoleMessage
import android.webkit.GeolocationPermissions
import android.webkit.JsPromptResult
import android.webkit.JsResult
import android.webkit.PermissionRequest
import android.webkit.ValueCallback
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.onhomeroom.app.R
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebChromeClientProxyApi.SecureWebChromeClient
import io.flutter.plugins.webviewflutter.WebViewFlutterPlugin
import io.flutter.plugins.webviewflutter.WebViewProxyApi.WebViewPlatformView

/**
 * Owns runtime microphone and camera requests for this Activity's WebViews.
 *
 * The microphone is Homeroom's own (dictation). The camera is also for the
 * apps Homeroom embeds: see [WebViewCameraPolicy] for why that is safe.
 */
class WebViewMediaPermissions(
    private val activity: Activity,
    private val engine: FlutterEngine,
) {
    private val channel = MethodChannel(
        engine.dartExecutor.binaryMessenger,
        "com.onhomeroom.app/webview_microphone",
    )
    private class Pending(
        val request: PermissionRequest,
        val webView: WebView,
        /** Asked again after the OS dialog, against the WebView's URL then. */
        val allowed: (requestOrigin: String, topFrameUrl: String?, resources: Array<String>) -> Boolean,
    )
    /** One Android permission, the one WebView resource it unlocks, and its prompt. */
    private inner class Gate(
        val permission: String,
        val resource: String,
        val requestCode: Int,
        val askedKey: String,
        val blockedTitle: Int,
        val blockedMessage: Int,
    ) {
        /** Requests waiting on the one OS prompt; all of them get its answer. */
        val pending = mutableListOf<Pending>()
        var promptInFlight = false

        fun hasPermission(): Boolean =
            ContextCompat.checkSelfPermission(activity, permission) == PackageManager.PERMISSION_GRANTED

        fun cancelPending() {
            promptInFlight = false
            val values = pending.toList()
            pending.clear()
            values.forEach { it.request.deny() }
        }
    }
    private val microphone = Gate(
        Manifest.permission.RECORD_AUDIO, PermissionRequest.RESOURCE_AUDIO_CAPTURE,
        MICROPHONE_REQUEST_CODE, KEY_ASKED,
        R.string.webview_microphone_blocked_title, R.string.webview_microphone_blocked_message,
    )
    private val camera = Gate(
        Manifest.permission.CAMERA, PermissionRequest.RESOURCE_VIDEO_CAPTURE,
        CAMERA_REQUEST_CODE, KEY_CAMERA_ASKED,
        R.string.webview_camera_blocked_title, R.string.webview_camera_blocked_message,
    )
    private val gates = listOf(microphone, camera)
    private val prefs = activity.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    init {
        channel.setMethodCallHandler { call, result ->
            if (call.method != "configure") {
                result.notImplemented()
            } else {
                val identifier = call.argument<Number>("webViewIdentifier")?.toLong()
                val origin = call.argument<String>("trustedOrigin")
                val plugin = engine.plugins.get(WebViewFlutterPlugin::class.java) as? WebViewFlutterPlugin
                // This plugin getter also exists below Android 8, unlike the
                // framework's WebView.getWebChromeClient() (added in API 26).
                val webView = identifier?.let { plugin?.instanceManager?.getInstance<Any>(it) }
                    as? WebViewPlatformView
                val delegate = webView?.webChromeClient as? SecureWebChromeClient
                if (webView == null || delegate == null || origin == null) {
                    Log.w(TAG, "Not configured: webView=${webView != null} " +
                        "delegate=${delegate != null} origin=${origin != null}")
                    result.success(false)
                } else {
                    webView.webChromeClient = MediaClient(
                        delegate, webView, WebViewMicrophonePolicy(origin), WebViewCameraPolicy(origin),
                    )
                    result.success(true)
                }
            }
        }
    }

    // Checks the WebView's current URL, so a hash route change while the OS
    // dialog is open keeps the grant; leaving the trusted origin does not.
    private fun eligible(value: Pending): Boolean =
        !activity.isFinishing && !activity.isDestroyed &&
            value.webView.isAttachedToWindow && value.webView.isShown &&
            value.allowed(
                value.request.origin.toString(), value.webView.url, value.request.resources,
            )

    private fun request(gate: Gate, value: Pending) {
        if (!eligible(value)) {
            value.request.deny()
            return
        }
        if (gate.hasPermission()) {
            value.request.grant(arrayOf(gate.resource))
            return
        }
        if (gate.promptInFlight) {
            gate.pending += value
            return
        }
        // Android stops showing its prompt after a permanent denial, so point
        // the user to Settings instead of failing silently.
        if (prefs.getBoolean(gate.askedKey, false) &&
            !ActivityCompat.shouldShowRequestPermissionRationale(activity, gate.permission)
        ) {
            value.request.deny()
            showSettingsPrompt(gate)
            return
        }
        gate.pending += value
        gate.promptInFlight = true
        prefs.edit().putBoolean(gate.askedKey, true).apply()
        try {
            ActivityCompat.requestPermissions(activity, arrayOf(gate.permission), gate.requestCode)
        } catch (e: RuntimeException) {
            Log.w(TAG, "Permission prompt failed for ${gate.permission}", e)
            gate.cancelPending()
        }
    }

    fun onRequestPermissionsResult(requestCode: Int) {
        val gate = gates.firstOrNull { it.requestCode == requestCode } ?: return
        gate.promptInFlight = false
        val values = gate.pending.toList()
        gate.pending.clear()
        val granted = gate.hasPermission()
        for (value in values) {
            // Recheck after the OS dialog: it may outlive a navigation.
            if (granted && eligible(value)) {
                value.request.grant(arrayOf(gate.resource))
            } else {
                value.request.deny()
            }
        }
    }

    private fun showSettingsPrompt(gate: Gate) {
        if (activity.isFinishing || activity.isDestroyed) return
        AlertDialog.Builder(activity)
            .setTitle(gate.blockedTitle)
            .setMessage(gate.blockedMessage)
            .setNegativeButton(R.string.webview_microphone_blocked_dismiss, null)
            .setPositiveButton(R.string.webview_microphone_blocked_open_settings) { _, _ ->
                try {
                    activity.startActivity(
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            .setData(Uri.fromParts("package", activity.packageName, null)),
                    )
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to open app details settings", e)
                }
            }
            .show()
    }

    fun close() {
        gates.forEach { it.cancelPending() }
        channel.setMethodCallHandler(null)
    }

    /**
     * Keep the plugin's chooser, dialogs, console and secure popup handling.
     * A camera-only request and any request naming the microphone stay
     * native (so a request for both is refused by the microphone's policy);
     * anything else still reaches the Dart `onPermissionRequest` handler
     * through the plugin's client.
     */
    private inner class MediaClient(
        private val delegate: SecureWebChromeClient,
        private val webView: WebView,
        private val microphonePolicy: WebViewMicrophonePolicy,
        private val cameraPolicy: WebViewCameraPolicy,
    ) : SecureWebChromeClient() {
        override fun onPermissionRequest(request: PermissionRequest) {
            val resources = request.resources
            if (PermissionRequest.RESOURCE_AUDIO_CAPTURE in resources) {
                request(microphone, Pending(request, webView, microphonePolicy::allows))
            } else if (PermissionRequest.RESOURCE_VIDEO_CAPTURE in resources) {
                request(camera, Pending(request, webView, cameraPolicy::allows))
            } else {
                delegate.onPermissionRequest(request)
            }
        }
        override fun onPermissionRequestCanceled(request: PermissionRequest) {
            if (gates.none { gate -> gate.pending.removeAll { it.request === request } }) {
                delegate.onPermissionRequestCanceled(request)
            }
        }
        override fun setWebViewClient(client: WebViewClient) {
            super.setWebViewClient(client)
            delegate.setWebViewClient(client)
        }
        override fun onProgressChanged(view: WebView, progress: Int) = delegate.onProgressChanged(view, progress)
        override fun onReceivedTitle(view: WebView, title: String?) = delegate.onReceivedTitle(view, title)
        override fun onReceivedIcon(view: WebView, icon: Bitmap?) = delegate.onReceivedIcon(view, icon)
        override fun onReceivedTouchIconUrl(view: WebView, url: String?, precomposed: Boolean) =
            delegate.onReceivedTouchIconUrl(view, url, precomposed)
        override fun onShowCustomView(view: View, callback: CustomViewCallback) = delegate.onShowCustomView(view, callback)
        override fun onHideCustomView() = delegate.onHideCustomView()
        override fun onGeolocationPermissionsShowPrompt(origin: String, callback: GeolocationPermissions.Callback) =
            delegate.onGeolocationPermissionsShowPrompt(origin, callback)
        override fun onGeolocationPermissionsHidePrompt() = delegate.onGeolocationPermissionsHidePrompt()
        override fun onShowFileChooser(view: WebView, callback: ValueCallback<Array<Uri>>, params: FileChooserParams): Boolean =
            delegate.onShowFileChooser(view, callback, params)
        override fun onConsoleMessage(message: ConsoleMessage): Boolean = delegate.onConsoleMessage(message)
        override fun onJsAlert(view: WebView, url: String, message: String, result: JsResult): Boolean =
            delegate.onJsAlert(view, url, message, result)
        override fun onJsConfirm(view: WebView, url: String, message: String, result: JsResult): Boolean =
            delegate.onJsConfirm(view, url, message, result)
        override fun onJsPrompt(view: WebView, url: String, message: String, defaultValue: String?, result: JsPromptResult): Boolean =
            delegate.onJsPrompt(view, url, message, defaultValue, result)
        override fun onCreateWindow(view: WebView, isDialog: Boolean, isUserGesture: Boolean, resultMsg: Message): Boolean =
            delegate.onCreateWindow(view, isDialog, isUserGesture, resultMsg)
        override fun onCloseWindow(window: WebView) = delegate.onCloseWindow(window)
        override fun onRequestFocus(view: WebView) = delegate.onRequestFocus(view)
        override fun getDefaultVideoPoster(): Bitmap? = delegate.defaultVideoPoster
        override fun getVideoLoadingProgressView(): View? = delegate.videoLoadingProgressView
        override fun getVisitedHistory(callback: ValueCallback<Array<String>>) = delegate.getVisitedHistory(callback)
    }

    companion object {
        private const val TAG = "usernode/WebViewMedia"
        private const val MICROPHONE_REQUEST_CODE = 0x4389
        private const val CAMERA_REQUEST_CODE = 0x438A
        // The file and the microphone's key keep their first names: they hold
        // whether Android has already shown its prompt on installed phones.
        private const val PREFS = "webview_microphone"
        private const val KEY_ASKED = "asked"
        private const val KEY_CAMERA_ASKED = "camera_asked"
    }
}
