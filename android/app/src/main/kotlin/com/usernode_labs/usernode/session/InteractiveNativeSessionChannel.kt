package com.usernode_labs.usernode.session

import android.content.Context
import android.util.Log
import android.os.Handler
import android.os.Looper
import com.usernode_labs.usernode.alarm.AlarmMethodChannelHandler
import com.usernode_labs.usernode.alarm.EngineLease
import com.usernode_labs.usernode.alarm.EngineRole
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/** Interactive-engine-only protocol-2 port. Never register this in headless code. */
internal class InteractiveNativeSessionChannel(
    context: Context,
    messenger: BinaryMessenger,
    private val engineLease: EngineLease,
    private val alarmHandler: AlarmMethodChannelHandler,
) {
    private val applicationContext = context.applicationContext
    private val vault = AndroidNativeSessionPlatform.vault(applicationContext)
    private val channel = MethodChannel(messenger, CHANNEL)
    private var processProofIssued = false
    private var closed = false
    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker: ExecutorService = Executors.newSingleThreadExecutor { task ->
        Thread(task, "usernode-interactive-session").apply { isDaemon = true }
    }
    private val processTransportClaim = ByteArray(PROCESS_CLAIM_BYTES).also {
        SecureRandom().nextBytes(it)
    }

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
                "redeemNativeSessionHandoff" -> redeemHandoff(call, result)
                "prepareNativeSessionExchange" -> prepareExchange(call, result)
                "installNativeSessionCredential" -> installCredential(call, result)
                "discardUncommittedNativeSessionCredential" -> discardUncommittedCredential(call, result)
                "retireNativeSessionCredential" -> retireCredential(call, result)
                "revokeNativeSessionCredential" -> revokeCredential(call, result)
                "recoverNativeSession" -> recoverNativeSession(call, result)
                "runInteractiveProducerWake" -> runInteractiveProducerWake(call, result)
                "stageNativeProducerPolicy" -> stageProducerPolicy(call, result)
                "getNativePushStatus" -> getPushStatus(call, result)
                "registerNativePush" -> registerPush(call, result)
                "unregisterNativePush" -> unregisterPush(call, result)
                "resolveNativeZkPassportChallenge" -> resolveZkPassportChallenge(call, result)
                "completeNativeZkPassport" -> completeZkPassport(call, result)
                else -> result.notImplemented()
            }
        } catch (error: NativeSessionProtocolException) {
            result.error(error.code, error.message, null)
        } catch (error: NativeManagedHttpException) {
            result.error(
                "native_managed_http_error",
                "The native managed request failed",
                mapOf(
                    "statusCode" to error.statusCode,
                    "code" to error.errorCode,
                    "latestMutationRevision" to error.latestMutationRevision,
                ),
            )
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
        val arguments = exactArguments(
            call.arguments,
            setOf("mobileApiBaseUrl"),
            "bootstrapInteractiveRoot",
        )
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
        val mobileApiBaseUrl = arguments["mobileApiBaseUrl"] as? String
            ?: fail("invalid_native_api_base_url", "The native mobile API base URL is invalid")
        vault.configureMobileApiBaseUrl(mobileApiBaseUrl)
        val proof = NativeSessionRust.nativeIssueProcessRootProof()
        if (proof.size != PROCESS_PROOF_BYTES) {
            proof.fill(0)
            fail("process_root_proof_invalid", "Rust returned an invalid process-root proof")
        }
        processProofIssued = true
        result.success(
            mapOf(
                "processRootProof" to proof,
                "processTransportClaim" to processTransportClaim.copyOf(),
            ),
        )
    }

    private fun redeemHandoff(call: MethodCall, result: MethodChannel.Result) {
        requireProcessRoot()
        val arguments = exactArguments(
            call.arguments,
            setOf("attemptId", "processTransportClaim"),
            "redeemNativeSessionHandoff",
        )
        requireProcessTransportClaim(arguments)
        val attemptId = arguments["attemptId"] as? String
            ?: fail("native_establish_request_invalid", "The native attempt id is invalid")
        runWorker(result) { vault.redeemHandoff(attemptId) }
    }

    private fun prepareExchange(call: MethodCall, result: MethodChannel.Result) {
        requireProcessRoot()
        val arguments = exactArguments(
            call.arguments,
            setOf("nativeEstablishTicket", "processTransportClaim"),
            "prepareNativeSessionExchange",
        )
        requireProcessTransportClaim(arguments)
        result.success(vault.prepareExchange(arguments["nativeEstablishTicket"]))
    }

    private fun installCredential(call: MethodCall, result: MethodChannel.Result) {
        requireProcessRoot()
        val arguments = exactArguments(
            call.arguments,
            setOf("nativeEstablishTicket", "exchange", "processTransportClaim"),
            "installNativeSessionCredential",
        )
        requireProcessTransportClaim(arguments)
        val claim = vault.installCredential(
            arguments["nativeEstablishTicket"],
            arguments["exchange"],
        )
        result.success(mapOf("installClaim" to claim))
    }

    private fun discardUncommittedCredential(call: MethodCall, result: MethodChannel.Result) {
        requireProcessRoot()
        val arguments = exactArguments(
            call.arguments,
            setOf("attemptId", "processTransportClaim"),
            "discardUncommittedNativeSessionCredential",
        )
        requireProcessTransportClaim(arguments)
        vault.discardUncommittedCredential(
            arguments["attemptId"] as? String
                ?: fail("invalid_native_establishment_cleanup", "The native attempt id is invalid"),
        )
        result.success(null)
    }

    private fun revokeCredential(call: MethodCall, result: MethodChannel.Result) {
        // Terminal intent may already have cleared the producer Ready selector.
        // The private process-root transport claim is the authority for teardown.
        requireProcessRoot()
        val arguments = exactArguments(
            call.arguments,
            setOf("expectedRevision", "processTransportClaim"),
            "revokeNativeSessionCredential",
        )
        requireProcessTransportClaim(arguments)
        exactLong(arguments["expectedRevision"], "expected revision")
        runWorker(result) {
            mapOf(
                "status" to when (vault.revokeCredentialOnServer()) {
                    NativeCredentialServerRevocation.DEFINITIVELY_ABSENT -> "definitivelyAbsent"
                    NativeCredentialServerRevocation.UNCERTAIN -> "uncertain"
                },
            )
        }
    }

    private fun retireCredential(call: MethodCall, result: MethodChannel.Result) {
        requireProcessRoot()
        val arguments = exactArguments(
            call.arguments,
            setOf(
                "credentialReference",
                "credentialGeneration",
                "vaultCommitment",
                "readyRevision",
                "processTransportClaim",
            ),
            "retireNativeSessionCredential",
        )
        requireProcessTransportClaim(arguments)
        val reference = arguments["credentialReference"] as? String
            ?: fail("invalid_native_retirement", "The credential reference is invalid")
        val generation = exactInt(arguments["credentialGeneration"], "credential generation")
        val commitment = arguments["vaultCommitment"] as? ByteArray
            ?: fail("invalid_native_retirement", "The vault commitment is invalid")
        try {
            vault.retireCredential(reference, generation, commitment)
            NativeProducerWakeCoordinator.clearReady(
                applicationContext,
                exactLong(arguments["readyRevision"], "ready revision"),
            )
        } finally {
            commitment.fill(0)
        }
        result.success(null)
    }

    private fun recoverNativeSession(call: MethodCall, result: MethodChannel.Result) {
        requireProcessRoot()
        val arguments = exactArguments(
            call.arguments,
            setOf("expectedRevision", "processTransportClaim"),
            "recoverNativeSession",
        )
        requireProcessTransportClaim(arguments)
        val expectedRevision = exactLong(arguments["expectedRevision"], "expected revision")
        runWorker(result) {
            when (val stage = vault.stageColdInstalledCredential()) {
                is ColdCredentialStage.Present -> mapOf(
                    "status" to "present",
                    "installClaim" to stage.installClaim,
                )
                ColdCredentialStage.Absent -> mapOf(
                    "status" to "absent",
                    "nativeRevision" to NativeSessionRust
                        .nativeResolveColdCredentialAbsentV1(expectedRevision),
                )
                ColdCredentialStage.Uncertain -> mapOf("status" to "uncertain")
            }
        }
    }

    private fun runInteractiveProducerWake(call: MethodCall, result: MethodChannel.Result) {
        requireProcessRoot()
        val arguments = exactArguments(
            call.arguments,
            setOf("expectedRevision", "refreshPolicy", "processTransportClaim"),
            "runInteractiveProducerWake",
        )
        requireProcessTransportClaim(arguments)
        val expectedRevision = exactLong(arguments["expectedRevision"], "expected revision")
        val refreshPolicy = arguments["refreshPolicy"] as? Boolean
            ?: fail("invalid_native_wake", "The native wake request is invalid")
        NativeProducerWakeCoordinator.submit(
            applicationContext,
            ProducerWakeSource.FOREGROUND_RESUME,
            expectedRevision = expectedRevision,
            refreshPolicy = refreshPolicy,
        ) { outcome ->
            finishWorker(
                result,
                mapOf("outcome" to outcome.name.lowercase()),
                null,
            )
        }
    }

    private fun stageProducerPolicy(call: MethodCall, result: MethodChannel.Result) {
        val arguments = managedArguments(
            call,
            setOf("delegated", "expectedRevision", "processTransportClaim"),
            "stageNativeProducerPolicy",
        )
        val delegated = arguments["delegated"]
        if (delegated != null && delegated !is Boolean) {
            fail("invalid_native_policy_request", "The native producer policy request is invalid")
        }
        runWorker(result) {
            mapOf("installClaim" to vault.stageProducerPolicy(delegated as Boolean?))
        }
    }

    private fun getPushStatus(call: MethodCall, result: MethodChannel.Result) {
        val arguments = managedArguments(
            call,
            setOf("installationId", "expectedRevision", "processTransportClaim"),
            "getNativePushStatus",
        )
        val installationId = arguments["installationId"] as? String
            ?: fail("invalid_native_push_request", "The push status request is invalid")
        runWorker(result) { vault.getPushStatus(installationId) }
    }

    private fun registerPush(call: MethodCall, result: MethodChannel.Result) {
        val arguments = managedArguments(
            call,
            setOf(
                "installationId", "providerToken", "platform", "permissionStatus",
                "mutationRevision", "expectedRevision", "processTransportClaim",
            ),
            "registerNativePush",
        )
        runWorker(result) {
            vault.registerPush(
                arguments["installationId"] as? String
                    ?: fail("invalid_native_push_request", "The push installation is invalid"),
                arguments["providerToken"] as? String
                    ?: fail("invalid_native_push_request", "The push provider token is invalid"),
                arguments["platform"] as? String
                    ?: fail("invalid_native_push_request", "The push platform is invalid"),
                arguments["permissionStatus"] as? String
                    ?: fail("invalid_native_push_request", "The push permission is invalid"),
                exactLong(arguments["mutationRevision"], "mutation revision"),
            )
        }
    }

    private fun unregisterPush(call: MethodCall, result: MethodChannel.Result) {
        val arguments = managedArguments(
            call,
            setOf(
                "installationId", "mutationRevision", "reason", "expectedRevision",
                "processTransportClaim",
            ),
            "unregisterNativePush",
        )
        runWorker(result) {
            vault.unregisterPush(
                arguments["installationId"] as? String
                    ?: fail("invalid_native_push_request", "The push installation is invalid"),
                exactLong(arguments["mutationRevision"], "mutation revision"),
                arguments["reason"] as? String
                    ?: fail("invalid_native_push_request", "The push reason is invalid"),
            )
        }
    }

    private fun completeZkPassport(call: MethodCall, result: MethodChannel.Result) {
        val arguments = managedArguments(
            call,
            setOf(
                "challengeId", "sessionId", "nullifierHex", "completedAt", "expectedRevision",
                "processTransportClaim",
            ),
            "completeNativeZkPassport",
        )
        val completedAt = arguments["completedAt"]
        if (completedAt != null && completedAt !is String) {
            fail("invalid_native_zk_completion", "The zkPassport completion is invalid")
        }
        runWorker(result) {
            vault.completeLegacyZkPassport(
                exactInt(arguments["challengeId"], "challenge id"),
                arguments["sessionId"] as? String
                    ?: fail("invalid_native_zk_completion", "The zkPassport session is invalid"),
                arguments["nullifierHex"] as? String
                    ?: fail("invalid_native_zk_completion", "The zkPassport nullifier is invalid"),
                completedAt as String?,
            )
        }
    }

    private fun resolveZkPassportChallenge(call: MethodCall, result: MethodChannel.Result) {
        managedArguments(
            call,
            setOf("expectedRevision", "processTransportClaim"),
            "resolveNativeZkPassportChallenge",
        )
        runWorker(result) {
            mapOf("challengeId" to vault.resolveLegacyZkPassportChallengeId())
        }
    }

    private fun managedArguments(
        call: MethodCall,
        expected: Set<String>,
        label: String,
    ): Map<String, Any?> {
        requireProcessRoot()
        val arguments = exactArguments(call.arguments, expected, label)
        requireProcessTransportClaim(arguments)
        val revision = exactLong(arguments["expectedRevision"], "expected revision")
        if (!NativeProducerWakeCoordinator.isReady(applicationContext, revision)) {
            fail("native_session_not_current", "The native session is not current")
        }
        return arguments
    }

    private fun runWorker(result: MethodChannel.Result, body: () -> Any?) {
        worker.execute {
            try {
                finishWorker(result, body(), null)
            } catch (error: Throwable) {
                finishWorker(result, null, error)
            }
        }
    }

    private fun finishWorker(
        result: MethodChannel.Result,
        value: Any?,
        error: Throwable?,
    ) {
        mainHandler.post {
            if (closed || !alarmHandler.isCurrentEngine(engineLease)) {
                result.error(
                    "stale_interactive_engine",
                    "The Flutter engine no longer owns native session authority",
                    null,
                )
            } else if (error is NativeSessionProtocolException) {
                result.error(error.code, error.message, null)
            } else if (error is NativeManagedHttpException) {
                result.error(
                    "native_managed_http_error",
                    "The native managed request failed",
                    mapOf(
                        "statusCode" to error.statusCode,
                        "code" to error.errorCode,
                        "latestMutationRevision" to error.latestMutationRevision,
                    ),
                )
            } else if (error != null) {
                Log.e(TAG, "Native session worker failed", error)
                result.error(
                    "native_session_unavailable",
                    "The native session operation could not be completed",
                    null,
                )
            } else {
                result.success(value)
            }
        }
    }

    private fun requireProcessRoot() {
        if (!processProofIssued) {
            fail("process_root_unavailable", "The interactive process root is unavailable")
        }
    }

    private fun requireProcessTransportClaim(arguments: Map<String, Any?>) {
        val presented = arguments["processTransportClaim"] as? ByteArray
            ?: fail("process_transport_claim_invalid", "The process transport claim is invalid")
        val accepted = try {
            presented.size == processTransportClaim.size &&
                MessageDigest.isEqual(presented, processTransportClaim)
        } finally {
            presented.fill(0)
        }
        if (!accepted) {
            fail("process_transport_claim_invalid", "The process transport claim is invalid")
        }
    }

    /** Revokes only this exact interactive engine's root. A stale Activity cannot revoke a successor. */
    fun closeIfCurrent() {
        if (closed) return
        closed = true
        channel.setMethodCallHandler(null)
        worker.shutdownNow()
        processTransportClaim.fill(0)
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

    private fun exactLong(raw: Any?, label: String): Long = when (raw) {
        is Int -> raw.toLong().takeIf { it >= 0 }
        is Long -> raw.takeIf { it >= 0 }
        else -> null
    } ?: fail("invalid_native_session_arguments", "$label must be a non-negative integer")

    private fun fail(code: String, message: String): Nothing =
        throw NativeSessionProtocolException(code, message)

    private companion object {
        const val CHANNEL = "com.usernode.app/native_session"
        const val PROCESS_PROOF_BYTES = 32
        const val PROCESS_CLAIM_BYTES = 32
        const val TAG = "usernode/NativeSession"
    }
}
