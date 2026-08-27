package com.usernode_labs.usernode.session

import android.content.Context
import android.util.Log
import com.usernode_labs.usernode.alarm.AlarmMethodChannelHandler
import com.usernode_labs.usernode.alarm.EngineLease
import com.usernode_labs.usernode.alarm.EngineRole
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Interactive-engine-only protocol-2 port. Never register this in headless code. */
internal class InteractiveNativeSessionChannel(
    context: Context,
    messenger: BinaryMessenger,
    private val engineLease: EngineLease,
    private val alarmHandler: AlarmMethodChannelHandler,
) {
    private val applicationContext = context.applicationContext
    private val vault = AndroidNativeSessionVault(applicationContext)
    private val channel = MethodChannel(messenger, CHANNEL)
    private var processProofIssued = false
    private var closed = false

    init {
        check(engineLease.role == EngineRole.INTERACTIVE)
        channel.setMethodCallHandler(::handleMethodCall)
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (closed || !alarmHandler.isCurrentEngine(engineLease)) {
            result.error(
                "stale_interactive_engine",
                "The Flutter engine no longer owns native session authority",
                null,
            )
            return
        }
        try {
            when (call.method) {
                "bootstrapInteractiveRoot" -> bootstrapInteractiveRoot(call, result)
                "prepareNativeSessionExchange" -> prepareExchange(call, result)
                "installNativeSessionCredential" -> installCredential(call, result)
                "retireNativeSessionCredential" -> retireCredential(call, result)
                else -> result.notImplemented()
            }
        } catch (error: NativeSessionProtocolException) {
            result.error(error.code, error.message, null)
        } catch (error: Throwable) {
            Log.e(TAG, "Native session operation failed (${call.method})", error)
            result.error(
                "native_session_unavailable",
                "The native session operation could not be completed",
                null,
            )
        }
    }

    private fun bootstrapInteractiveRoot(call: MethodCall, result: MethodChannel.Result) {
        exactArguments(call.arguments, emptySet(), "bootstrapInteractiveRoot")
        if (processProofIssued) {
            fail("process_root_proof_already_issued", "The process-root proof was already issued")
        }
        val authorityDirectory = File(
            applicationContext.noBackupFilesDir,
            "native_session_v2",
        )
        if ((!authorityDirectory.exists() && !authorityDirectory.mkdirs()) ||
            !authorityDirectory.isDirectory
        ) {
            fail(
                "native_process_storage_unavailable",
                "The native process-root storage is unavailable",
            )
        }
        NativeSessionRust.nativeInstallProcessAuthority(authorityDirectory.absolutePath)
        val proof = NativeSessionRust.nativeIssueProcessRootProof()
        if (proof.size != PROCESS_PROOF_BYTES) {
            proof.fill(0)
            fail("process_root_proof_invalid", "Rust returned an invalid process-root proof")
        }
        processProofIssued = true
        result.success(proof)
    }

    private fun prepareExchange(call: MethodCall, result: MethodChannel.Result) {
        requireProcessRoot()
        val arguments = exactArguments(
            call.arguments,
            setOf("nativeEstablishTicket"),
            "prepareNativeSessionExchange",
        )
        result.success(vault.prepareExchange(arguments["nativeEstablishTicket"]))
    }

    private fun installCredential(call: MethodCall, result: MethodChannel.Result) {
        requireProcessRoot()
        val arguments = exactArguments(
            call.arguments,
            setOf("nativeEstablishTicket", "exchange"),
            "installNativeSessionCredential",
        )
        val claim = vault.installCredential(
            arguments["nativeEstablishTicket"],
            arguments["exchange"],
        )
        result.success(mapOf("installClaim" to claim))
    }

    private fun retireCredential(call: MethodCall, result: MethodChannel.Result) {
        requireProcessRoot()
        val arguments = exactArguments(
            call.arguments,
            setOf("credentialReference", "credentialGeneration", "vaultCommitment"),
            "retireNativeSessionCredential",
        )
        val reference = arguments["credentialReference"] as? String
            ?: fail("invalid_native_retirement", "The credential reference is invalid")
        val generation = exactInt(arguments["credentialGeneration"], "credential generation")
        val commitment = arguments["vaultCommitment"] as? ByteArray
            ?: fail("invalid_native_retirement", "The vault commitment is invalid")
        try {
            vault.retireCredential(reference, generation, commitment)
        } finally {
            commitment.fill(0)
        }
        result.success(null)
    }

    private fun requireProcessRoot() {
        if (!processProofIssued) {
            fail("process_root_unavailable", "The interactive process root is unavailable")
        }
    }

    /** Revokes only this exact interactive engine's root. A stale Activity cannot revoke a successor. */
    fun closeIfCurrent() {
        if (closed) return
        closed = true
        channel.setMethodCallHandler(null)
        if (!alarmHandler.isCurrentEngine(engineLease)) return
        try {
            NativeSessionRust.nativeRevokeProcessRoot()
        } catch (error: Throwable) {
            // A failed revoke intentionally leaves the next root acquisition closed.
            Log.e(TAG, "Could not revoke native process-root authority", error)
        }
    }

    private fun exactArguments(
        raw: Any?,
        expected: Set<String>,
        label: String,
    ): Map<String, Any?> {
        if (raw !is Map<*, *> || raw.keys.any { it !is String }) {
            fail("invalid_native_session_arguments", "$label arguments are invalid")
        }
        @Suppress("UNCHECKED_CAST")
        val arguments = raw as Map<String, Any?>
        if (arguments.keys != expected) {
            fail("invalid_native_session_arguments", "$label arguments have unexpected fields")
        }
        return arguments
    }

    private fun exactInt(raw: Any?, label: String): Int = when (raw) {
        is Int -> raw
        is Long -> if (raw in Int.MIN_VALUE..Int.MAX_VALUE) raw.toInt() else {
            fail("invalid_native_session_arguments", "$label is out of range")
        }
        else -> fail("invalid_native_session_arguments", "$label must be an integer")
    }

    private fun fail(code: String, message: String): Nothing =
        throw NativeSessionProtocolException(code, message)

    private companion object {
        const val CHANNEL = "com.usernode.app/native_session_v2"
        const val PROCESS_PROOF_BYTES = 32
        const val TAG = "usernode/NativeSession"
    }
}
