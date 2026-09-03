package com.usernode_labs.usernode.session

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.webkit.CookieManager
import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.nio.charset.StandardCharsets
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.SecureRandom
import java.security.Signature
import java.security.interfaces.ECPublicKey
import java.security.interfaces.RSAPublicKey
import java.security.spec.ECGenParameterSpec
import java.security.spec.MGF1ParameterSpec
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.OAEPParameterSpec
import javax.crypto.spec.PSource
import org.json.JSONObject

/**
 * Purpose-specific Android owner for protocol-2 installation keys and vault data.
 *
 * The only decrypted credential path ends in [NativeSessionRust]. Callers can
 * request the exact public exchange, install one matching compact JWE, or
 * compare-delete the committed generation. They cannot sign arbitrary bytes,
 * decrypt arbitrary ciphertext, or read a stored credential.
 */
internal class AndroidNativeSessionVault(context: Context) {
    private val applicationContext = context.applicationContext
    private val preferences: SharedPreferences = applicationContext.getSharedPreferences(
        PREFERENCES_NAME,
        Context.MODE_PRIVATE,
    )
    private val secureRandom = SecureRandom()
    private var http: NativeSessionHttp? = null

    @Synchronized
    fun configureMobileApiBaseUrl(value: String) {
        val configured = NativeSessionHttp(value)
        val existing = http
        if (existing != null) {
            // The engine lease may be replaced, but a process may not switch
            // the credential's authenticated origin underneath a live vault.
            if (existing.canonicalBaseUrl != configured.canonicalBaseUrl) {
                requireOriginMayChange()
                persistMobileApiBaseUrl(configured.canonicalBaseUrl)
                http = configured
            }
            return
        }
        val persisted = preferences.getString(MOBILE_API_BASE_URL_KEY, null)
        if (persisted != null && persisted != configured.canonicalBaseUrl) {
            requireOriginMayChange()
        }
        persistMobileApiBaseUrl(configured.canonicalBaseUrl)
        http = configured
    }

    private fun requireOriginMayChange() {
        if (preferences.contains(CREDENTIAL_RECORD_KEY)) {
            fail(
                "native_api_origin_conflict",
                "The native mobile API origin changed underneath a live credential",
            )
        }
    }

    private fun persistMobileApiBaseUrl(canonicalBaseUrl: String) {
        if (preferences.getString(MOBILE_API_BASE_URL_KEY, null) == canonicalBaseUrl) return
        if (!preferences.edit().putString(MOBILE_API_BASE_URL_KEY, canonicalBaseUrl).commit() ||
            preferences.getString(MOBILE_API_BASE_URL_KEY, null) != canonicalBaseUrl
        ) {
            fail("native_api_unavailable", "The native mobile API origin could not be persisted")
        }
    }

    @Synchronized
    fun redeemHandoff(attemptId: String): Map<String, Any> {
        NativeSessionProtocol.validateHandoffAttemptId(attemptId)
        val client = configuredHttp()
        val cookieHeader = CookieManager.getInstance().getCookie(client.nativeHandoffTicketUrl)
            ?: fail("native_handoff_cookie_absent", "The native handoff cookie is absent")
        val handoffTokens = cookieHeader.split(';').mapNotNull { part ->
            val pair = part.trim()
            val separator = pair.indexOf('=')
            if (separator <= 0 || pair.substring(0, separator) != HANDOFF_COOKIE_NAME) {
                null
            } else {
                pair.substring(separator + 1)
            }
        }
        if (handoffTokens.size != 1) {
            fail("native_handoff_cookie_invalid", "The native handoff cookie is invalid")
        }
        val handoffToken = handoffTokens.single()
        NativeSessionProtocol.validateHandoffToken(handoffToken)
        return when (val response = client.redeemHandoff(attemptId, handoffToken)) {
            is NativeHttpResult.Success ->
                NativeSessionProtocol.parseTicketResponse(response.body, attemptId)
            NativeHttpResult.Unauthorized -> fail(
                "invalid_native_session_handoff",
                "The native handoff was rejected",
            )
            is NativeHttpResult.Failure -> throw NativeManagedHttpException(
                response.statusCode,
                response.code,
                response.latestMutationRevision,
            )
        }
    }

    @Synchronized
    fun prepareExchange(rawTicket: Any?): Map<String, Any> {
        val ticket = NativeSessionProtocol.parseTicket(rawTicket)
        val installation = loadInstallation()
        val transcript = NativeSessionProtocol.possessionTranscript(ticket, installation)
        val derSignature = try {
            Signature.getInstance("SHA256withECDSA").run {
                initSign(loadPrivateKey(POSSESSION_ALIAS))
                update(transcript)
                sign()
            }
        } finally {
            transcript.fill(0)
        }
        val p1363 = try {
            NativeSessionProtocol.derEcdsaToP1363(derSignature)
        } finally {
            derSignature.fill(0)
        }
        return try {
            NativeSessionProtocol.exchangeRequest(ticket, installation, p1363)
        } finally {
            p1363.fill(0)
        }
    }

    @Synchronized
    fun installCredential(rawTicket: Any?, rawExchange: Any?): ByteArray {
        val ticket = NativeSessionProtocol.parseTicket(rawTicket)
        val installation = loadInstallation()
        val exchange = NativeSessionProtocol.parseExchangeEnvelope(
            rawExchange,
            ticket,
            installation,
        )
        val binding = NativeSessionProtocol.credentialBinding(
            ticket,
            installation,
            exchange,
        )
        val plaintextBytes = decryptCompactJwe(exchange.compactJwe, installation)
        val credential = try {
            NativeSessionProtocol.validateCredentialPlaintext(
                plaintextBytes,
                binding,
                installation,
            )
        } finally {
            plaintextBytes.fill(0)
        }
        return try {
            val fingerprint = credentialFingerprint(binding, installation, credential)
            try {
                val persisted = persistCredential(
                    binding = binding,
                    installation = installation,
                    exchange = exchange,
                    fingerprint = fingerprint,
                    credential = credential,
                )
                try {
                    val frame = buildInstallFrame(
                        binding = binding,
                        installation = installation,
                        credential = credential,
                        leaseExpiresAt = persisted.leaseExpiresAt,
                        commitment = persisted.commitment,
                    )
                    try {
                        NativeSessionRust.nativeStageInstalledCredential(frame).also { claim ->
                            if (claim.size != CLAIM_BYTES) {
                                claim.fill(0)
                                fail(
                                    "native_install_claim_invalid",
                                    "Rust returned an invalid install claim",
                                )
                            }
                        }
                    } finally {
                        frame.fill(0)
                    }
                } finally {
                    persisted.commitment.fill(0)
                }
            } finally {
                fingerprint.fill(0)
            }
        } finally {
            credential.accountScalar.fill(0)
        }
    }

    @Synchronized
    fun retireCredential(reference: String, generation: Int, commitment: ByteArray) {
        if (generation <= 0 || reference.isBlank() ||
            commitment.size != COMMITMENT_BYTES
        ) {
            fail("invalid_native_retirement", "The native retirement directive is invalid")
        }
        val storedRaw = preferences.getString(CREDENTIAL_RECORD_KEY, null) ?: return
        val stored = try {
            parseStoredRecord(storedRaw)
        } catch (error: NativeSessionProtocolException) {
            if (shouldDiscardCredential(error)) {
                compareDeleteExact(storedRaw)
                return
            }
            throw error
        }
        val storedCommitment = NativeSessionProtocol.decodeCanonicalBase64Url(
            stored.getString("vaultCommitment"),
            COMMITMENT_BYTES,
            "stored vault commitment",
        )
        try {
            if (stored.getString("credentialReference") != reference ||
                stored.getInt("credentialGeneration") != generation ||
                !storedCommitment.contentEquals(commitment)
            ) {
                fail("native_retirement_mismatch", "The native retirement directive is mismatched")
            }
            if (preferences.getString(CREDENTIAL_RECORD_KEY, null) != storedRaw) {
                fail("native_retirement_mismatch", "The native credential changed during retirement")
            }
            if (!preferences.edit().remove(CREDENTIAL_RECORD_KEY).commit()) {
                fail("native_vault_write_failed", "The native credential could not be retired")
            }
        } finally {
            storedCommitment.fill(0)
        }
    }

    /** Closed cold-start result from local vault evidence; no service needs to be online. */
    @Synchronized
    fun stageColdInstalledCredential(): ColdCredentialStage {
        return stageLocalColdInstalledCredential()
    }

    /**
     * Purpose-specific evidence consumed only by the private ProducerWake port.
     *
     * Ordinary foreground VRF polls stay local: they send only the durable
     * vault binding Rust already knows. Authenticated policy refresh is
     * reserved for bounded recovery/resume boundaries and delegation writes.
     */
    @Synchronized
    fun producerWakeCredential(
        refreshPolicy: Boolean,
        coldInstallClaim: ByteArray? = null,
    ): ProducerWakeCredential {
        if (coldInstallClaim != null && coldInstallClaim.size != CLAIM_BYTES) {
            fail("native_install_claim_invalid", "The native install claim is invalid")
        }
        if (!refreshPolicy) {
            val storedRaw = preferences.getString(CREDENTIAL_RECORD_KEY, null)
                ?: return ProducerWakeCredential.Absent
            return try {
                ProducerWakeCredential.Present(
                    vaultEvidenceFrame(storedRaw, coldInstallClaim),
                    ByteArray(0),
                )
            } catch (error: NativeSessionProtocolException) {
                if (shouldDiscardCredential(error)) {
                    compareDeleteExact(storedRaw)
                    ProducerWakeCredential.Absent
                } else {
                    ProducerWakeCredential.Uncertain
                }
            } catch (_: Throwable) {
                ProducerWakeCredential.Uncertain
            }
        }

        return when (val material = authenticatedProducerMaterial()) {
            is AuthenticatedProducerMaterial.Present -> try {
                ProducerWakeCredential.Present(
                    vaultEvidenceFrame(material.recovered.storedRaw, coldInstallClaim),
                    material.policyFrame.copyOf(),
                )
            } finally {
                material.close()
            }
            AuthenticatedProducerMaterial.Absent -> ProducerWakeCredential.Absent
            AuthenticatedProducerMaterial.Uncertain -> ProducerWakeCredential.Uncertain
        }
    }

    /** Scalar-bearing cold stage used only after Rust requests tag-5 install. */
    @Synchronized
    fun stageBackgroundColdInstalledCredential(): ColdCredentialStage {
        return stageLocalColdInstalledCredential()
    }

    private fun stageLocalColdInstalledCredential(): ColdCredentialStage {
        val storedRaw = preferences.getString(CREDENTIAL_RECORD_KEY, null)
            ?: return ColdCredentialStage.Absent
        val recovered = try {
            recoverCredential(storedRaw)
        } catch (error: NativeSessionProtocolException) {
            if (shouldDiscardCredential(error)) {
                compareDeleteExact(storedRaw)
                return ColdCredentialStage.Absent
            }
            return ColdCredentialStage.Uncertain
        } catch (_: Throwable) {
            return ColdCredentialStage.Uncertain
        }
        return try {
            stageColdRecoveredCredential(recovered)
        } finally {
            recovered.close()
        }
    }

    /** Fetches and stages one exact policy claim; no bearer or DTO reaches Dart. */
    @Synchronized
    fun stageProducerPolicy(delegated: Boolean?): ByteArray {
        val recovered = recoverCredentialForManagedCall()
        try {
            val response = if (delegated == null) {
                configuredHttp().getProducerPolicy(recovered.credential.bearerToken)
            } else {
                configuredHttp().setProducerPolicy(
                    recovered.credential.bearerToken,
                    delegated,
                    randomPolicyRequestId(),
                )
            }
            val success = requireManagedSuccess(response, recovered)
            val frame = NativeProducerPolicyFrame.encode(
                success.body,
                recovered.binding,
                recovered.credential,
            )
            return try {
                NativeSessionRust.nativeStageProducerPolicyV1(frame).also { claim ->
                    if (claim.size != CLAIM_BYTES) {
                        claim.fill(0)
                        fail("native_policy_claim_invalid", "Rust returned an invalid policy claim")
                    }
                }
            } finally {
                frame.fill(0)
            }
        } finally {
            recovered.close()
        }
    }

    @Synchronized
    fun getPushStatus(installationId: String): Map<String, Any> {
        validateInstallationUuid(installationId)
        val recovered = recoverCredentialForManagedCall()
        try {
            val response = requireManagedSuccess(
                configuredHttp().getPushStatus(recovered.credential.bearerToken, installationId),
                recovered,
            )
            return NativePushResponse.status(response.body)
        } finally {
            recovered.close()
        }
    }

    @Synchronized
    fun registerPush(
        installationId: String,
        providerToken: String,
        platform: String,
        permissionStatus: String,
        mutationRevision: Long,
    ): Map<String, Any> {
        validatePushMutation(
            installationId,
            providerToken,
            platform,
            permissionStatus,
            mutationRevision,
        )
        val recovered = recoverCredentialForManagedCall()
        try {
            val response = requireManagedSuccess(
                configuredHttp().registerPush(
                    recovered.credential.bearerToken,
                    installationId,
                    providerToken,
                    platform,
                    permissionStatus,
                    mutationRevision,
                ),
                recovered,
            )
            return NativePushResponse.mutation(
                response.body,
                installationId,
                mutationRevision,
                registered = true,
            )
        } finally {
            recovered.close()
        }
    }

    @Synchronized
    fun unregisterPush(
        installationId: String,
        mutationRevision: Long,
        reason: String,
    ): Map<String, Any> {
        validateInstallationUuid(installationId)
        if (mutationRevision <= 0 || reason !in PUSH_UNREGISTER_REASONS) {
            fail("invalid_native_push_request", "The push unregistration request is invalid")
        }
        val recovered = recoverCredentialForManagedCall()
        try {
            val response = requireManagedSuccess(
                configuredHttp().unregisterPush(
                    recovered.credential.bearerToken,
                    installationId,
                    mutationRevision,
                    reason,
                ),
                recovered,
            )
            return NativePushResponse.mutation(
                response.body,
                installationId,
                mutationRevision,
                registered = false,
            )
        } finally {
            recovered.close()
        }
    }

    /** Revokes only the bearer bound to the currently installed credential. */
    @Synchronized
    fun revokeCredentialOnServer(): NativeCredentialServerRevocation {
        val storedRaw = preferences.getString(CREDENTIAL_RECORD_KEY, null)
            ?: return NativeCredentialServerRevocation.DEFINITIVELY_ABSENT
        val recovered = try {
            recoverCredential(storedRaw)
        } catch (error: NativeSessionProtocolException) {
            if (shouldDiscardCredential(error)) {
                compareDeleteExact(storedRaw)
                return NativeCredentialServerRevocation.DEFINITIVELY_ABSENT
            }
            return NativeCredentialServerRevocation.UNCERTAIN
        } catch (_: Throwable) {
            return NativeCredentialServerRevocation.UNCERTAIN
        }
        return try {
            when (val response = configuredHttp().logout(recovered.credential.bearerToken)) {
                is NativeHttpResult.Success -> {
                    if (response.body.length() == 1 && response.body.opt("success") == true) {
                        NativeCredentialServerRevocation.DEFINITIVELY_ABSENT
                    } else {
                        NativeCredentialServerRevocation.UNCERTAIN
                    }
                }
                NativeHttpResult.Unauthorized -> {
                    compareDeleteExact(recovered.storedRaw)
                    NativeCredentialServerRevocation.DEFINITIVELY_ABSENT
                }
                is NativeHttpResult.Failure -> NativeCredentialServerRevocation.UNCERTAIN
            }
        } finally {
            recovered.close()
        }
    }

    /** Removes only a credential staged by the failed establishment attempt. */
    @Synchronized
    fun discardUncommittedCredential(attemptId: String) {
        if (attemptId.isEmpty() || attemptId.toByteArray(StandardCharsets.UTF_8).size > 64) {
            fail("invalid_native_establishment_cleanup", "The native attempt id is invalid")
        }
        val storedRaw = preferences.getString(CREDENTIAL_RECORD_KEY, null) ?: return
        val stored = parseStoredRecord(storedRaw)
        if (stored.getString("attemptId") == attemptId && !compareDeleteExact(storedRaw)) {
            fail(
                "native_vault_write_failed",
                "The uncommitted native credential could not be discarded",
            )
        }
    }

    /** Rust LoggedOut authoritatively makes every persisted credential stale. */
    @Synchronized
    fun clearOrphanedCredential() {
        val storedRaw = preferences.getString(CREDENTIAL_RECORD_KEY, null) ?: return
        if (!compareDeleteExact(storedRaw)) {
            fail(
                "native_vault_write_failed",
                "The orphaned native credential could not be discarded",
            )
        }
    }

    /** Retained, authenticated challenge lookup; no bearer/API client enters Dart. */
    @Synchronized
    fun resolveLegacyZkPassportChallengeId(): Int {
        val recovered = recoverCredentialForManagedCall()
        try {
            val client = configuredHttp()
            val bearer = recovered.credential.bearerToken
            val seasons = requireManagedSuccess(
                client.getSeasonsForLegacyZkCompletion(bearer),
                recovered,
            ).body.optJSONArray("data")
                ?: fail("invalid_native_zk_completion_response", "The active season response is invalid")
            val activeSeasonIds = buildList {
                for (index in 0 until seasons.length()) {
                    val season = seasons.optJSONObject(index) ?: continue
                    if (season.opt("is_active") != true) continue
                    val id = season.optInt("season_id", -1)
                    if (id <= 0) {
                        fail("invalid_native_zk_completion_response", "The active season response is invalid")
                    }
                    add(id)
                }
            }
            if (activeSeasonIds.size != 1) {
                throw NativeManagedHttpException(
                    409,
                    if (activeSeasonIds.isEmpty()) {
                        "active_zk_challenge_unavailable"
                    } else {
                        "ambiguous_active_zk_challenge"
                    },
                    null,
                )
            }
            val challenges = requireManagedSuccess(
                client.getChallengesForLegacyZkCompletion(bearer, activeSeasonIds.single()),
                recovered,
            ).body.optJSONArray("data")
                ?: fail("invalid_native_zk_completion_response", "The active challenge response is invalid")
            val challengeIds = buildList {
                for (index in 0 until challenges.length()) {
                    val challenge = challenges.optJSONObject(index) ?: continue
                    if (challenge.optString("kind") != ZK_IDENTITY_KIND ||
                        challenge.opt("enabled") == false
                    ) {
                        continue
                    }
                    val id = challenge.optInt("id", -1)
                    if (id <= 0) {
                        fail("invalid_native_zk_completion_response", "The active challenge response is invalid")
                    }
                    add(id)
                }
            }
            if (challengeIds.size != 1) {
                throw NativeManagedHttpException(
                    409,
                    if (challengeIds.isEmpty()) {
                        "active_zk_challenge_unavailable"
                    } else {
                        "ambiguous_active_zk_challenge"
                    },
                    null,
                )
            }
            return challengeIds.single()
        } finally {
            recovered.close()
        }
    }

    /** Exact vault-bound final write; Social revalidates the credential at commit. */
    @Synchronized
    fun completeLegacyZkPassport(
        challengeId: Int,
        sessionId: String,
        nullifierHex: String,
        completedAt: String?,
    ): Map<String, Any> {
        if (challengeId <= 0 ||
            sessionId.isEmpty() || sessionId.length > 255 || sessionId != sessionId.trim() ||
            !ZK_NULLIFIER.matches(nullifierHex) || nullifierHex.length > 255 ||
            (completedAt != null &&
                (completedAt.isEmpty() || completedAt.length > 64 || completedAt != completedAt.trim()))
        ) {
            fail("invalid_native_zk_completion", "The zkPassport completion is invalid")
        }
        val recovered = recoverCredentialForManagedCall()
        try {
            requireManagedSuccess(
                configuredHttp().completeLegacyZkPassport(
                    recovered.credential.bearerToken,
                    challengeId,
                    recovered.credential.address,
                    sessionId,
                    nullifierHex,
                    completedAt,
                ),
                recovered,
            )
            return mapOf("challengeId" to challengeId)
        } finally {
            recovered.close()
        }
    }

    private fun authenticatedProducerMaterial(): AuthenticatedProducerMaterial {
        val storedRaw = preferences.getString(CREDENTIAL_RECORD_KEY, null)
            ?: return AuthenticatedProducerMaterial.Absent
        val recovered = try {
            recoverCredential(storedRaw)
        } catch (error: NativeSessionProtocolException) {
            if (shouldDiscardCredential(error)) {
                compareDeleteExact(storedRaw)
                return AuthenticatedProducerMaterial.Absent
            }
            return AuthenticatedProducerMaterial.Uncertain
        } catch (_: Throwable) {
            return AuthenticatedProducerMaterial.Uncertain
        }
        return when (
            val response = configuredHttp().getProducerPolicy(recovered.credential.bearerToken)
        ) {
            is NativeHttpResult.Success -> try {
                applyCredentialLease(response.credentialLease, recovered, required = true)
                val policy = NativeProducerPolicyFrame.encode(
                    response.body,
                    recovered.binding,
                    recovered.credential,
                )
                AuthenticatedProducerMaterial.Present(recovered, policy)
            } catch (_: Throwable) {
                recovered.close()
                AuthenticatedProducerMaterial.Uncertain
            }
            NativeHttpResult.Unauthorized -> {
                compareDeleteExact(recovered.storedRaw)
                recovered.close()
                AuthenticatedProducerMaterial.Absent
            }
            is NativeHttpResult.Failure -> {
                try {
                    applyCredentialLease(response.credentialLease, recovered, required = false)
                } catch (_: Throwable) {
                    recovered.close()
                    return AuthenticatedProducerMaterial.Uncertain
                }
                recovered.close()
                AuthenticatedProducerMaterial.Uncertain
            }
        }
    }

    private fun stageColdRecoveredCredential(
        recovered: RecoveredCredential,
    ): ColdCredentialStage {
        val claim = NativeSessionRust.nativeStageColdInstalledCredentialV1(
            recovered.installFrame,
        )
        if (claim.size != CLAIM_BYTES) {
            claim.fill(0)
            fail("native_install_claim_invalid", "Rust returned an invalid install claim")
        }
        return ColdCredentialStage.Present(claim)
    }

    private fun recoverCredentialForManagedCall(): RecoveredCredential {
        val raw = preferences.getString(CREDENTIAL_RECORD_KEY, null)
            ?: fail("native_vault_absent", "The native credential is absent")
        return try {
            recoverCredential(raw)
        } catch (error: NativeSessionProtocolException) {
            if (shouldDiscardCredential(error)) compareDeleteExact(raw)
            throw error
        }
    }

    private fun requireManagedSuccess(
        response: NativeHttpResult,
        recovered: RecoveredCredential,
    ): NativeHttpResult.Success = when (response) {
        is NativeHttpResult.Success -> response.also {
            applyCredentialLease(it.credentialLease, recovered, required = true)
        }
        NativeHttpResult.Unauthorized -> {
            compareDeleteExact(recovered.storedRaw)
            fail(
                "native_credential_definitively_absent",
                "The authenticated native credential is no longer accepted",
            )
        }
        is NativeHttpResult.Failure -> {
            applyCredentialLease(response.credentialLease, recovered, required = false)
            throw NativeManagedHttpException(
                response.statusCode,
                response.code,
                response.latestMutationRevision,
            )
        }
    }

    private fun applyCredentialLease(
        receipt: NativeCredentialLeaseReceipt?,
        recovered: RecoveredCredential,
        required: Boolean,
    ) {
        if (receipt == null) {
            if (required) {
                fail(
                    "invalid_native_credential_lease_receipt",
                    "The authenticated response has no credential lease receipt",
                )
            }
            return
        }
        if (receipt.credentialReference != recovered.binding.credentialReference ||
            receipt.credentialGeneration != recovered.binding.credentialGeneration
        ) {
            fail(
                "native_credential_lease_mismatch",
                "The credential lease receipt is bound to another credential",
            )
        }

        val currentRaw = preferences.getString(CREDENTIAL_RECORD_KEY, null)
            ?: fail("native_vault_absent", "The native credential is absent")
        val current = parseStoredRecord(currentRaw)
        if (current.getString("credentialReference") != receipt.credentialReference ||
            current.getInt("credentialGeneration") != receipt.credentialGeneration
        ) {
            fail(
                "native_credential_lease_mismatch",
                "The installed credential changed before lease persistence",
            )
        }
        val currentExpiry = NativeSessionProtocol.credentialLeaseExpiry(
            current.getString("leaseExpiresAt"),
        )
        if (receipt.leaseExpiry.isBefore(currentExpiry)) {
            fail(
                "native_credential_lease_regressed",
                "The authenticated credential lease moved backwards",
            )
        }

        var appliedRaw = currentRaw
        if (receipt.leaseExpiry.isAfter(currentExpiry)) {
            appliedRaw = JSONObject(currentRaw)
                .put("leaseExpiresAt", receipt.leaseExpiresAt)
                .toString()
            if (preferences.getString(CREDENTIAL_RECORD_KEY, null) != currentRaw ||
                !preferences.edit().putString(CREDENTIAL_RECORD_KEY, appliedRaw).commit() ||
                preferences.getString(CREDENTIAL_RECORD_KEY, null) != appliedRaw
            ) {
                fail("native_vault_write_failed", "The credential lease could not be persisted")
            }
        }
        recovered.storedRaw = appliedRaw
        applyCredentialLeaseToRust(current, receipt.leaseExpiresAt)
    }

    private fun compareDeleteExact(storedRaw: String): Boolean {
        if (preferences.getString(CREDENTIAL_RECORD_KEY, null) != storedRaw) return false
        return preferences.edit().remove(CREDENTIAL_RECORD_KEY).commit()
    }

    @Synchronized
    private fun configuredHttp(): NativeSessionHttp {
        http?.let { return it }
        val persisted = preferences.getString(MOBILE_API_BASE_URL_KEY, null)
            ?: fail(
                "native_api_unavailable",
                "The native mobile API origin has not been configured",
            )
        return NativeSessionHttp(persisted).also { http = it }
    }

    private fun applyCredentialLeaseToRust(stored: JSONObject, leaseExpiresAt: String) {
        val commitment = NativeSessionProtocol.decodeCanonicalBase64Url(
            stored.getString("vaultCommitment"),
            COMMITMENT_BYTES,
            "stored vault commitment",
        )
        val frame = try {
            buildFrame("UNVL") {
                write(1)
                writeString(stored.getString("credentialReference"), 64)
                writeLong(stored.getLong("credentialGeneration"))
                writeFixed(commitment)
                writeLong(
                    NativeSessionProtocol.credentialLeaseExpiry(leaseExpiresAt).toEpochMilli(),
                )
            }
        } finally {
            commitment.fill(0)
        }
        try {
            if (!NativeSessionRust.nativeApplyCredentialLeaseV1(frame)) {
                fail(
                    "native_credential_lease_update_failed",
                    "Rust rejected the authenticated credential lease",
                )
            }
        } finally {
            frame.fill(0)
        }
    }

    private fun randomPolicyRequestId(): String {
        val bytes = ByteArray(32).also(secureRandom::nextBytes)
        return try {
            "ndp_${NativeSessionProtocol.encodeBase64Url(bytes)}"
        } finally {
            bytes.fill(0)
        }
    }

    private fun validateInstallationUuid(value: String) {
        val canonical = try {
            UUID.fromString(value).toString()
        } catch (_: Exception) {
            null
        }
        if (canonical != value.lowercase()) {
            fail("invalid_native_push_request", "The push installation id is invalid")
        }
    }

    private fun validatePushMutation(
        installationId: String,
        providerToken: String,
        platform: String,
        permissionStatus: String,
        mutationRevision: Long,
    ) {
        validateInstallationUuid(installationId)
        if (providerToken.isEmpty() || providerToken.length > 4096 ||
            platform !in setOf("android", "ios") ||
            permissionStatus !in PUSH_PERMISSION_STATUSES ||
            mutationRevision <= 0
        ) {
            fail("invalid_native_push_request", "The push registration request is invalid")
        }
    }

    private fun recoverCredential(storedRaw: String): RecoveredCredential {
        val stored = parseStoredRecord(storedRaw)
        NativeSessionProtocol.requireCredentialLeaseCurrent(
            stored.getString("leaseExpiresAt"),
        )
        val installation = loadInstallation()
        if (stored.getString("installationId") != installation.installationId ||
            stored.getInt("installationGeneration") != installation.keyGeneration ||
            stored.getString("possessionKeyThumbprint") != installation.possessionThumbprint ||
            stored.getString("envelopeKeyThumbprint") != installation.envelopeThumbprint ||
            stored.getString("envelopeKeyId") != installation.envelopeKeyId ||
            stored.getString("envelopeAlgorithm") != "RSA-OAEP" ||
            stored.getString("envelopeEncryption") != "A256GCM"
        ) {
            fail("native_credential_mismatch", "The stored native installation is mismatched")
        }
        val binding = NativeCredentialBinding(
            attemptId = stored.getString("attemptId"),
            ticketHash = stored.getString("ticketHash"),
            requestDigest = stored.getString("requestDigest"),
            exchangeRequestDigest = stored.getString("exchangeRequestDigest"),
            exchangeChallenge = stored.getString("exchangeChallenge"),
            networkId = stored.getString("networkId"),
            chainId = stored.getString("chainId"),
            credentialReference = stored.getString("credentialReference"),
            credentialGeneration = stored.getInt("credentialGeneration"),
        )
        // Decode fixed fields up front so malformed durable JSON never reaches
        // either Rust or an authenticated HTTP request.
        NativeSessionProtocol.decodeHex32(binding.ticketHash, "stored ticket hash").fill(0)
        NativeSessionProtocol.decodeHex32(binding.requestDigest, "stored request digest").fill(0)
        NativeSessionProtocol.decodeHex32(
            binding.exchangeRequestDigest,
            "stored exchange digest",
        ).fill(0)
        NativeSessionProtocol.decodeCanonicalBase64Url(
            binding.exchangeChallenge,
            32,
            "stored exchange challenge",
        ).fill(0)
        val exchange = NativeExchangeEnvelope(
            binding.credentialReference,
            binding.credentialGeneration,
            stored.getString("compactJwe"),
        )
        val plaintext = decryptCompactJwe(exchange.compactJwe, installation)
        val credential = try {
            NativeSessionProtocol.validateCredentialPlaintext(
                plaintext,
                binding,
                installation,
            )
        } finally {
            plaintext.fill(0)
        }
        val commitment = NativeSessionProtocol.decodeCanonicalBase64Url(
            stored.getString("vaultCommitment"),
            COMMITMENT_BYTES,
            "stored vault commitment",
        )
        try {
            val fingerprint = credentialFingerprint(binding, installation, credential)
            try {
                val encodedFingerprint = NativeSessionProtocol.encodeBase64Url(fingerprint)
                if (encodedFingerprint != stored.getString("fingerprint")) {
                    fail("native_credential_mismatch", "The stored credential fingerprint is mismatched")
                }
            } finally {
                fingerprint.fill(0)
            }
            val frame = buildInstallFrame(
                binding = binding,
                installation = installation,
                credential = credential,
                leaseExpiresAt = stored.getString("leaseExpiresAt"),
                commitment = commitment,
            )
            return RecoveredCredential(storedRaw, binding, frame, credential)
        } catch (error: Throwable) {
            credential.accountScalar.fill(0)
            throw error
        } finally {
            commitment.fill(0)
        }
    }

    private fun loadInstallation(): NativeInstallationMaterial {
        var keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        val storedInstallationId = preferences.getString(INSTALLATION_ID_KEY, null)
        val possessionExists = keyStore.containsAlias(POSSESSION_ALIAS)
        val envelopeExists = keyStore.containsAlias(ENVELOPE_ALIAS)
        if (storedInstallationId != null && (!possessionExists || !envelopeExists)) {
            fail(
                "native_installation_recovery_required",
                "The native installation keys no longer match durable storage",
            )
        }
        if (!possessionExists) generatePossessionKey()
        if (!envelopeExists) generateEnvelopeKey()
        if (!possessionExists || !envelopeExists) {
            keyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }
        }
        val installationId = storedInstallationId ?: loadOrCreateInstallationId()

        val possession = keyStore.getCertificate(POSSESSION_ALIAS)?.publicKey as? ECPublicKey
            ?: fail("native_key_unavailable", "The native possession key is unavailable")
        val envelope = keyStore.getCertificate(ENVELOPE_ALIAS)?.publicKey as? RSAPublicKey
            ?: fail("native_key_unavailable", "The native envelope key is unavailable")
        return NativeSessionProtocol.installationMaterial(
            installationId = installationId,
            keyGeneration = KEY_GENERATION,
            possessionKey = possession,
            envelopeKey = envelope,
        )
    }

    private fun loadOrCreateInstallationId(): String {
        preferences.getString(INSTALLATION_ID_KEY, null)?.let { return it }
        val random = ByteArray(32).also(secureRandom::nextBytes)
        val id = try {
            "nsi_${NativeSessionProtocol.encodeBase64Url(random)}"
        } finally {
            random.fill(0)
        }
        if (!preferences.edit().putString(INSTALLATION_ID_KEY, id).commit()) {
            fail("native_vault_write_failed", "The native installation could not be persisted")
        }
        return preferences.getString(INSTALLATION_ID_KEY, null)
            ?: fail("native_vault_write_failed", "The native installation could not be read back")
    }

    private fun generatePossessionKey() {
        KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, ANDROID_KEYSTORE).run {
            initialize(
                KeyGenParameterSpec.Builder(
                    POSSESSION_ALIAS,
                    KeyProperties.PURPOSE_SIGN,
                )
                    .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
                    .setDigests(KeyProperties.DIGEST_SHA256)
                    .setUserAuthenticationRequired(false)
                    .build(),
            )
            generateKeyPair()
        }
    }

    private fun generateEnvelopeKey() {
        KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_RSA, ANDROID_KEYSTORE).run {
            initialize(
                KeyGenParameterSpec.Builder(
                    ENVELOPE_ALIAS,
                    KeyProperties.PURPOSE_DECRYPT,
                )
                    .setKeySize(3072)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
                    .setDigests(KeyProperties.DIGEST_SHA1)
                    .setUserAuthenticationRequired(false)
                    .build(),
            )
            generateKeyPair()
        }
    }

    private fun loadPrivateKey(alias: String): PrivateKey =
        KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }.getKey(alias, null)
            as? PrivateKey
            ?: fail("native_key_unavailable", "A native installation key is unavailable")

    private fun decryptCompactJwe(
        compactJwe: String,
        installation: NativeInstallationMaterial,
    ): ByteArray {
        val parts = compactJwe.split('.')
        if (parts.size != 5 || parts.any(String::isEmpty)) {
            fail("invalid_native_credential_envelope", "The compact JWE is invalid")
        }
        val protectedBytes = NativeSessionProtocol.decodeCanonicalBase64Url(
            parts[0],
            null,
            "JWE protected header",
        )
        try {
            val protected = try {
                JSONObject(NativeSessionProtocol.decodeStrictUtf8(protectedBytes))
            } catch (_: Exception) {
                fail("invalid_native_credential_envelope", "The JWE protected header is invalid")
            }
            val keys = mutableSetOf<String>()
            protected.keys().forEachRemaining(keys::add)
            if (keys != setOf("alg", "enc", "kid", "typ") ||
                protected.opt("alg") != "RSA-OAEP" ||
                protected.opt("enc") != "A256GCM" ||
                protected.opt("kid") != installation.envelopeKeyId ||
                protected.opt("typ") != CREDENTIAL_JWE_TYPE
            ) {
                fail("native_credential_mismatch", "The JWE protected header is mismatched")
            }
        } finally {
            protectedBytes.fill(0)
        }

        val encryptedKey = NativeSessionProtocol.decodeCanonicalBase64Url(
            parts[1],
            RSA_CIPHERTEXT_BYTES,
            "JWE encrypted key",
        )
        val iv = NativeSessionProtocol.decodeCanonicalBase64Url(parts[2], 12, "JWE IV")
        val ciphertext = NativeSessionProtocol.decodeCanonicalBase64Url(
            parts[3],
            null,
            "JWE ciphertext",
        )
        val tag = NativeSessionProtocol.decodeCanonicalBase64Url(parts[4], 16, "JWE tag")
        if (ciphertext.isEmpty() || ciphertext.size > MAX_PLAINTEXT_BYTES) {
            encryptedKey.fill(0)
            iv.fill(0)
            ciphertext.fill(0)
            tag.fill(0)
            fail("invalid_native_credential_envelope", "The JWE ciphertext size is invalid")
        }

        val cek = try {
            Cipher.getInstance("RSA/ECB/OAEPWithSHA-1AndMGF1Padding").run {
                init(
                    Cipher.DECRYPT_MODE,
                    loadPrivateKey(ENVELOPE_ALIAS),
                    OAEPParameterSpec(
                        "SHA-1",
                        "MGF1",
                        MGF1ParameterSpec.SHA1,
                        PSource.PSpecified.DEFAULT,
                    ),
                )
                doFinal(encryptedKey)
            }
        } finally {
            encryptedKey.fill(0)
        }
        try {
            if (cek.size != 32) {
                fail("invalid_native_credential_envelope", "The JWE content key is invalid")
            }
            val encryptedContent = ciphertext + tag
            return try {
                Cipher.getInstance("AES/GCM/NoPadding").run {
                    init(Cipher.DECRYPT_MODE, javax.crypto.spec.SecretKeySpec(cek, "AES"), GCMParameterSpec(128, iv))
                    updateAAD(parts[0].toByteArray(StandardCharsets.US_ASCII))
                    doFinal(encryptedContent).also {
                        if (it.isEmpty() || it.size > MAX_PLAINTEXT_BYTES) {
                            it.fill(0)
                            fail("invalid_native_credential_envelope", "The credential plaintext size is invalid")
                        }
                    }
                }
            } finally {
                encryptedContent.fill(0)
            }
        } finally {
            cek.fill(0)
            iv.fill(0)
            ciphertext.fill(0)
            tag.fill(0)
        }
    }

    private fun credentialFingerprint(
        binding: NativeCredentialBinding,
        installation: NativeInstallationMaterial,
        credential: NativeCredentialPlaintext,
    ): ByteArray {
        val frame = buildFrame("UNVF") {
            writeString(binding.attemptId, 64)
            writeFixed(NativeSessionProtocol.decodeHex32(binding.ticketHash, "ticket hash"))
            writeFixed(NativeSessionProtocol.decodeHex32(binding.requestDigest, "ticket request digest"))
            writeFixed(NativeSessionProtocol.decodeHex32(
                binding.exchangeRequestDigest,
                "exchange request digest",
            ))
            writeString(binding.networkId, 32)
            writeString(binding.chainId, 96)
            writeString(installation.installationId, 64)
            writeLong(installation.keyGeneration.toLong())
            writeFixed(NativeSessionProtocol.decodeCanonicalBase64Url(
                installation.possessionThumbprint,
                32,
                "possession thumbprint",
            ))
            writeFixed(NativeSessionProtocol.decodeCanonicalBase64Url(
                installation.envelopeThumbprint,
                32,
                "envelope thumbprint",
            ))
            writeString(binding.credentialReference, 64)
            writeLong(binding.credentialGeneration.toLong())
            writeString(credential.participantId, 32)
            writeString(credential.accountId, 32)
            writeString(credential.address, 128)
            writeString(credential.publicKey, 128)
            write(if (credential.blockProductionReleased) 1 else 0)
        }
        return try {
            MessageDigest.getInstance("SHA-256").digest(frame)
        } finally {
            frame.fill(0)
        }
    }

    private fun persistCredential(
        binding: NativeCredentialBinding,
        installation: NativeInstallationMaterial,
        exchange: NativeExchangeEnvelope,
        fingerprint: ByteArray,
        credential: NativeCredentialPlaintext,
    ): PersistedCredentialInstall {
        val fingerprintText = NativeSessionProtocol.encodeBase64Url(fingerprint)
        val existingRaw = preferences.getString(CREDENTIAL_RECORD_KEY, null)
        if (existingRaw != null) {
            val existing = parseStoredRecord(existingRaw)
            if (existing.optString("fingerprint", "") != fingerprintText ||
                existing.optString("compactJwe", "") != exchange.compactJwe
            ) {
                fail("native_vault_occupied", "A different native credential is already installed")
            }
            val leaseExpiresAt = existing.getString("leaseExpiresAt")
            NativeSessionProtocol.requireCredentialLeaseCurrent(leaseExpiresAt)
            return PersistedCredentialInstall(
                commitment = NativeSessionProtocol.decodeCanonicalBase64Url(
                    existing.getString("vaultCommitment"),
                    COMMITMENT_BYTES,
                    "stored vault commitment",
                ),
                leaseExpiresAt = leaseExpiresAt,
            )
        }

        NativeSessionProtocol.requireCredentialLeaseCurrent(credential.bearerExpiresAt)
        val commitment = ByteArray(COMMITMENT_BYTES).also(secureRandom::nextBytes)
        val record = JSONObject()
            .put("version", 4)
            .put("attemptId", binding.attemptId)
            .put("ticketHash", binding.ticketHash)
            .put("requestDigest", binding.requestDigest)
            .put("exchangeRequestDigest", binding.exchangeRequestDigest)
            .put("exchangeChallenge", binding.exchangeChallenge)
            .put("networkId", binding.networkId)
            .put("chainId", binding.chainId)
            .put("installationId", installation.installationId)
            .put("installationGeneration", installation.keyGeneration)
            .put("possessionKeyThumbprint", installation.possessionThumbprint)
            .put("envelopeKeyThumbprint", installation.envelopeThumbprint)
            .put("credentialReference", exchange.credentialReference)
            .put("credentialGeneration", exchange.credentialGeneration)
            .put("envelopeAlgorithm", "RSA-OAEP")
            .put("envelopeEncryption", "A256GCM")
            .put("envelopeKeyId", installation.envelopeKeyId)
            .put("compactJwe", exchange.compactJwe)
            .put("leaseExpiresAt", credential.bearerExpiresAt)
            .put("fingerprint", fingerprintText)
            .put("vaultCommitment", NativeSessionProtocol.encodeBase64Url(commitment))
        val encoded = record.toString()
        if (!preferences.edit().putString(CREDENTIAL_RECORD_KEY, encoded).commit() ||
            preferences.getString(CREDENTIAL_RECORD_KEY, null) != encoded
        ) {
            commitment.fill(0)
            fail("native_vault_write_failed", "The native credential could not be persisted")
        }
        return PersistedCredentialInstall(commitment, credential.bearerExpiresAt)
    }

    private fun buildInstallFrame(
        binding: NativeCredentialBinding,
        installation: NativeInstallationMaterial,
        credential: NativeCredentialPlaintext,
        leaseExpiresAt: String,
        commitment: ByteArray,
    ): ByteArray = buildFrame("UNSI") {
        write(1)
        write(1)
        writeString(binding.attemptId, 64)
        writeFixed(NativeSessionProtocol.decodeHex32(binding.ticketHash, "ticket hash"))
        writeFixed(NativeSessionProtocol.decodeHex32(binding.requestDigest, "ticket request digest"))
        writeFixed(NativeSessionProtocol.decodeHex32(
            binding.exchangeRequestDigest,
            "exchange request digest",
        ))
        writeFixed(NativeSessionProtocol.decodeCanonicalBase64Url(
            binding.exchangeChallenge,
            32,
            "exchange challenge",
        ))
        writeString(binding.networkId, 32)
        writeString(binding.chainId, 96)
        writeString(installation.installationId, 64)
        writeLong(installation.keyGeneration.toLong())
        writeFixed(NativeSessionProtocol.decodeCanonicalBase64Url(
            installation.possessionThumbprint,
            32,
            "possession thumbprint",
        ))
        writeFixed(NativeSessionProtocol.decodeCanonicalBase64Url(
            installation.envelopeThumbprint,
            32,
            "envelope thumbprint",
        ))
        writeString(binding.credentialReference, 64)
        writeLong(binding.credentialGeneration.toLong())
        writeString(credential.participantId, 32)
        writeString(credential.accountId, 32)
        writeString(credential.address, 128)
        writeString(credential.publicKey, 128)
        writeLong(
            NativeSessionProtocol.requireCredentialLeaseCurrent(
                leaseExpiresAt,
            ).toEpochMilli(),
        )
        write(if (credential.blockProductionReleased) 1 else 0)
        writeFixed(commitment)
        writeFixed(credential.accountScalar)
    }.also {
        if (it.size > MAX_INSTALL_FRAME_BYTES) {
            it.fill(0)
            fail("native_install_frame_too_large", "The native install frame is too large")
        }
    }

    private fun vaultEvidenceFrame(
        storedRaw: String,
        coldInstallClaim: ByteArray?,
    ): ByteArray {
        val stored = parseStoredRecord(storedRaw)
        val installation = loadInstallation()
        if (stored.getString("installationId") != installation.installationId ||
            stored.getInt("installationGeneration") != installation.keyGeneration ||
            stored.getString("possessionKeyThumbprint") != installation.possessionThumbprint ||
            stored.getString("envelopeKeyThumbprint") != installation.envelopeThumbprint ||
            stored.getString("envelopeKeyId") != installation.envelopeKeyId
        ) {
            fail("native_credential_mismatch", "The stored native installation is mismatched")
        }
        val reference = stored.getString("credentialReference")
        val generation = stored.getLong("credentialGeneration")
        val leaseExpiryMs = NativeSessionProtocol.requireCredentialLeaseCurrent(
            stored.getString("leaseExpiresAt"),
        ).toEpochMilli()
        if (reference.isEmpty() || reference.toByteArray(StandardCharsets.UTF_8).size > 64 ||
            generation <= 0
        ) {
            fail("native_vault_corrupt", "The native credential record is invalid")
        }
        val commitment = NativeSessionProtocol.decodeCanonicalBase64Url(
            stored.getString("vaultCommitment"),
            COMMITMENT_BYTES,
            "stored vault commitment",
        )
        val fingerprint = NativeSessionProtocol.decodeCanonicalBase64Url(
            stored.getString("fingerprint"),
            32,
            "stored request fingerprint",
        )
        return try {
            buildFrame("UNVE") {
                write(1)
                writeString(reference, 64)
                writeLong(generation)
                writeLong(leaseExpiryMs)
                writeFixed(commitment)
                writeFixed(fingerprint)
                if (coldInstallClaim == null) {
                    write(0)
                } else {
                    write(CLAIM_BYTES)
                    writeFixed(coldInstallClaim)
                }
            }
        } finally {
            commitment.fill(0)
            fingerprint.fill(0)
        }
    }

    private fun buildFrame(magic: String, body: DataOutputStream.() -> Unit): ByteArray {
        val bytes = ByteArrayOutputStream()
        DataOutputStream(bytes).use { output ->
            output.write(magic.toByteArray(StandardCharsets.US_ASCII))
            output.body()
        }
        return bytes.toByteArray()
    }

    private fun DataOutputStream.writeString(value: String, maximumBytes: Int) {
        val bytes = value.toByteArray(StandardCharsets.UTF_8)
        if (bytes.isEmpty() || bytes.size > maximumBytes || bytes.size > 0xffff) {
            bytes.fill(0)
            fail("native_install_frame_invalid", "A native install field is invalid")
        }
        writeShort(bytes.size)
        write(bytes)
        bytes.fill(0)
    }

    private fun DataOutputStream.writeFixed(value: ByteArray) {
        write(value)
    }

    private fun parseStoredRecord(raw: String): JSONObject = try {
        JSONObject(raw).also { record ->
            if (record.optInt("version", -1) != 4) {
                fail(
                    "native_credential_relogin_required",
                    "The native credential record requires login",
                )
            }
            val keys = mutableSetOf<String>()
            record.keys().forEachRemaining(keys::add)
            if (keys != STORED_RECORD_KEYS) {
                fail("native_vault_corrupt", "The native credential record is invalid")
            }
        }
    } catch (error: NativeSessionProtocolException) {
        throw error
    } catch (_: Exception) {
        fail("native_vault_corrupt", "The native credential record is invalid")
    }

    private fun fail(code: String, message: String): Nothing =
        throw NativeSessionProtocolException(code, message)

    private fun shouldDiscardCredential(error: NativeSessionProtocolException): Boolean =
        error.code == "native_credential_expired" ||
            error.code == "native_credential_relogin_required"

    private companion object {
        const val HANDOFF_COOKIE_NAME = "usernode_native_session_handoff"
        const val PREFERENCES_NAME = "native_session_v2"
        const val INSTALLATION_ID_KEY = "installation_id"
        const val CREDENTIAL_RECORD_KEY = "credential_record"
        const val MOBILE_API_BASE_URL_KEY = "mobile_api_base_url"
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val POSSESSION_ALIAS = "usernode_native_session_v2_possession_1"
        const val ENVELOPE_ALIAS = "usernode_native_session_v2_envelope_1"
        const val KEY_GENERATION = 1
        const val RSA_CIPHERTEXT_BYTES = 384
        const val COMMITMENT_BYTES = 32
        const val CLAIM_BYTES = 32
        const val MAX_PLAINTEXT_BYTES = 32 * 1024
        const val MAX_INSTALL_FRAME_BYTES = 1024
        const val CREDENTIAL_JWE_TYPE = "application/usernode-native-session-credential+jwe"
        const val ZK_IDENTITY_KIND = "ZK_IDENTITY_VERIFICATION"
        val ZK_NULLIFIER = Regex("^0x[0-9a-fA-F]+$")
        val PUSH_PERMISSION_STATUSES = setOf(
            "authorized", "provisional", "denied", "not_determined",
        )
        val PUSH_UNREGISTER_REASONS = setOf(
            "client_request", "notifications_disabled", "permission_denied", "signed_out",
            "account_changed", "identity_boundary", "terminal_reset",
            "configuration_unavailable",
        )
        val STORED_RECORD_KEYS = setOf(
            "version",
            "attemptId",
            "ticketHash",
            "requestDigest",
            "exchangeRequestDigest",
            "exchangeChallenge",
            "networkId",
            "chainId",
            "installationId",
            "installationGeneration",
            "possessionKeyThumbprint",
            "envelopeKeyThumbprint",
            "credentialReference",
            "credentialGeneration",
            "envelopeAlgorithm",
            "envelopeEncryption",
            "envelopeKeyId",
            "compactJwe",
            "leaseExpiresAt",
            "fingerprint",
            "vaultCommitment",
        )
    }
}

internal sealed interface ColdCredentialStage {
    data class Present(val installClaim: ByteArray) : ColdCredentialStage
    object Absent : ColdCredentialStage
    object Uncertain : ColdCredentialStage
}

internal enum class NativeCredentialServerRevocation {
    DEFINITIVELY_ABSENT,
    UNCERTAIN,
}

private data class PersistedCredentialInstall(
    val commitment: ByteArray,
    val leaseExpiresAt: String,
)

internal sealed interface ProducerWakeCredential {
    data class Present(
        val vaultEvidenceFrame: ByteArray,
        val producerPolicyFrame: ByteArray,
    ) : ProducerWakeCredential {
        fun close() {
            vaultEvidenceFrame.fill(0)
            producerPolicyFrame.fill(0)
        }
    }
    object Absent : ProducerWakeCredential
    object Uncertain : ProducerWakeCredential
}

private sealed interface AuthenticatedProducerMaterial {
    class Present(
        val recovered: RecoveredCredential,
        val policyFrame: ByteArray,
    ) : AuthenticatedProducerMaterial {
        fun close() {
            policyFrame.fill(0)
            recovered.close()
        }
    }

    object Absent : AuthenticatedProducerMaterial
    object Uncertain : AuthenticatedProducerMaterial
}

private class RecoveredCredential(
    var storedRaw: String,
    val binding: NativeCredentialBinding,
    val installFrame: ByteArray,
    val credential: NativeCredentialPlaintext,
) {
    fun close() {
        installFrame.fill(0)
        credential.accountScalar.fill(0)
    }
}

/** One vault instance serializes every decrypt/use/delete transaction in-process. */
internal object AndroidNativeSessionPlatform {
    @Volatile
    private var vault: AndroidNativeSessionVault? = null

    fun vault(context: Context): AndroidNativeSessionVault {
        val current = vault
        if (current != null) return current
        return synchronized(this) {
            vault ?: AndroidNativeSessionVault(context.applicationContext).also { vault = it }
        }
    }
}
