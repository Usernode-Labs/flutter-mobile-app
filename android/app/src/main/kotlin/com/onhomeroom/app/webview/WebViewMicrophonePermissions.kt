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

/** Owns runtime microphone requests for this Activity's WebViews. */
class WebViewMicrophonePermissions(
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
        val policy: WebViewMicrophonePolicy,
    )
    /** Requests waiting on the one OS prompt; all of them get its answer. */
    private val pending = mutableListOf<Pending>()
    private var permissionPromptInFlight = false
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
                    webView.webChromeClient = MicrophoneClient(
                        delegate, webView, WebViewMicrophonePolicy(origin),
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
            value.policy.allows(
                value.request.origin.toString(), value.webView.url, value.request.resources,
            )

    private fun hasMicrophonePermission(): Boolean =
        ContextCompat.checkSelfPermission(activity, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    private fun request(request: PermissionRequest, webView: WebView, policy: WebViewMicrophonePolicy) {
        val value = Pending(request, webView, policy)
        if (!eligible(value)) {
            request.deny()
            return
        }
        if (hasMicrophonePermission()) {
            request.grant(arrayOf(PermissionRequest.RESOURCE_AUDIO_CAPTURE))
            return
        }
        if (permissionPromptInFlight) {
            pending += value
            return
        }
        // Android stops showing its prompt after a permanent denial, so point
        // the user to Settings instead of failing silently.
        if (prefs.getBoolean(KEY_ASKED, false) &&
            !ActivityCompat.shouldShowRequestPermissionRationale(activity, Manifest.permission.RECORD_AUDIO)
        ) {
            request.deny()
            showSettingsPrompt()
            return
        }
        pending += value
        permissionPromptInFlight = true
        prefs.edit().putBoolean(KEY_ASKED, true).apply()
        try {
            ActivityCompat.requestPermissions(activity, arrayOf(Manifest.permission.RECORD_AUDIO), REQUEST_CODE)
        } catch (e: RuntimeException) {
            Log.w(TAG, "Microphone permission prompt failed", e)
            cancelPending()
        }
    }

    fun onRequestPermissionsResult(requestCode: Int) {
        if (requestCode != REQUEST_CODE) return
        permissionPromptInFlight = false
        val values = pending.toList()
        pending.clear()
        val granted = hasMicrophonePermission()
        for (value in values) {
            // Recheck after the OS dialog: it may outlive a navigation.
            if (granted && eligible(value)) {
                value.request.grant(arrayOf(PermissionRequest.RESOURCE_AUDIO_CAPTURE))
            } else {
                value.request.deny()
            }
        }
    }

    private fun cancelPending() {
        permissionPromptInFlight = false
        val values = pending.toList()
        pending.clear()
        values.forEach { it.request.deny() }
    }

    private fun showSettingsPrompt() {
        if (activity.isFinishing || activity.isDestroyed) return
        AlertDialog.Builder(activity)
            .setTitle(R.string.webview_microphone_blocked_title)
            .setMessage(R.string.webview_microphone_blocked_message)
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
        cancelPending()
        channel.setMethodCallHandler(null)
    }

    /**
     * Keep the plugin's chooser, dialogs, console and secure popup handling.
     * Only microphone requests stay native; anything else still reaches the
     * Dart `onPermissionRequest` handler through the plugin's client.
     */
    private inner class MicrophoneClient(
        private val delegate: SecureWebChromeClient,
        private val webView: WebView,
        private val policy: WebViewMicrophonePolicy,
    ) : SecureWebChromeClient() {
        override fun onPermissionRequest(request: PermissionRequest) {
            if (PermissionRequest.RESOURCE_AUDIO_CAPTURE in request.resources) {
                this@WebViewMicrophonePermissions.request(request, webView, policy)
            } else {
                delegate.onPermissionRequest(request)
            }
        }
        override fun onPermissionRequestCanceled(request: PermissionRequest) {
            if (!pending.removeAll { it.request === request }) {
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
        private const val TAG = "usernode/WebViewMic"
        private const val REQUEST_CODE = 0x4389
        private const val PREFS = "webview_microphone"
        private const val KEY_ASKED = "asked"
    }
}
