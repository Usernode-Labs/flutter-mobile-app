package com.usernode_labs.usernode.session

import android.content.Context
import android.content.SharedPreferences
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
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
        val plaintextBytes = decryptCompactJwe(exchange.compactJwe, installation)
        val credential = try {
            NativeSessionProtocol.validateCredentialPlaintext(
                plaintextBytes,
                ticket,
                installation,
                exchange,
            )
        } finally {
            plaintextBytes.fill(0)
        }

        return try {
            val fingerprint = credentialFingerprint(ticket, installation, exchange, credential)
            try {
                val commitment = persistCredential(
                    ticket = ticket,
                    installation = installation,
                    exchange = exchange,
                    fingerprint = fingerprint,
                )
                try {
                    val frame = buildInstallFrame(
                        ticket = ticket,
                        installation = installation,
                        exchange = exchange,
                        credential = credential,
                        commitment = commitment,
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
                    commitment.fill(0)
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
        val stored = parseStoredRecord(storedRaw)
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
            if (!preferences.edit().remove(CREDENTIAL_RECORD_KEY).commit()) {
                fail("native_vault_write_failed", "The native credential could not be retired")
            }
        } finally {
            storedCommitment.fill(0)
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
        ticket: NativeEstablishTicket,
        installation: NativeInstallationMaterial,
        exchange: NativeExchangeEnvelope,
        credential: NativeCredentialPlaintext,
    ): ByteArray {
        val frame = buildFrame("UNVF") {
            writeString(ticket.attemptId, 64)
            writeFixed(MessageDigest.getInstance("SHA-256").digest(
                ticket.ticket.toByteArray(StandardCharsets.UTF_8),
            ))
            writeFixed(NativeSessionProtocol.decodeHex32(ticket.requestDigest, "ticket request digest"))
            writeFixed(NativeSessionProtocol.decodeHex32(
                NativeSessionProtocol.exchangeRequestDigest(ticket, installation),
                "exchange request digest",
            ))
            writeString(ticket.networkId, 32)
            writeString(ticket.chainId, 96)
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
            writeString(exchange.credentialReference, 64)
            writeLong(exchange.credentialGeneration.toLong())
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
        ticket: NativeEstablishTicket,
        installation: NativeInstallationMaterial,
        exchange: NativeExchangeEnvelope,
        fingerprint: ByteArray,
    ): ByteArray {
        val fingerprintText = NativeSessionProtocol.encodeBase64Url(fingerprint)
        val existingRaw = preferences.getString(CREDENTIAL_RECORD_KEY, null)
        if (existingRaw != null) {
            val existing = parseStoredRecord(existingRaw)
            if (existing.optString("fingerprint", "") != fingerprintText ||
                existing.optString("compactJwe", "") != exchange.compactJwe
            ) {
                fail("native_vault_occupied", "A different native credential is already installed")
            }
            return NativeSessionProtocol.decodeCanonicalBase64Url(
                existing.getString("vaultCommitment"),
                COMMITMENT_BYTES,
                "stored vault commitment",
            )
        }

        val commitment = ByteArray(COMMITMENT_BYTES).also(secureRandom::nextBytes)
        val record = JSONObject()
            .put("version", 2)
            .put("attemptId", ticket.attemptId)
            .put(
                "ticketHash",
                NativeSessionProtocol.sha256Hex(ticket.ticket.toByteArray(StandardCharsets.UTF_8)),
            )
            .put("requestDigest", ticket.requestDigest)
            .put("exchangeRequestDigest", NativeSessionProtocol.exchangeRequestDigest(ticket, installation))
            .put("networkId", ticket.networkId)
            .put("chainId", ticket.chainId)
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
            .put("fingerprint", fingerprintText)
            .put("vaultCommitment", NativeSessionProtocol.encodeBase64Url(commitment))
        val encoded = record.toString()
        if (!preferences.edit().putString(CREDENTIAL_RECORD_KEY, encoded).commit() ||
            preferences.getString(CREDENTIAL_RECORD_KEY, null) != encoded
        ) {
            commitment.fill(0)
            fail("native_vault_write_failed", "The native credential could not be persisted")
        }
        return commitment
    }

    private fun buildInstallFrame(
        ticket: NativeEstablishTicket,
        installation: NativeInstallationMaterial,
        exchange: NativeExchangeEnvelope,
        credential: NativeCredentialPlaintext,
        commitment: ByteArray,
    ): ByteArray = buildFrame("UNSI") {
        write(1)
        write(1)
        writeString(ticket.attemptId, 64)
        writeFixed(MessageDigest.getInstance("SHA-256").digest(
            ticket.ticket.toByteArray(StandardCharsets.UTF_8),
        ))
        writeFixed(NativeSessionProtocol.decodeHex32(ticket.requestDigest, "ticket request digest"))
        writeFixed(NativeSessionProtocol.decodeHex32(
            NativeSessionProtocol.exchangeRequestDigest(ticket, installation),
            "exchange request digest",
        ))
        writeFixed(NativeSessionProtocol.decodeCanonicalBase64Url(
            ticket.exchangeChallenge,
            32,
            "exchange challenge",
        ))
        writeString(ticket.networkId, 32)
        writeString(ticket.chainId, 96)
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
        writeString(exchange.credentialReference, 64)
        writeLong(exchange.credentialGeneration.toLong())
        writeString(credential.participantId, 32)
        writeString(credential.accountId, 32)
        writeString(credential.address, 128)
        writeString(credential.publicKey, 128)
        write(if (credential.blockProductionReleased) 1 else 0)
        writeFixed(commitment)
        writeFixed(credential.accountScalar)
    }.also {
        if (it.size > MAX_INSTALL_FRAME_BYTES) {
            it.fill(0)
            fail("native_install_frame_too_large", "The native install frame is too large")
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
            val keys = mutableSetOf<String>()
            record.keys().forEachRemaining(keys::add)
            if (keys != STORED_RECORD_KEYS || record.optInt("version", -1) != 2) {
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

    private companion object {
        const val PREFERENCES_NAME = "native_session_v2"
        const val INSTALLATION_ID_KEY = "installation_id"
        const val CREDENTIAL_RECORD_KEY = "credential_record"
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
        val STORED_RECORD_KEYS = setOf(
            "version",
            "attemptId",
            "ticketHash",
            "requestDigest",
            "exchangeRequestDigest",
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
            "fingerprint",
            "vaultCommitment",
        )
    }
}
