package com.onhomeroom.app.webview

import java.net.URI
import java.util.Locale

/** Scheme, host and port of an HTTPS URL; null for anything else. */
internal fun httpsOriginOf(value: String?): Triple<String, String, Int>? = try {
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
