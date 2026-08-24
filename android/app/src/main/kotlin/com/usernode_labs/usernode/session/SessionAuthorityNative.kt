package com.usernode_labs.usernode.session

import android.content.Context
import com.usernode_labs.usernode.alarm.RuntimeOwner
import java.io.File

/** Thin, read-only Android client for the Rust-owned process authority. */
internal object SessionAuthorityNative {
    private const val DIRECTORY_NAME = "session-authority"

    private val libraryLoaded = try {
        System.loadLibrary("usernode")
        true
    } catch (_: UnsatisfiedLinkError) {
        false
    }

    private external fun readAdmissionJson(journalDirectory: String): String

    private external fun admitsBackgroundRuntime(
        journalDirectory: String,
        sessionId: String,
        runtimeGeneration: Long,
        accountId: String,
        address: String,
    ): Boolean

    fun admissionJson(context: Context): String {
        if (!libraryLoaded) {
            return """{"status":"terminal","reason":"Rust authority library unavailable"}"""
        }
        return readAdmissionJson(journalDirectory(context))
    }

    fun isBackgroundRuntimeAdmitted(
        context: Context,
        owner: RuntimeOwner,
    ): Boolean {
        if (!libraryLoaded) {
            return false
        }
        return admitsBackgroundRuntime(
            journalDirectory(context),
            owner.sessionId,
            owner.runtimeGeneration,
            owner.accountId,
            owner.address,
        )
    }

    private fun journalDirectory(context: Context): String =
        File(context.filesDir, DIRECTORY_NAME).absolutePath
}
