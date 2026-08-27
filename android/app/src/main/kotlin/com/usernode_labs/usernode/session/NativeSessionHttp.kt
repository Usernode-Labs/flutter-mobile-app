package com.usernode_labs.usernode.session

import java.io.ByteArrayOutputStream
import java.io.DataOutputStream
import java.net.HttpURLConnection
import java.net.URLEncoder
import java.net.URL
import java.nio.charset.StandardCharsets
import org.json.JSONArray
import org.json.JSONObject

/**
 * The only Android HTTP client allowed to see the native mobile bearer.
 *
 * It is deliberately purpose-specific: callers can fetch/update delegation,
 * push registration, or the retained zkPassport completion, but cannot choose
 * a URL, read the bearer, or make an arbitrary authenticated request.
 */
internal class NativeSessionHttp(
    mobileApiBaseUrl: String,
) {
    internal val canonicalBaseUrl = validateBaseUrl(mobileApiBaseUrl)
    fun getProducerPolicy(bearer: String): NativeHttpResult =
        request("GET", "native/delegation", bearer)

    fun setProducerPolicy(bearer: String, delegated: Boolean, requestId: String): NativeHttpResult =
        request(
            "POST",
            "native/delegation",
            bearer,
            JSONObject()
                .put("requestId", requestId)
                .put("delegated", delegated),
        )

    fun logout(bearer: String): NativeHttpResult =
        request("POST", "auth/logout", bearer)

    fun getPushStatus(bearer: String, installationId: String): NativeHttpResult =
        request(
            "GET",
            "push-registration?installation_id=${urlEncode(installationId)}",
            bearer,
        )

    fun registerPush(
        bearer: String,
        installationId: String,
        providerToken: String,
        platform: String,
        permissionStatus: String,
        mutationRevision: Long,
    ): NativeHttpResult = request(
        "PUT",
        "push-registration",
        bearer,
        JSONObject()
            .put("installation_id", installationId)
            .put("mutation_revision", mutationRevision.toString())
            .put("provider", "fcm")
            .put("platform", platform)
            .put("permission_status", permissionStatus)
            .put("registration", providerToken),
    )

    fun unregisterPush(
        bearer: String,
        installationId: String,
        mutationRevision: Long,
        reason: String,
    ): NativeHttpResult = request(
        "DELETE",
        "push-registration",
        bearer,
        JSONObject()
            .put("installation_id", installationId)
            .put("mutation_revision", mutationRevision.toString())
            .put("reason", reason),
    )

    fun getSeasonsForLegacyZkCompletion(bearer: String): NativeHttpResult =
        request("GET", "seasons?include_challenges=0", bearer)

    fun getChallengesForLegacyZkCompletion(
        bearer: String,
        seasonId: Int,
    ): NativeHttpResult = request(
        "GET",
        "challenges?season_id=$seasonId&active_only=1",
        bearer,
    )

    fun completeLegacyZkPassport(
        bearer: String,
        challengeId: Int,
        walletAddress: String,
        sessionId: String,
        nullifierHex: String,
        completedAt: String?,
    ): NativeHttpResult = request(
        "POST",
        "zkpassport/complete",
        bearer,
        JSONObject()
            .put("challenge_id", challengeId)
            .put("wallet_address", walletAddress)
            .put("session_id", sessionId)
            .put("nullifier_hex", nullifierHex)
            .also { body ->
                if (completedAt != null) body.put("completed_at", completedAt)
            },
    )

    private fun request(
        method: String,
        relativePath: String,
        bearer: String,
        body: JSONObject? = null,
    ): NativeHttpResult {
        val url = URL("$canonicalBaseUrl/$relativePath")
        if (url.protocol != "https") {
            return NativeHttpResult.Failure(0, null, null)
        }
        val connection = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = method
            instanceFollowRedirects = false
            connectTimeout = TIMEOUT_MS
            readTimeout = TIMEOUT_MS
            useCaches = false
            setRequestProperty("Accept", "application/json")
            setRequestProperty("Authorization", "Bearer $bearer")
            if (body != null) {
                doOutput = true
                setRequestProperty("Content-Type", "application/json")
            }
        }
        return try {
            if (body != null) {
                val encoded = body.toString().toByteArray(StandardCharsets.UTF_8)
                try {
                    if (encoded.size > MAX_REQUEST_BYTES) {
                        return NativeHttpResult.Failure(0, null, null)
                    }
                    connection.outputStream.use { it.write(encoded) }
                } finally {
                    encoded.fill(0)
                }
            }
            val status = connection.responseCode
            val leaseReceipt = readCredentialLeaseReceipt(connection)
            val response = readResponse(connection, status)
            if (status == HttpURLConnection.HTTP_UNAUTHORIZED) {
                NativeHttpResult.Unauthorized
            } else if (status in 200..299) {
                val json = try {
                    JSONObject(response)
                } catch (_: Exception) {
                    return NativeHttpResult.Failure(status, null, null)
                }
                NativeHttpResult.Success(json, leaseReceipt)
            } else {
                val error = try {
                    JSONObject(response)
                } catch (_: Exception) {
                    null
                }
                NativeHttpResult.Failure(
                    status,
                    error?.optString("code")?.takeIf(ERROR_CODE::matches),
                    error?.optString("latest_mutation_revision")
                        ?.takeIf(POSITIVE_DECIMAL::matches)
                        ?.toLongOrNull(),
                    leaseReceipt,
                )
            }
        } catch (_: Exception) {
            NativeHttpResult.Failure(0, null, null)
        } finally {
            connection.disconnect()
        }
    }

    private fun readResponse(connection: HttpURLConnection, status: Int): String {
        val stream = if (status in 200..299) connection.inputStream else connection.errorStream
            ?: return ""
        stream.use { input ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(4096)
            while (true) {
                val count = input.read(buffer)
                if (count < 0) break
                if (output.size() + count > MAX_RESPONSE_BYTES) return ""
                output.write(buffer, 0, count)
            }
            return output.toString(StandardCharsets.UTF_8.name())
        }
    }

    private fun readCredentialLeaseReceipt(
        connection: HttpURLConnection,
    ): NativeCredentialLeaseReceipt? = try {
        NativeSessionProtocol.parseCredentialLeaseReceipt(
            connection.getHeaderField(CREDENTIAL_REFERENCE_HEADER),
            connection.getHeaderField(CREDENTIAL_GENERATION_HEADER),
            connection.getHeaderField(CREDENTIAL_LEASE_EXPIRES_HEADER),
        )
    } catch (_: NativeSessionProtocolException) {
        null
    }

    private fun urlEncode(value: String): String =
        URLEncoder.encode(value, StandardCharsets.UTF_8.name()).replace("+", "%20")

    private companion object {
        const val TIMEOUT_MS = 15_000
        const val MAX_REQUEST_BYTES = 16 * 1024
        const val MAX_RESPONSE_BYTES = 64 * 1024
        val ERROR_CODE = Regex("^[a-z0-9_]{1,64}$")
        val POSITIVE_DECIMAL = Regex("^[1-9][0-9]{0,18}$")
        const val CREDENTIAL_REFERENCE_HEADER = "Usernode-Credential-Reference"
        const val CREDENTIAL_GENERATION_HEADER = "Usernode-Credential-Generation"
        const val CREDENTIAL_LEASE_EXPIRES_HEADER = "Usernode-Credential-Lease-Expires-At"

        fun validateBaseUrl(raw: String): String {
            val url = try {
                URL(raw.trimEnd('/'))
            } catch (_: Exception) {
                throw NativeSessionProtocolException(
                    "invalid_native_api_base_url",
                    "The native mobile API base URL is invalid",
                )
            }
            if (url.protocol != "https" ||
                url.userInfo != null ||
                url.query != null ||
                url.ref != null ||
                !url.path.endsWith("/api/v4/mobile")
            ) {
                throw NativeSessionProtocolException(
                    "invalid_native_api_base_url",
                    "The native mobile API base URL is invalid",
                )
            }
            return url.toExternalForm().trimEnd('/')
        }
    }
}

internal sealed interface NativeHttpResult {
    data class Success(
        val body: JSONObject,
        val credentialLease: NativeCredentialLeaseReceipt?,
    ) : NativeHttpResult
    object Unauthorized : NativeHttpResult
    data class Failure(
        val statusCode: Int,
        val code: String?,
        val latestMutationRevision: Long?,
        val credentialLease: NativeCredentialLeaseReceipt? = null,
    ) : NativeHttpResult
}

internal class NativeManagedHttpException(
    val statusCode: Int,
    val errorCode: String?,
    val latestMutationRevision: Long?,
) : Exception("The native managed request failed")

internal object NativeProducerPolicyFrame {
    fun encode(
        response: JSONObject,
        binding: NativeCredentialBinding,
        credential: NativeCredentialPlaintext,
    ): ByteArray {
        if (response.opt("success") != true) invalid()
        val data = response.optJSONObject("data") ?: invalid()
        val protocol = exactInt(data, "protocol")
        val policyRevision = string(data, "policyRevision", 32)
        val credentialReference = string(data, "credentialReference", 64)
        val credentialGeneration = exactLong(data, "credentialGeneration")
        val account = data.optJSONObject("account") ?: invalid()
        val accountId = string(account, "accountId", 32)
        val address = string(account, "address", 128)
        val network = data.optJSONObject("network") ?: invalid()
        val networkId = string(network, "id", 32)
        val chainId = string(network, "chainId", 96)
        val observedEpoch = exactInt(data, "observedEpoch")
        val epochs = data.optJSONArray("epochs") ?: invalid()
        if (protocol != 1 ||
            credentialReference != binding.credentialReference ||
            credentialGeneration != binding.credentialGeneration.toLong() ||
            accountId != credential.accountId ||
            address != credential.address ||
            networkId != binding.networkId ||
            chainId != binding.chainId ||
            observedEpoch < 0 ||
            epochs.length() != 3
        ) {
            invalid()
        }
        val bytes = ByteArrayOutputStream()
        DataOutputStream(bytes).use { output ->
            output.write("UNDP".toByteArray(StandardCharsets.US_ASCII))
            output.writeByte(1)
            output.writeByte(protocol)
            output.writeString(policyRevision)
            output.writeString(credentialReference)
            output.writeLong(credentialGeneration)
            output.writeString(accountId)
            output.writeString(address)
            output.writeString(networkId)
            output.writeString(chainId)
            output.writeInt(observedEpoch)
            output.writeByte(3)
            for (index in 0 until 3) {
                val epoch = epochs.optJSONObject(index) ?: invalid()
                val number = exactInt(epoch, "epoch")
                val delegated = epoch.opt("delegated") as? Boolean ?: invalid()
                if (number != observedEpoch + index) invalid()
                output.writeInt(number)
                output.writeByte(if (delegated) 1 else 0)
            }
        }
        return bytes.toByteArray().also {
            if (it.size > 512) {
                it.fill(0)
                invalid()
            }
        }
    }

    private fun DataOutputStream.writeString(value: String) {
        val encoded = value.toByteArray(StandardCharsets.UTF_8)
        writeShort(encoded.size)
        write(encoded)
    }

    private fun string(json: JSONObject, key: String, maximum: Int): String {
        val value = json.opt(key) as? String ?: invalid()
        if (value.isEmpty() || value.toByteArray(StandardCharsets.UTF_8).size > maximum) invalid()
        return value
    }

    private fun exactInt(json: JSONObject, key: String): Int {
        val value = json.opt(key)
        return when (value) {
            is Int -> value
            is Long -> value.takeIf { it in Int.MIN_VALUE..Int.MAX_VALUE }?.toInt()
            else -> null
        } ?: invalid()
    }

    private fun exactLong(json: JSONObject, key: String): Long {
        val value = json.opt(key)
        return when (value) {
            is Int -> value.toLong()
            is Long -> value
            else -> null
        }?.takeIf { it >= 0 } ?: invalid()
    }

    private fun invalid(): Nothing = throw NativeSessionProtocolException(
        "invalid_native_policy_response",
        "The authenticated producer policy response is invalid",
    )
}

internal object NativePushResponse {
    fun status(response: JSONObject): Map<String, Any> {
        if (response.opt("success") != true) invalid()
        val registered = response.opt("registered") as? Boolean ?: invalid()
        val deliveryActive = response.opt("delivery_active") as? Boolean ?: invalid()
        val environment = bounded(response, "environment", 64)
        val projectId = bounded(response, "firebase_project_id", 128)
        if (!registered && deliveryActive) invalid()
        return mapOf(
            "registered" to registered,
            "deliveryActive" to deliveryActive,
            "environment" to environment,
            "firebaseProjectId" to projectId,
        )
    }

    fun mutation(
        response: JSONObject,
        installationId: String,
        mutationRevision: Long,
        registered: Boolean,
    ): Map<String, Any> {
        val status = status(response).toMutableMap()
        if (status["registered"] != registered ||
            response.optString("mutation_revision") != mutationRevision.toString()
        ) {
            invalid()
        }
        if (!registered) {
            val cleanup = response.optJSONObject("installation_cleanup") ?: invalid()
            if (cleanup.optString("installation_id") != installationId ||
                cleanup.optString("mutation_revision") != mutationRevision.toString() ||
                cleanup.optString("environment") != status["environment"]
            ) {
                invalid()
            }
        }
        status["mutationRevision"] = mutationRevision
        return status
    }

    private fun bounded(json: JSONObject, key: String, maximum: Int): String {
        val value = json.opt(key) as? String ?: invalid()
        if (value.isEmpty() || value.length > maximum) invalid()
        return value
    }

    private fun invalid(): Nothing = throw NativeSessionProtocolException(
        "invalid_native_push_response",
        "The authenticated push response is invalid",
    )
}
