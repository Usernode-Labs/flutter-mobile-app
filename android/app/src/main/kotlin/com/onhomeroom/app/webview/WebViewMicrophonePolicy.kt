package com.onhomeroom.app.webview

import java.net.URI
import java.util.Locale

/** Audio-only access for the configured HTTPS origin, never an embedded app. */
internal class WebViewMicrophonePolicy(trustedOrigin: String) {
    private val trusted = originOf(trustedOrigin)

    fun allows(requestOrigin: String?, topFrameUrl: String?, resources: Array<String>): Boolean =
        trusted != null && originOf(requestOrigin) == trusted &&
            originOf(topFrameUrl) == trusted &&
            resources.contentEquals(arrayOf(AUDIO_CAPTURE))

    companion object {
        const val AUDIO_CAPTURE = "android.webkit.resource.AUDIO_CAPTURE"

        private fun originOf(value: String?): Triple<String, String, Int>? = try {
            val uri = URI(value ?: "")
            val scheme = uri.scheme?.lowercase(Locale.ROOT)
            val host = uri.host?.lowercase(Locale.ROOT)
            if (scheme != "https" || host.isNullOrBlank() || uri.rawUserInfo != null ||
                uri.port < -1 || uri.port > 65535
            ) {
                null
            } else {
                Triple(scheme, host, if (uri.port == -1) 443 else uri.port)
            }
        } catch (_: Exception) {
            null
        }
    }
}
