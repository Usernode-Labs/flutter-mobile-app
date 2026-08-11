package com.usernode_labs.usernode.alarm

import android.content.Context
import java.util.UUID

/** One opaque application-incarnation token shared by native scheduled work. */
class ApplicationIncarnationStore(context: Context) {
    companion object {
        const val EXTRA_APPLICATION_INCARNATION = "applicationIncarnation"
        private const val PREFS_NAME = "application_incarnation"
        private const val TOKEN_KEY = "token"
        private val lock = Any()

        @Volatile
        private var terminalResetRequested = false
    }

    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun ensure(): String? = synchronized(lock) {
        if (terminalResetRequested) return@synchronized null
        val existing = storedCurrent()
        if (existing != null) return@synchronized existing
        UUID.randomUUID().toString().also { created ->
            check(prefs.edit().putString(TOKEN_KEY, created).commit()) {
                "Could not persist application incarnation"
            }
        }
    }

    fun current(): String? = synchronized(lock) {
        if (terminalResetRequested) null else storedCurrent()
    }

    fun matches(captured: String?): Boolean {
        val current = current()
        return captured != null && current != null && captured == current
    }

    fun invalidate(): Boolean = synchronized(lock) {
        terminalResetRequested = true
        prefs.edit().remove(TOKEN_KEY).commit()
    }

    fun clear(): Boolean = synchronized(lock) {
        prefs.edit().clear().commit()
    }

    private fun storedCurrent(): String? =
        prefs.getString(TOKEN_KEY, null)?.takeIf { it.isNotBlank() }
}
