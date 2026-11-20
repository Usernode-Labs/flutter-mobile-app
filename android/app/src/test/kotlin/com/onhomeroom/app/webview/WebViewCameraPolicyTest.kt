package com.onhomeroom.app.webview

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WebViewCameraPolicyTest {
    private val origin = "https://app.onhomeroom.com"
    private val policy = WebViewCameraPolicy(origin)
    private val video = arrayOf(WebViewCameraPolicy.VIDEO_CAPTURE)

    @Test
    fun `allows Homeroom and an embedded app under Homeroom's top frame`() {
        assertTrue(policy.allows("$origin/", "$origin/#app/same-place", video))
        assertTrue(policy.allows("https://same-place.onhomeroom.app/", "$origin/#app/same-place", video))
        assertTrue(policy.allows("https://photos.example.com", "$origin/path?q=1", video))
    }

    @Test
    fun `rejects any frame under a top frame that is not Homeroom`() {
        for (top in listOf(
            null, "", "https://example.com", "https://app.onhomeroom.com.evil.example",
            "http://app.onhomeroom.com", "https://app.onhomeroom.com:444",
            "https://person@app.onhomeroom.com", "data:text/html,hello", "about:blank",
        )) {
            assertFalse(top, policy.allows(origin, top, video))
            assertFalse(top, policy.allows("https://photos.example.com", top, video))
        }
    }

    @Test
    fun `rejects a requesting frame that is not HTTPS`() {
        for (requestOrigin in listOf(
            null, "", "not a URL", "http://photos.example.com", "data:text/html,hello",
            "about:blank", "null", "https://photos.example.com:99999",
        )) {
            assertFalse(requestOrigin, policy.allows(requestOrigin, origin, video))
        }
    }

    @Test
    fun `never grants the microphone other resources or combined requests`() {
        for (resources in listOf(
            emptyArray(), arrayOf(WebViewMicrophonePolicy.AUDIO_CAPTURE),
            arrayOf(WebViewCameraPolicy.VIDEO_CAPTURE, WebViewMicrophonePolicy.AUDIO_CAPTURE),
            arrayOf("android.webkit.resource.PROTECTED_MEDIA_ID"), arrayOf("future.resource"),
        )) {
            assertFalse(policy.allows(origin, origin, resources))
        }
    }

    @Test
    fun `invalid deployment configuration fails closed`() {
        for (configured in listOf("", "http://app.onhomeroom.com", "garbage")) {
            assertFalse(WebViewCameraPolicy(configured).allows(origin, origin, video))
        }
    }
}
