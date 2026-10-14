package com.onhomeroom.app.webview

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class WebViewMicrophonePolicyTest {
    private val origin = "https://app.onhomeroom.com"
    private val policy = WebViewMicrophonePolicy(origin)
    private val audio = arrayOf(WebViewMicrophonePolicy.AUDIO_CAPTURE)

    @Test
    fun `allows Homeroom audio in its own top frame`() {
        assertTrue(policy.allows("$origin/", "$origin/#messages", audio))
        assertTrue(policy.allows("https://APP.ONHOMEROOM.COM:443", "$origin/path?q=1", audio))
    }

    @Test
    fun `rejects external and preview iframes inside trusted Homeroom`() {
        for (requestOrigin in listOf(
            "https://example.com", "https://preview.onhomeroom.com",
            "https://app.onhomeroom.com.evil.example", "https://onhomeroom.com",
        )) {
            assertFalse(requestOrigin, policy.allows(requestOrigin, origin, audio))
        }
    }

    @Test
    fun `rejects trusted iframe under an untrusted top frame`() {
        assertFalse(policy.allows(origin, "https://example.com", audio))
    }

    @Test
    fun `rejects insecure malformed missing and different port origins`() {
        for (url in listOf(
            null, "", "not a URL", "http://app.onhomeroom.com",
            "https://app.onhomeroom.com:444", "https://app.onhomeroom.com:99999",
            "https://person@app.onhomeroom.com", "data:text/html,hello", "about:blank",
        )) {
            assertFalse(url, policy.allows(url, origin, audio))
            assertFalse(url, policy.allows(origin, url, audio))
        }
    }

    @Test
    fun `never grants camera other resources or combined requests`() {
        for (resources in listOf(
            emptyArray(), arrayOf("android.webkit.resource.VIDEO_CAPTURE"),
            arrayOf(WebViewMicrophonePolicy.AUDIO_CAPTURE, "android.webkit.resource.VIDEO_CAPTURE"),
            arrayOf("android.webkit.resource.PROTECTED_MEDIA_ID"), arrayOf("future.resource"),
        )) {
            assertFalse(policy.allows(origin, origin, resources))
        }
    }

    @Test
    fun `invalid deployment configuration fails closed`() {
        for (configured in listOf("", "http://app.onhomeroom.com", "garbage")) {
            assertFalse(WebViewMicrophonePolicy(configured).allows(origin, origin, audio))
        }
    }

    @Test
    fun `uses the configured deployment rather than a hostname suffix`() {
        val staging = "https://staging.example.com:8443"
        val configured = WebViewMicrophonePolicy(staging)
        assertTrue(configured.allows(staging, "$staging/#messages", audio))
        assertFalse(configured.allows(origin, origin, audio))
        assertFalse(configured.allows("https://staging.example.com", staging, audio))
    }
}
