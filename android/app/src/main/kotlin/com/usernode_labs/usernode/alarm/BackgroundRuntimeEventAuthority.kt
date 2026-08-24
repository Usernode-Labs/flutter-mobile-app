package com.usernode_labs.usernode.alarm

import android.content.Context
import com.usernode_labs.usernode.session.SessionAuthorityNative
import org.json.JSONObject

/** Native-first admission for Android events that can create runtime work. */
internal object BackgroundRuntimeEventAuthority {
    const val SESSION_ID_KEY = RuntimeOwner.SESSION_ID_KEY
    const val RUNTIME_GENERATION_KEY = RuntimeOwner.RUNTIME_GENERATION_KEY

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
        durableAdmission = { owner ->
            SessionAuthorityNative.isBackgroundRuntimeAdmitted(context, owner)
        },
    )

    internal fun isAdmitted(
        eventType: String,
        eventData: Map<String, Any?>,
        durableAdmission: (RuntimeOwner) -> Boolean,
    ): Boolean {
        if (!requiresRuntimeAuthority(eventType)) return true
        val owner = RuntimeOwner.fromMap(eventData) ?: return false
        return durableAdmission(owner)
    }

    fun currentOwner(context: Context): RuntimeOwner? = runCatching {
        val admission = JSONObject(SessionAuthorityNative.admissionJson(context))
        if (admission.optString("status") != "ready" ||
            !admission.optBoolean("production_desired")
        ) {
            return@runCatching null
        }
        RuntimeOwner.fromMap(
            mapOf(
                RuntimeOwner.SESSION_ID_KEY to admission.opt("session_id"),
                RuntimeOwner.RUNTIME_GENERATION_KEY to admission.opt("runtime_generation"),
                RuntimeOwner.ACCOUNT_ID_KEY to admission.opt("account_id"),
                RuntimeOwner.ADDRESS_KEY to admission.opt("address"),
            ),
        )
    }.getOrNull()

    internal fun requiresRuntimeAuthority(eventType: String): Boolean =
        eventType.startsWith("android_") && eventType !in unprivilegedAndroidEvents

}
