package com.usernode_labs.usernode.alarm

import android.content.Context
import com.usernode_labs.usernode.session.SessionAuthorityNative
import org.json.JSONObject

/** Native-first admission for Android events that can create runtime work. */
internal object BackgroundRuntimeEventAuthority {
    const val SESSION_ID_KEY = "session_id"
    const val RUNTIME_GENERATION_KEY = "runtime_generation"

    private val unprivilegedAndroidEvents = setOf(
        "android_post_notifications_permission_granted",
        "android_post_notifications_permission_denied",
        "android_exact_alarm_permission_granted",
        "android_exact_alarm_permission_denied",
        "android_battery_optimization_disabled",
    )

    fun isAdmitted(
        context: Context,
        eventType: String,
        eventData: Map<String, Any?>,
    ): Boolean = isAdmitted(
        eventType = eventType,
        eventData = eventData,
        journalIsMissing = {
            runCatching {
                JSONObject(SessionAuthorityNative.admissionJson(context))
                    .optString("status") == "missing_journal"
            }.getOrDefault(false)
        },
        durableAdmission = { sessionId, runtimeGeneration ->
            SessionAuthorityNative.isBackgroundRuntimeAdmitted(
                context,
                sessionId,
                runtimeGeneration,
            )
        },
    )

    internal fun isAdmitted(
        eventType: String,
        eventData: Map<String, Any?>,
        journalIsMissing: () -> Boolean,
        durableAdmission: (String, Long) -> Boolean,
    ): Boolean {
        if (!requiresRuntimeAuthority(eventType)) return true

        // Staged compatibility only: until the vertical cutover creates the
        // journal, the existing application-incarnation fence remains the
        // production owner. The cutover removes this fallback atomically.
        if (journalIsMissing()) return true

        val sessionId = (eventData[SESSION_ID_KEY] as? String)
            ?.takeIf { it.isNotBlank() }
            ?: return false
        val runtimeGeneration = positiveInteger(
            eventData[RUNTIME_GENERATION_KEY],
        ) ?: return false
        return durableAdmission(sessionId, runtimeGeneration)
    }

    internal fun requiresRuntimeAuthority(eventType: String): Boolean =
        eventType.startsWith("android_") && eventType !in unprivilegedAndroidEvents

    private fun positiveInteger(value: Any?): Long? {
        val integer = when (value) {
            is Byte -> value.toLong()
            is Short -> value.toLong()
            is Int -> value.toLong()
            is Long -> value
            else -> return null
        }
        return integer.takeIf { it > 0 }
    }
}
