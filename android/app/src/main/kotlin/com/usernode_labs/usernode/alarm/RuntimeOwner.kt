package com.usernode_labs.usernode.alarm

import android.content.Intent

/** Complete Rust-issued owner of Android runtime and scheduling work. */
data class RuntimeOwner(
    val sessionId: String,
    val runtimeGeneration: Long,
    val accountId: String,
    val address: String,
) {
    fun toMap(): Map<String, Any> = mapOf(
        SESSION_ID_KEY to sessionId,
        RUNTIME_GENERATION_KEY to runtimeGeneration,
        ACCOUNT_ID_KEY to accountId,
        ADDRESS_KEY to address,
    )

    fun putInto(intent: Intent) {
        intent.putExtra(SESSION_ID_KEY, sessionId)
        intent.putExtra(RUNTIME_GENERATION_KEY, runtimeGeneration)
        intent.putExtra(ACCOUNT_ID_KEY, accountId)
        intent.putExtra(ADDRESS_KEY, address)
    }

    companion object {
        const val SESSION_ID_KEY = "session_id"
        const val RUNTIME_GENERATION_KEY = "runtime_generation"
        const val ACCOUNT_ID_KEY = "account_id"
        const val ADDRESS_KEY = "address"

        fun fromMap(value: Map<*, *>?): RuntimeOwner? {
            if (value == null) return null
            val sessionId = (value[SESSION_ID_KEY] as? String)
                ?.trim()
                ?.takeIf(String::isNotEmpty)
                ?: return null
            val runtimeGeneration = positiveInteger(value[RUNTIME_GENERATION_KEY])
                ?: return null
            val accountId = (value[ACCOUNT_ID_KEY] as? String)
                ?.trim()
                ?.takeIf(String::isNotEmpty)
                ?: return null
            val address = (value[ADDRESS_KEY] as? String)
                ?.trim()
                ?.takeIf(String::isNotEmpty)
                ?: return null
            return RuntimeOwner(sessionId, runtimeGeneration, accountId, address)
        }

        fun fromIntent(intent: Intent?): RuntimeOwner? {
            val extras = intent?.extras ?: return null
            return fromMap(
                mapOf(
                    SESSION_ID_KEY to extras.get(SESSION_ID_KEY),
                    RUNTIME_GENERATION_KEY to extras.get(RUNTIME_GENERATION_KEY),
                    ACCOUNT_ID_KEY to extras.get(ACCOUNT_ID_KEY),
                    ADDRESS_KEY to extras.get(ADDRESS_KEY),
                ),
            )
        }

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
}
