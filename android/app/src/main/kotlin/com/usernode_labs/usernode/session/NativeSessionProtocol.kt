package com.usernode_labs.usernode.session

import android.util.Base64
import java.io.ByteArrayOutputStream
import java.math.BigInteger
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.security.interfaces.ECPublicKey
import java.security.interfaces.RSAPublicKey
import java.security.spec.ECFieldFp
import java.time.Instant
import org.json.JSONObject

internal class NativeSessionProtocolException(
    internal val code: String,
    message: String,
) : Exception(message)

internal class NativeEstablishTicket(
    val protocol: Int,
    val attemptId: String,
    val desiredRuntime: String,
    val ticket: String,
    val requestDigest: String,
    val exchangeChallenge: String,
    val networkId: String,
    val chainId: String,
) {
    override fun toString(): String = "NativeEstablishTicket(<redacted>)"
}

internal data class NativeInstallationMaterial(
    val installationId: String,
    val keyGeneration: Int,
    val possessionX: String,
    val possessionY: String,
    val envelopeModulus: String,
) {
    val possessionJwk: Map<String, Any>
        get() = linkedMapOf(
            "kty" to "EC",
            "crv" to "P-256",
            "x" to possessionX,
            "y" to possessionY,
        )

    val envelopeJwk: Map<String, Any>
        get() = linkedMapOf(
            "kty" to "RSA",
            "n" to envelopeModulus,
            "e" to "AQAB",
        )

    val possessionCanonicalJwk: String
        get() = "{\"crv\":\"P-256\",\"kty\":\"EC\",\"x\":\"$possessionX\",\"y\":\"$possessionY\"}"

    val envelopeCanonicalJwk: String
        get() = "{\"e\":\"AQAB\",\"kty\":\"RSA\",\"n\":\"$envelopeModulus\"}"

    val possessionThumbprint: String
        get() = NativeSessionProtocol.sha256Base64Url(possessionCanonicalJwk.toByteArray(StandardCharsets.UTF_8))

    val envelopeThumbprint: String
        get() = NativeSessionProtocol.sha256Base64Url(envelopeCanonicalJwk.toByteArray(StandardCharsets.UTF_8))

    val possessionKeyId: String get() = "nskp_$possessionThumbprint"
    val envelopeKeyId: String get() = "nske_$envelopeThumbprint"
}

internal class NativeExchangeEnvelope(
    val credentialReference: String,
    val credentialGeneration: Int,
    val compactJwe: String,
) {
    override fun toString(): String = "NativeExchangeEnvelope(<redacted>)"
}

internal class NativeCredentialPlaintext(
    val participantId: String,
    val bearerToken: String,
    val bearerExpiresAt: String,
    val account: NativeCredentialAccount?,
) {
    override fun toString(): String = "NativeCredentialPlaintext(<redacted>)"
}

internal class NativeCredentialAccount(
    val accountId: String,
    val address: String,
    val publicKey: String,
    val accountScalar: ByteArray,
    val blockProductionReleased: Boolean,
) {
    override fun toString(): String = "NativeCredentialAccount(<redacted>)"
}

internal data class NativeCredentialLeaseReceipt(
    val credentialReference: String,
    val credentialGeneration: Int,
    val leaseExpiresAt: String,
    val leaseExpiry: Instant,
)

internal data class NativeCredentialBinding(
    val attemptId: String,
    val ticketHash: String,
    val requestDigest: String,
    val exchangeRequestDigest: String,
    val exchangeChallenge: String,
    val networkId: String,
    val chainId: String,
    val credentialReference: String,
    val credentialGeneration: Int,
)

internal object NativeSessionProtocol {
    private val hex64Pattern = Regex("^[0-9a-f]{64}$")
    private val bearerPattern = Regex("^[0-9a-f]{80}$")
    private val positiveDecimalPattern = Regex("^[1-9][0-9]*$")
    private val p256Prime = BigInteger(
        "ffffffff00000001000000000000000000000000ffffffffffffffffffffffff",
        16,
    )
    private val p256A = BigInteger(
        "ffffffff00000001000000000000000000000000fffffffffffffffffffffffc",
        16,
    )
    private val p256B = BigInteger(
        "5ac635d8aa3a93e7b3ebbd55769886bc651d06b0cc53b0f63bce3c3e27d2604b",
        16,
    )
    private val p256GeneratorX = BigInteger(
        "6b17d1f2e12c4247f8bce6e563a440f277037d812deb33a0f4a13945d898c296",
        16,
    )
    private val p256GeneratorY = BigInteger(
        "4fe342e2fe1a7f9b8ee7eb4a7c0f9e162bce33576b315ececbb6406837bf51f5",
        16,
    )
    private val p256Order = BigInteger(
        "ffffffff00000000ffffffffffffffffbce6faada7179e84f3b9cac2fc632551",
        16,
    )
    private val ticketKeys = setOf(
        "protocol", "attemptId", "desiredRuntime", "ticket", "requestDigest",
        "exchangeChallenge", "network", "issuedAt", "expiresAt",
    )
    private val exchangeKeys = setOf(
        "protocol", "attemptId", "requestDigest", "credentialReference",
        "credentialGeneration", "envelope",
    )

    fun parseTicket(raw: Any?): NativeEstablishTicket {
        val map = exactMap(raw, ticketKeys, "nativeEstablishTicket")
        val protocol = exactInt(map["protocol"], "nativeEstablishTicket.protocol")
        val attemptId = canonicalString(map["attemptId"], "nativeEstablishTicket.attemptId")
        val desiredRuntime = canonicalString(
            map["desiredRuntime"],
            "nativeEstablishTicket.desiredRuntime",
        )
        val ticket = canonicalString(map["ticket"], "nativeEstablishTicket.ticket")
        val requestDigest = canonicalString(
            map["requestDigest"],
            "nativeEstablishTicket.requestDigest",
        )
        val exchangeChallenge = canonicalString(
            map["exchangeChallenge"],
            "nativeEstablishTicket.exchangeChallenge",
        )
        val network = exactMap(
            map["network"],
            setOf("id", "chainId"),
            "nativeEstablishTicket.network",
        )
        val networkId = canonicalString(network["id"], "nativeEstablishTicket.network.id")
        val chainId = canonicalString(
            network["chainId"],
            "nativeEstablishTicket.network.chainId",
        )
        val issuedAt = canonicalString(map["issuedAt"], "nativeEstablishTicket.issuedAt")
        val expiresAt = canonicalString(map["expiresAt"], "nativeEstablishTicket.expiresAt")

        validateOpaque(attemptId, "nsa_", "nativeEstablishTicket.attemptId")
        validateOpaque(ticket, "nst_", "nativeEstablishTicket.ticket")
        if (protocol != 2 || desiredRuntime != "running" || networkId != "testnet" ||
            !hex64Pattern.matches(requestDigest) ||
            chainId.toByteArray(StandardCharsets.UTF_8).size !in 1..96
        ) {
            fail("invalid_native_establish_ticket", "The native establishment ticket is invalid")
        }
        decodeCanonicalBase64Url(
            exchangeChallenge,
            32,
            "nativeEstablishTicket.exchangeChallenge",
        ).fill(0)
        try {
            val issued = Instant.parse(issuedAt)
            val expires = Instant.parse(expiresAt)
            if (!expires.isAfter(issued)) {
                fail("invalid_native_establish_ticket", "The ticket timestamps are invalid")
            }
        } catch (_: Exception) {
            fail("invalid_native_establish_ticket", "The ticket timestamps are invalid")
        }
        return NativeEstablishTicket(
            protocol = protocol,
            attemptId = attemptId,
            desiredRuntime = desiredRuntime,
            ticket = ticket,
            requestDigest = requestDigest,
            exchangeChallenge = exchangeChallenge,
            networkId = networkId,
            chainId = chainId,
        )
    }

    fun parseTicketResponse(raw: JSONObject, expectedAttemptId: String): Map<String, Any> {
        if (jsonKeys(raw) != setOf("success", "data") || raw.opt("success") != true) {
            fail("invalid_native_establish_ticket", "The native ticket response is invalid")
        }
        val data = raw.optJSONObject("data")
            ?: fail("invalid_native_establish_ticket", "The native ticket response is invalid")
        if (jsonKeys(data) != ticketKeys) {
            fail("invalid_native_establish_ticket", "The native ticket response is invalid")
        }
        val network = data.optJSONObject("network")
            ?: fail("invalid_native_establish_ticket", "The native ticket response is invalid")
        if (jsonKeys(network) != setOf("id", "chainId")) {
            fail("invalid_native_establish_ticket", "The native ticket response is invalid")
        }
        val ticketMap = linkedMapOf<String, Any>(
            "protocol" to data.get("protocol"),
            "attemptId" to data.get("attemptId"),
            "desiredRuntime" to data.get("desiredRuntime"),
            "ticket" to data.get("ticket"),
            "requestDigest" to data.get("requestDigest"),
            "exchangeChallenge" to data.get("exchangeChallenge"),
            "network" to linkedMapOf(
                "id" to network.get("id"),
                "chainId" to network.get("chainId"),
            ),
            "issuedAt" to data.get("issuedAt"),
            "expiresAt" to data.get("expiresAt"),
        )
        val parsed = parseTicket(ticketMap)
        if (parsed.attemptId != expectedAttemptId) {
            fail("native_establish_request_mismatch", "The native ticket does not match its handoff")
        }
        return ticketMap
    }

    fun validateHandoffAttemptId(value: String) {
        validateOpaque(value, "nsa_", "native handoff attempt id")
    }

    fun validateHandoffToken(value: String) {
        validateOpaque(value, "nsh_", "native handoff token")
    }

    fun installationMaterial(
        installationId: String,
        keyGeneration: Int,
        possessionKey: ECPublicKey,
        envelopeKey: RSAPublicKey,
    ): NativeInstallationMaterial {
        validateOpaque(installationId, "nsi_", "native installation id")
        if (keyGeneration != 1) {
            fail("invalid_native_installation", "The native installation identity is invalid")
        }
        val params = possessionKey.params
        if ((params.curve.field as? ECFieldFp)?.p != p256Prime ||
            params.curve.a != p256A || params.curve.b != p256B ||
            params.generator.affineX != p256GeneratorX ||
            params.generator.affineY != p256GeneratorY ||
            params.order != p256Order || params.cofactor != 1 ||
            possessionKey.w.affineX.signum() < 0 ||
            possessionKey.w.affineX >= p256Prime ||
            possessionKey.w.affineY.signum() < 0 ||
            possessionKey.w.affineY >= p256Prime
        ) {
            fail("invalid_native_installation", "The possession key is not P-256")
        }
        if (envelopeKey.modulus.signum() <= 0 || envelopeKey.modulus.bitLength() != 3072) {
            fail("invalid_native_installation", "The envelope key is not RSA-3072")
        }
        val x = encodeBase64Url(fixedUnsigned(possessionKey.w.affineX.toByteArray(), 32))
        val y = encodeBase64Url(fixedUnsigned(possessionKey.w.affineY.toByteArray(), 32))
        val modulus = encodeBase64Url(fixedUnsigned(envelopeKey.modulus.toByteArray(), 384))
        if (envelopeKey.publicExponent != BigInteger.valueOf(65537L)) {
            fail("invalid_native_installation", "The envelope public exponent is invalid")
        }
        return NativeInstallationMaterial(
            installationId = installationId,
            keyGeneration = keyGeneration,
            possessionX = x,
            possessionY = y,
            envelopeModulus = modulus,
        )
    }

    fun possessionTranscript(
        ticket: NativeEstablishTicket,
        installation: NativeInstallationMaterial,
    ): ByteArray = frame(
        "usernode.native-session.exchange-pop.v2",
        listOf(
            "protocol" to ticket.protocol.toString(),
            "attemptId" to ticket.attemptId,
            "desiredRuntime" to ticket.desiredRuntime,
            "ticketHash" to sha256Hex(ticket.ticket.toByteArray(StandardCharsets.UTF_8)),
            "ticketRequestDigest" to ticket.requestDigest,
            "exchangeChallenge" to ticket.exchangeChallenge,
            "installationId" to installation.installationId,
            "keyGeneration" to installation.keyGeneration.toString(),
            "possessionKeyThumbprint" to installation.possessionThumbprint,
            "envelopeKeyThumbprint" to installation.envelopeThumbprint,
            "networkId" to ticket.networkId,
            "chainId" to ticket.chainId,
        ),
    )

    fun exchangeRequest(
        ticket: NativeEstablishTicket,
        installation: NativeInstallationMaterial,
        p1363Signature: ByteArray,
    ): Map<String, Any> {
        if (p1363Signature.size != 64) {
            fail("invalid_native_possession_proof", "The possession signature is invalid")
        }
        return linkedMapOf(
            "protocol" to 2,
            "attemptId" to ticket.attemptId,
            "desiredRuntime" to "running",
            "ticket" to ticket.ticket,
            "requestDigest" to ticket.requestDigest,
            "installation" to linkedMapOf(
                "id" to installation.installationId,
                "keyGeneration" to 1,
                "possessionPublicJwk" to installation.possessionJwk,
                "envelopePublicJwk" to installation.envelopeJwk,
            ),
            "proof" to linkedMapOf(
                "algorithm" to "ES256",
                "signature" to encodeBase64Url(p1363Signature),
            ),
        )
    }

    fun parseExchangeEnvelope(
        raw: Any?,
        ticket: NativeEstablishTicket,
        installation: NativeInstallationMaterial,
    ): NativeExchangeEnvelope {
        val map = exactMap(raw, exchangeKeys, "nativeEstablishExchange")
        val protocol = exactInt(map["protocol"], "nativeEstablishExchange.protocol")
        val attemptId = canonicalString(map["attemptId"], "nativeEstablishExchange.attemptId")
        val requestDigest = canonicalString(
            map["requestDigest"],
            "nativeEstablishExchange.requestDigest",
        )
        val reference = canonicalString(
            map["credentialReference"],
            "nativeEstablishExchange.credentialReference",
        )
        val generation = exactInt(
            map["credentialGeneration"],
            "nativeEstablishExchange.credentialGeneration",
        )
        val envelope = exactMap(
            map["envelope"],
            setOf("format", "algorithm", "encryption", "keyId", "compactJwe"),
            "nativeEstablishExchange.envelope",
        )
        if (protocol != 2 || attemptId != ticket.attemptId ||
            requestDigest != ticket.requestDigest ||
            generation != 1 || envelope["format"] != "compact-jwe" ||
            envelope["algorithm"] != "RSA-OAEP" || envelope["encryption"] != "A256GCM" ||
            envelope["keyId"] != installation.envelopeKeyId
        ) {
            fail("native_exchange_mismatch", "The native exchange response is mismatched")
        }
        validateOpaque(reference, "nsc_", "native credential reference")
        val compactJwe = canonicalString(
            envelope["compactJwe"],
            "nativeEstablishExchange.envelope.compactJwe",
        )
        if (compactJwe.length > 65_536) {
            fail("invalid_native_credential_envelope", "The credential envelope is too large")
        }
        return NativeExchangeEnvelope(reference, generation, compactJwe)
    }

    fun credentialBinding(
        ticket: NativeEstablishTicket,
        installation: NativeInstallationMaterial,
        exchange: NativeExchangeEnvelope,
    ) = NativeCredentialBinding(
        attemptId = ticket.attemptId,
        ticketHash = sha256Hex(ticket.ticket.toByteArray(StandardCharsets.UTF_8)),
        requestDigest = ticket.requestDigest,
        exchangeRequestDigest = exchangeRequestDigest(ticket, installation),
        exchangeChallenge = ticket.exchangeChallenge,
        networkId = ticket.networkId,
        chainId = ticket.chainId,
        credentialReference = exchange.credentialReference,
        credentialGeneration = exchange.credentialGeneration,
    )

    fun validateCredentialPlaintext(
        plaintext: ByteArray,
        binding: NativeCredentialBinding,
        installation: NativeInstallationMaterial,
    ): NativeCredentialPlaintext {
        val canonicalJson = decodeStrictUtf8(plaintext)
        val root = parseJsonObject(canonicalJson, "native credential")
        exactJsonKeys(
            root,
            setOf(
                "protocol", "attemptId", "ticketRequestDigest", "exchangeRequestDigest",
                "ticketHash", "subject", "network", "installation", "credential", "account",
            ),
            "native credential",
        )
        if (jsonInt(root, "protocol") != 2 ||
            jsonString(root, "attemptId") != binding.attemptId ||
            jsonString(root, "ticketRequestDigest") != binding.requestDigest ||
            jsonString(root, "exchangeRequestDigest") != binding.exchangeRequestDigest ||
            jsonString(root, "ticketHash") != binding.ticketHash
        ) {
            fail("native_credential_mismatch", "The native credential request binding is invalid")
        }

        val subject = jsonObject(root, "subject")
        exactJsonKeys(subject, setOf("userId"), "native credential subject")
        val participantId = jsonString(subject, "userId")
        if (!positiveDecimalPattern.matches(participantId) ||
            participantId.toByteArray(StandardCharsets.UTF_8).size > 32
        ) {
            fail("invalid_native_credential", "The credential subject is invalid")
        }

        val network = jsonObject(root, "network")
        exactJsonKeys(network, setOf("id", "chainId"), "native credential network")
        if (jsonString(network, "id") != binding.networkId ||
            jsonString(network, "chainId") != binding.chainId
        ) {
            fail("native_credential_mismatch", "The native credential network is invalid")
        }

        val installed = jsonObject(root, "installation")
        exactJsonKeys(
            installed,
            setOf(
                "id", "keyGeneration", "possessionKeyId", "possessionKeyThumbprint",
                "envelopeKeyId", "envelopeKeyThumbprint",
            ),
            "native credential installation",
        )
        if (jsonString(installed, "id") != installation.installationId ||
            jsonInt(installed, "keyGeneration") != installation.keyGeneration ||
            jsonString(installed, "possessionKeyId") != installation.possessionKeyId ||
            jsonString(installed, "possessionKeyThumbprint") != installation.possessionThumbprint ||
            jsonString(installed, "envelopeKeyId") != installation.envelopeKeyId ||
            jsonString(installed, "envelopeKeyThumbprint") != installation.envelopeThumbprint
        ) {
            fail("native_credential_mismatch", "The native credential installation is invalid")
        }

        val credential = jsonObject(root, "credential")
        exactJsonKeys(
            credential,
            setOf("reference", "generation", "bearerToken", "bearerExpiresAt"),
            "native credential authority",
        )
        val reference = jsonString(credential, "reference")
        val generation = jsonInt(credential, "generation")
        val bearer = jsonString(credential, "bearerToken")
        val bearerExpiresAt = jsonString(credential, "bearerExpiresAt")
        if (reference != binding.credentialReference ||
            generation != binding.credentialGeneration ||
            !bearerPattern.matches(bearer)
        ) {
            fail("native_credential_mismatch", "The native credential authority is invalid")
        }
        parseCredentialExpiry(bearerExpiresAt)

        val account = if (root.isNull("account")) {
            null
        } else {
            val accountJson = jsonObject(root, "account")
            exactJsonKeys(
                accountJson,
                setOf(
                    "accountId", "address", "publicKey", "secretKey", "seasonId",
                    "seasonEventId", "newlyAllocated", "blockProductionReleased",
                ),
                "native credential account",
            )
            val accountId = jsonString(accountJson, "accountId")
            val address = boundedCanonicalJsonString(accountJson, "address", 128)
            val publicKey = boundedCanonicalJsonString(accountJson, "publicKey", 128)
            val secretKey = boundedCanonicalJsonString(accountJson, "secretKey", 128)
            if (!positiveDecimalPattern.matches(accountId) ||
                accountId.toByteArray(StandardCharsets.UTF_8).size > 32
            ) {
                fail("invalid_native_credential", "The native credential account is invalid")
            }
            // Season allocation metadata is authenticated by the JWE but is
            // not installed into this native-session slice. Rust independently
            // checks every account field that does cross the JNI frame.
            NativeCredentialAccount(
                accountId = accountId,
                address = address,
                publicKey = publicKey,
                accountScalar = decodeAccountScalar(secretKey),
                blockProductionReleased = jsonBoolean(
                    accountJson,
                    "blockProductionReleased",
                ),
            )
        }

        return NativeCredentialPlaintext(
            participantId = participantId,
            bearerToken = bearer,
            bearerExpiresAt = bearerExpiresAt,
            account = account,
        )
    }

    fun requireCredentialLeaseCurrent(value: String): Instant {
        val expiry = parseCredentialExpiry(value)
        if (!expiry.isAfter(Instant.now())) {
            fail("native_credential_expired", "The native credential is expired")
        }
        return expiry
    }

    fun credentialLeaseExpiry(value: String): Instant = parseCredentialExpiry(value)

    fun parseCredentialLeaseReceipt(
        reference: String?,
        generation: String?,
        leaseExpiresAt: String?,
    ): NativeCredentialLeaseReceipt {
        if (reference == null || generation == null || leaseExpiresAt == null) {
            fail("invalid_native_credential_lease_receipt", "The credential lease receipt is missing")
        }
        try {
            validateOpaque(reference, "nsc_", "credential lease reference")
        } catch (_: NativeSessionProtocolException) {
            fail("invalid_native_credential_lease_receipt", "The credential lease receipt is invalid")
        }
        val parsedGeneration = generation.toIntOrNull()
        if (parsedGeneration == null || parsedGeneration <= 0 || generation != parsedGeneration.toString()) {
            fail("invalid_native_credential_lease_receipt", "The credential lease receipt is invalid")
        }
        val expiry = try {
            Instant.parse(leaseExpiresAt)
        } catch (_: Exception) {
            fail("invalid_native_credential_lease_receipt", "The credential lease receipt is invalid")
        }
        if (!expiry.isAfter(Instant.now())) {
            fail("invalid_native_credential_lease_receipt", "The credential lease receipt is invalid")
        }
        return NativeCredentialLeaseReceipt(
            credentialReference = reference,
            credentialGeneration = parsedGeneration,
            leaseExpiresAt = leaseExpiresAt,
            leaseExpiry = expiry,
        )
    }

    fun exchangeRequestDigest(
        ticket: NativeEstablishTicket,
        installation: NativeInstallationMaterial,
    ): String = sha256Hex(
        frame(
            "usernode.native-session.exchange-request.v2",
            listOf(
                "protocol" to ticket.protocol.toString(),
                "attemptId" to ticket.attemptId,
                "desiredRuntime" to ticket.desiredRuntime,
                "ticketHash" to sha256Hex(ticket.ticket.toByteArray(StandardCharsets.UTF_8)),
                "ticketRequestDigest" to ticket.requestDigest,
                "installationId" to installation.installationId,
                "keyGeneration" to installation.keyGeneration.toString(),
                "possessionPublicJwk" to installation.possessionCanonicalJwk,
                "envelopePublicJwk" to installation.envelopeCanonicalJwk,
                "proofAlgorithm" to "ES256",
            ),
        ),
    )

    fun derEcdsaToP1363(der: ByteArray): ByteArray {
        var offset = 0
        fun readByte(): Int {
            if (offset >= der.size) fail("invalid_native_possession_proof", "Truncated ECDSA signature")
            return der[offset++].toInt() and 0xff
        }
        fun readLength(): Int {
            val first = readByte()
            if (first < 0x80) return first
            val count = first and 0x7f
            if (count !in 1..2) fail("invalid_native_possession_proof", "Invalid ECDSA length")
            var length = 0
            repeat(count) { length = (length shl 8) or readByte() }
            if (length < 0x80) fail("invalid_native_possession_proof", "Non-canonical ECDSA length")
            return length
        }
        if (readByte() != 0x30) fail("invalid_native_possession_proof", "Invalid ECDSA sequence")
        val sequenceLength = readLength()
        if (sequenceLength != der.size - offset) {
            fail("invalid_native_possession_proof", "Invalid ECDSA sequence length")
        }
        fun readInteger(): ByteArray {
            if (readByte() != 0x02) fail("invalid_native_possession_proof", "Invalid ECDSA integer")
            val length = readLength()
            if (length !in 1..33 || offset + length > der.size) {
                fail("invalid_native_possession_proof", "Invalid ECDSA integer length")
            }
            val value = der.copyOfRange(offset, offset + length)
            offset += length
            if ((value[0].toInt() and 0x80) != 0 ||
                (value.size > 1 && value[0] == 0.toByte() && (value[1].toInt() and 0x80) == 0)
            ) {
                fail("invalid_native_possession_proof", "Non-canonical ECDSA integer")
            }
            val unsigned = if (value.size == 33) value.copyOfRange(1, value.size) else value
            if (unsigned.size > 32) fail("invalid_native_possession_proof", "Oversized ECDSA integer")
            return ByteArray(32 - unsigned.size) + unsigned
        }
        val r = readInteger()
        val s = readInteger()
        if (offset != der.size) fail("invalid_native_possession_proof", "Trailing ECDSA data")
        return r + s
    }

    fun encodeBase64Url(bytes: ByteArray): String = Base64.encodeToString(
        bytes,
        Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING,
    )

    fun decodeCanonicalBase64Url(value: String, expectedSize: Int?, label: String): ByteArray {
        val decoded = try {
            Base64.decode(value, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
        } catch (_: IllegalArgumentException) {
            fail("invalid_native_base64", "$label is not canonical base64url")
        }
        if ((expectedSize != null && decoded.size != expectedSize) || encodeBase64Url(decoded) != value) {
            fail("invalid_native_base64", "$label is not canonical base64url")
        }
        return decoded
    }

    fun sha256Hex(bytes: ByteArray): String = MessageDigest.getInstance("SHA-256")
        .digest(bytes)
        .joinToString("") { "%02x".format(it.toInt() and 0xff) }

    fun sha256Base64Url(bytes: ByteArray): String =
        encodeBase64Url(MessageDigest.getInstance("SHA-256").digest(bytes))

    fun decodeHex32(value: String, label: String): ByteArray {
        if (!hex64Pattern.matches(value)) {
            fail("invalid_native_hex", "$label is not a canonical 32-byte hex value")
        }
        return ByteArray(32) { index ->
            value.substring(index * 2, index * 2 + 2).toInt(16).toByte()
        }
    }

    private fun frame(domain: String, fields: List<Pair<String, String>>): ByteArray {
        val output = ByteArrayOutputStream()
        output.write(domain.toByteArray(StandardCharsets.US_ASCII))
        output.write(0)
        for ((name, value) in fields) {
            val encoded = value.toByteArray(StandardCharsets.UTF_8)
            output.write("$name:${encoded.size}:".toByteArray(StandardCharsets.US_ASCII))
            output.write(encoded)
            output.write('\n'.code)
        }
        return output.toByteArray()
    }

    private fun fixedUnsigned(raw: ByteArray, size: Int): ByteArray {
        var start = 0
        while (start < raw.size - 1 && raw[start] == 0.toByte()) start++
        val length = raw.size - start
        if (length > size) fail("invalid_native_installation", "Public key coordinate is oversized")
        return ByteArray(size - length) + raw.copyOfRange(start, raw.size)
    }

    private fun decodeAccountScalar(value: String): ByteArray {
        val separator = value.lastIndexOf('1')
        if (separator != 4 || value.substring(0, separator) != "utsk" ||
            value.any { it.isUpperCase() } || value.length > 128
        ) {
            fail("invalid_native_credential", "The account secret key is invalid")
        }
        val alphabet = "qpzry9x8gf2tvdw0s3jn54khce6mua7l"
        val data = IntArray(value.length - separator - 1)
        for (index in data.indices) {
            val digit = alphabet.indexOf(value[separator + 1 + index])
            if (digit < 0) fail("invalid_native_credential", "The account secret key is invalid")
            data[index] = digit
        }
        if (data.size < 7 || bech32Polymod("utsk", data) != 0x2bc830a3) {
            fail("invalid_native_credential", "The account secret key checksum is invalid")
        }
        val payload = data.copyOfRange(0, data.size - 6)
        val output = ByteArrayOutputStream()
        var accumulator = 0
        var bits = 0
        for (digit in payload) {
            accumulator = ((accumulator and 0xfff) shl 5) or digit
            bits += 5
            while (bits >= 8) {
                bits -= 8
                output.write((accumulator shr bits) and 0xff)
            }
        }
        if (bits >= 5 || ((accumulator shl (8 - bits)) and 0xff) != 0) {
            fail("invalid_native_credential", "The account secret key padding is invalid")
        }
        return output.toByteArray().also { scalar ->
            // The platform must decode the exact Bech32m representation for
            // the fixed JNI frame; Rust owns scalar-field semantics.
            if (scalar.size != 32) {
                scalar.fill(0)
                fail("invalid_native_credential", "The account secret key scalar is invalid")
            }
        }
    }

    private fun bech32Polymod(hrp: String, data: IntArray): Int {
        var checksum = 1
        val generators = intArrayOf(
            0x3b6a57b2,
            0x26508e6d,
            0x1ea119fa,
            0x3d4233dd,
            0x2a1462b3,
        )
        fun step(value: Int) {
            val top = checksum ushr 25
            checksum = (checksum and 0x1ffffff) shl 5 xor value
            for (index in generators.indices) {
                if (((top ushr index) and 1) != 0) checksum = checksum xor generators[index]
            }
        }
        for (character in hrp) step(character.code ushr 5)
        step(0)
        for (character in hrp) step(character.code and 31)
        for (digit in data) step(digit)
        return checksum
    }

    private fun exactMap(raw: Any?, expected: Set<String>, label: String): Map<String, Any?> {
        if (raw !is Map<*, *> || raw.keys.any { it !is String }) {
            fail("invalid_native_protocol_object", "$label must be an object")
        }
        @Suppress("UNCHECKED_CAST")
        val map = raw as Map<String, Any?>
        if (map.keys != expected) {
            fail("invalid_native_protocol_object", "$label has unexpected fields")
        }
        return map
    }

    private fun exactInt(raw: Any?, label: String): Int = when (raw) {
        is Int -> raw
        is Long -> if (raw in Int.MIN_VALUE..Int.MAX_VALUE) raw.toInt() else {
            fail("invalid_native_integer", "$label is out of range")
        }
        else -> fail("invalid_native_integer", "$label must be an integer")
    }

    private fun canonicalString(raw: Any?, label: String): String {
        if (raw !is String || raw.isEmpty() || raw != raw.trim()) {
            fail("invalid_native_string", "$label must be a canonical string")
        }
        return raw
    }

    fun decodeStrictUtf8(bytes: ByteArray): String = try {
        StandardCharsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
            .decode(ByteBuffer.wrap(bytes))
            .toString()
    } catch (_: Exception) {
        fail("invalid_native_credential", "The native credential is not UTF-8")
    }

    private fun parseJsonObject(raw: String, label: String): JSONObject = try {
        JSONObject(raw)
    } catch (_: Exception) {
        fail("invalid_native_credential", "$label is not valid JSON")
    }

    private fun validateOpaque(value: String, prefix: String, label: String) {
        if (!value.startsWith(prefix)) {
            fail("invalid_native_base64", "$label is not a canonical opaque value")
        }
        decodeCanonicalBase64Url(value.substring(prefix.length), 32, label)
            .fill(0)
    }

    private fun parseCredentialExpiry(value: String): Instant = try {
        Instant.parse(value)
    } catch (_: Exception) {
        fail("invalid_native_credential", "The native credential expiry is invalid")
    }

    private fun exactJsonKeys(value: JSONObject, expected: Set<String>, label: String) {
        if (jsonKeys(value) != expected) {
            fail("invalid_native_credential", "$label has unexpected fields")
        }
    }

    private fun jsonKeys(value: JSONObject): Set<String> {
        val actual = mutableSetOf<String>()
        val keys = value.keys()
        while (keys.hasNext()) actual += keys.next()
        return actual
    }

    private fun jsonObject(parent: JSONObject, key: String): JSONObject =
        parent.optJSONObject(key)
            ?: fail("invalid_native_credential", "$key must be an object")

    private fun jsonString(parent: JSONObject, key: String): String =
        canonicalString(parent.opt(key), key)

    private fun boundedCanonicalJsonString(parent: JSONObject, key: String, maxLength: Int): String {
        val value = jsonString(parent, key)
        if (value.toByteArray(StandardCharsets.UTF_8).size > maxLength) {
            fail("invalid_native_credential", "$key is too long")
        }
        return value
    }

    private fun jsonInt(parent: JSONObject, key: String): Int = exactJsonInt(parent.opt(key), key)

    private fun exactJsonInt(raw: Any?, label: String): Int = when (raw) {
        is Int -> raw
        is Long -> if (raw in Int.MIN_VALUE..Int.MAX_VALUE) raw.toInt() else {
            fail("invalid_native_credential", "$label is out of range")
        }
        else -> fail("invalid_native_credential", "$label must be an integer")
    }

    private fun jsonBoolean(parent: JSONObject, key: String): Boolean {
        val value = parent.opt(key)
        if (value !is Boolean) fail("invalid_native_credential", "$key must be a boolean")
        return value
    }

    private fun fail(code: String, message: String): Nothing =
        throw NativeSessionProtocolException(code, message)
}
