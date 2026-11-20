package com.onhomeroom.app.webview

/** Audio-only access for the configured HTTPS origin, never an embedded app. */
internal class WebViewMicrophonePolicy(trustedOrigin: String) {
    private val trusted = httpsOriginOf(trustedOrigin)

    fun allows(requestOrigin: String?, topFrameUrl: String?, resources: Array<String>): Boolean =
        trusted != null && httpsOriginOf(requestOrigin) == trusted &&
            httpsOriginOf(topFrameUrl) == trusted &&
            resources.contentEquals(arrayOf(AUDIO_CAPTURE))

    companion object {
        const val AUDIO_CAPTURE = "android.webkit.resource.AUDIO_CAPTURE"
    }
}
