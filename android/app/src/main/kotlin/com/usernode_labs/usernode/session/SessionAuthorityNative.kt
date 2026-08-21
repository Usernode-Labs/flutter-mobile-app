package com.usernode_labs.usernode.session

import android.content.Context
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
    ): Boolean

    fun admissionJson(context: Context): String {
        if (!libraryLoaded) {
            return """{"status":"terminal","reason":"Rust authority library unavailable"}"""
        }
        return readAdmissionJson(journalDirectory(context))
    }

    fun isBackgroundRuntimeAdmitted(
        context: Context,
        sessionId: String,
        runtimeGeneration: Long,
    ): Boolean {
        if (!libraryLoaded || sessionId.isBlank() || runtimeGeneration <= 0) {
            return false
        }
        return admitsBackgroundRuntime(
            journalDirectory(context),
            sessionId,
            runtimeGeneration,
        )
    }

    private fun journalDirectory(context: Context): String =
        File(context.filesDir, DIRECTORY_NAME).absolutePath
}
