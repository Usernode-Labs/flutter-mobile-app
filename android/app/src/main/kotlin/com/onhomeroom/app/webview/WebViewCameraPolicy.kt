package com.onhomeroom.app.webview

/**
 * Camera-only access for pages shown under the configured HTTPS origin:
 * Homeroom itself and the apps it embeds.
 *
 * An embedded app is another origin, and which apps may use the camera is
 * Homeroom's decision, not this class's. Homeroom names `camera` in an app
 * frame's `allow` attribute only after the person allowed that app (its App
 * permissions), and the WebView refuses `getUserMedia` in a cross-origin
 * frame without that attribute before any request reaches the host app. So
 * the requesting origin only has to be HTTPS; what this class holds is that
 * the page on top is Homeroom, that the request is for the camera alone, and
 * that nothing is granted to a top frame somebody navigated elsewhere.
 */
internal class WebViewCameraPolicy(trustedOrigin: String) {
    private val trusted = httpsOriginOf(trustedOrigin)

    fun allows(requestOrigin: String?, topFrameUrl: String?, resources: Array<String>): Boolean =
        trusted != null && httpsOriginOf(requestOrigin) != null &&
            httpsOriginOf(topFrameUrl) == trusted &&
            resources.contentEquals(arrayOf(VIDEO_CAPTURE))

    companion object {
        const val VIDEO_CAPTURE = "android.webkit.resource.VIDEO_CAPTURE"
    }
}
