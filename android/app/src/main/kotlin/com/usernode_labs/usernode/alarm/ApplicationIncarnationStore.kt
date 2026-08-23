package com.usernode_labs.usernode.alarm

import android.content.Context
import java.util.UUID

/** One opaque application-incarnation token shared by native scheduled work. */
class ApplicationIncarnationStore(context: Context) {
    companion object {
        const val EXTRA_APPLICATION_INCARNATION = "applicationIncarnation"
        private const val PREFS_NAME = "application_incarnation"
        private const val TOKEN_KEY = "token"

        @Volatile
        private var terminalResetRequested = false
    }

    private val prefs = context.applicationContext
        .getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun ensure(): String? =
        NativeSchedulingAuthority.process.serialized("incarnation.ensure") {
            if (terminalResetRequested) return@serialized null
            val existing = storedCurrent()
            if (existing != null) return@serialized existing
            UUID.randomUUID().toString().also { created ->
                check(prefs.edit().putString(TOKEN_KEY, created).commit()) {
                    "Could not persist application incarnation"
                }
            }
        }

    fun current(): String? =
        NativeSchedulingAuthority.process.serialized("incarnation.current") {
            if (terminalResetRequested) null else storedCurrent()
        }

    fun matches(captured: String?): Boolean =
        NativeSchedulingAuthority.process.serialized("incarnation.matches") {
            val current = if (terminalResetRequested) null else storedCurrent()
            captured != null && current != null && captured == current
        }

    /**
     * Retires the current token and issues a fresh one.
     *
     * The reversible twin of [invalidate], for the one boundary that keeps the
     * process alive: a scoped sign-out. Durable work scheduled by the retired
     * session no longer [matches], while this process can keep scheduling
     * under the returned token. Returns null once a terminal reset has latched
     * the store shut.
     */
    fun rotate(): String? =
        NativeSchedulingAuthority.process.serialized("incarnation.rotate") {
            if (terminalResetRequested) return@serialized null
            UUID.randomUUID().toString().also { created ->
                check(prefs.edit().putString(TOKEN_KEY, created).commit()) {
                    "Could not persist the rotated application incarnation"
                }
            }
        }

    fun invalidate(): Boolean =
        NativeSchedulingAuthority.process.serialized("incarnation.invalidate") {
            terminalResetRequested = true
            prefs.edit().remove(TOKEN_KEY).commit()
        }

    fun clear(): Boolean =
        NativeSchedulingAuthority.process.serialized("incarnation.clear") {
            prefs.edit().clear().commit()
        }

    private fun storedCurrent(): String? =
        prefs.getString(TOKEN_KEY, null)?.takeIf { it.isNotBlank() }
}
