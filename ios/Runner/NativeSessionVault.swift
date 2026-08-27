import CryptoKit
import Foundation
import Security

enum IOSColdCredentialStage {
  case present(Data)
  case absent
  case uncertain
}

enum IOSProducerWakeCredential {
  case present(evidence: Data, policy: Data)
  case absent
  case uncertain
}

private struct IOSRecoveredCredential {
  let storedRaw: Data
  let binding: NativeCredentialBinding
  let installFrame: Data
  var credential: NativeCredentialPlaintext
}

/// The sole iOS owner of installation keys, the encrypted credential, and
/// purpose-specific authenticated Social calls. No bearer/decrypt primitive is
/// exposed through Flutter or to another feature owner.
final class IOSNativeSessionVault {
  static let shared = IOSNativeSessionVault()

  private let lock = NSRecursiveLock()
  private let defaults = UserDefaults.standard
  private var configuredHTTP: IOSNativeSessionHTTP?

  private init() {}

  func configureMobileApiBaseUrl(_ raw: String) throws {
    lock.lock(); defer { lock.unlock() }
    let next = try IOSNativeSessionHTTP(raw)
    if let configuredHTTP {
      guard configuredHTTP.canonicalBaseUrl == next.canonicalBaseUrl else {
        try NativeSessionProtocol.fail(
          "native_api_origin_conflict",
          "The native mobile API origin changed within one process"
        )
      }
      return
    }
    if let persisted = defaults.string(forKey: Self.mobileApiBaseUrlKey),
       persisted != next.canonicalBaseUrl {
      try NativeSessionProtocol.fail(
        "native_api_origin_conflict",
        "The native mobile API origin changed within one installation"
      )
    }
    defaults.set(next.canonicalBaseUrl, forKey: Self.mobileApiBaseUrlKey)
    configuredHTTP = next
  }

  func prepareExchange(_ rawTicket: Any?) throws -> [String: Any] {
    lock.lock(); defer { lock.unlock() }
    let ticket = try NativeSessionProtocol.parseTicket(rawTicket)
    let installation = try loadInstallation()
    let transcript = NativeSessionProtocol.possessionTranscript(ticket, installation)
    let privateKey = try loadPrivateKey(tag: Self.possessionTag)
    var error: Unmanaged<CFError>?
    guard let der = SecKeyCreateSignature(
      privateKey,
      .ecdsaSignatureMessageX962SHA256,
      transcript as CFData,
      &error
    ) as Data? else {
      try NativeSessionProtocol.fail(
        "native_key_unavailable", "The native possession proof could not be created"
      )
    }
    let signature = try NativeSessionProtocol.derEcdsaToP1363(der)
    return try NativeSessionProtocol.exchangeRequest(ticket, installation, signature)
  }

  func installCredential(ticket rawTicket: Any?, exchange rawExchange: Any?) throws -> Data {
    lock.lock(); defer { lock.unlock() }
    let ticket = try NativeSessionProtocol.parseTicket(rawTicket)
    let installation = try loadInstallation()
    let exchange = try NativeSessionProtocol.parseExchange(
      rawExchange, ticket: ticket, installation: installation
    )
    let binding = NativeSessionProtocol.binding(
      ticket: ticket, installation: installation, exchange: exchange
    )
    let plaintext = try decryptCompactJwe(exchange.compactJwe, installation: installation)
    var credential = try NativeSessionProtocol.validateCredential(
      plaintext, binding: binding, installation: installation
    )
    defer { credential.accountScalar.resetBytes(in: 0..<credential.accountScalar.count) }
    let fingerprint = try credentialFingerprint(
      binding: binding, installation: installation, credential: credential
    )
    let commitment = try persistCredential(
      binding: binding,
      installation: installation,
      exchange: exchange,
      fingerprint: fingerprint
    )
    var frame = try buildInstallFrame(
      binding: binding,
      installation: installation,
      credential: credential,
      commitment: commitment
    )
    defer { frame.resetBytes(in: 0..<frame.count) }
    return try IOSNativeSessionRust.stageInstalledCredential(&frame)
  }

  func retireCredential(
    reference: String,
    generation: UInt64,
    commitment: Data,
    readyRevision: UInt64
  ) throws {
    lock.lock(); defer { lock.unlock() }
    guard !reference.isEmpty, generation > 0, commitment.count == 32 else {
      try NativeSessionProtocol.fail(
        "invalid_native_retirement", "The native retirement directive is invalid"
      )
    }
    if let raw = try readKeychain(account: Self.credentialAccount) {
      let record = try parseStoredRecord(raw)
      guard record["credentialReference"] as? String == reference,
            try NativeSessionProtocol.exactUInt64(
              record["credentialGeneration"], "stored credential generation"
            ) == generation,
            try NativeSessionProtocol.decodeBase64Url(
              record["vaultCommitment"] as? String ?? "",
              expected: 32,
              label: "stored vault commitment"
            ) == commitment else {
        try NativeSessionProtocol.fail(
          "native_retirement_mismatch", "The native retirement directive is mismatched"
        )
      }
      try deleteKeychain(account: Self.credentialAccount, expected: raw)
    }
    try clearReadyRevision(expected: readyRevision)
  }

  func stageColdInstalledCredential() -> IOSColdCredentialStage {
    lock.lock(); defer { lock.unlock() }
    let raw: Data
    do {
      guard let stored = try readKeychain(account: Self.credentialAccount) else {
        return .absent
      }
      raw = stored
    } catch {
      return .uncertain
    }
    do {
      var recovered = try recoverCredential(raw)
      defer {
        recovered.installFrame.withUnsafeBytes { _ in }
        recovered.credential.accountScalar.resetBytes(
          in: 0..<recovered.credential.accountScalar.count
        )
      }
      var frame = recovered.installFrame
      defer { frame.resetBytes(in: 0..<frame.count) }
      return .present(try IOSNativeSessionRust.stageColdInstalledCredential(&frame))
    } catch let error as NativeSessionProtocolError where error.code == "native_credential_expired" {
      try? deleteKeychain(account: Self.credentialAccount, expected: raw)
      return .absent
    } catch {
      return .uncertain
    }
  }

  func producerWakeCredential(
    refreshPolicy: Bool,
    coldInstallClaim: Data? = nil
  ) -> IOSProducerWakeCredential {
    lock.lock(); defer { lock.unlock() }
    if let coldInstallClaim, coldInstallClaim.count != 32 { return .uncertain }
    let raw: Data
    do {
      guard let stored = try readKeychain(account: Self.credentialAccount) else {
        return .absent
      }
      raw = stored
    } catch {
      return .uncertain
    }
    if !refreshPolicy {
      do {
        return .present(
          evidence: try vaultEvidenceFrame(raw, coldInstallClaim: coldInstallClaim),
          policy: Data()
        )
      } catch {
        return .uncertain
      }
    }
    do {
      var recovered = try recoverCredential(raw)
      defer {
        recovered.credential.accountScalar.resetBytes(
          in: 0..<recovered.credential.accountScalar.count
        )
      }
      switch try http().getProducerPolicy(bearer: recovered.credential.bearerToken) {
      case .success(let body):
        return .present(
          evidence: try vaultEvidenceFrame(raw, coldInstallClaim: coldInstallClaim),
          policy: try producerPolicyFrame(
            body, binding: recovered.binding, credential: recovered.credential
          )
        )
      case .unauthorized:
        try? deleteKeychain(account: Self.credentialAccount, expected: raw)
        return .absent
      case .failure:
        return .uncertain
      }
    } catch let error as NativeSessionProtocolError where error.code == "native_credential_expired" {
      try? deleteKeychain(account: Self.credentialAccount, expected: raw)
      return .absent
    } catch {
      return .uncertain
    }
  }

  func stageBackgroundColdInstalledCredential() -> IOSColdCredentialStage {
    stageColdInstalledCredential()
  }

  func stageProducerPolicy(delegated: Bool?) throws -> Data {
    lock.lock(); defer { lock.unlock() }
    var recovered = try recoverForManagedCall()
    defer {
      recovered.credential.accountScalar.resetBytes(
        in: 0..<recovered.credential.accountScalar.count
      )
    }
    let response: IOSNativeHTTPResult
    if let delegated {
      response = try http().setProducerPolicy(
        bearer: recovered.credential.bearerToken,
        delegated: delegated,
        requestId: "ndp_\(NativeSessionProtocol.base64Url(try randomData(count: 32)))"
      )
    } else {
      response = try http().getProducerPolicy(bearer: recovered.credential.bearerToken)
    }
    let body = try requireManagedSuccess(response, recovered: recovered)
    var frame = try producerPolicyFrame(
      body, binding: recovered.binding, credential: recovered.credential
    )
    defer { frame.resetBytes(in: 0..<frame.count) }
    return try IOSNativeSessionRust.stageProducerPolicy(&frame)
  }

  func getPushStatus(installationId: String) throws -> [String: Any] {
    lock.lock(); defer { lock.unlock() }
    try validateInstallationUUID(installationId)
    var recovered = try recoverForManagedCall()
    defer { recovered.credential.accountScalar.resetBytes(in: 0..<recovered.credential.accountScalar.count) }
    return try pushStatus(try requireManagedSuccess(
      http().getPushStatus(
        bearer: recovered.credential.bearerToken,
        installationId: installationId
      ),
      recovered: recovered
    ))
  }

  func registerPush(
    installationId: String,
    providerToken: String,
    platform: String,
    permissionStatus: String,
    mutationRevision: UInt64
  ) throws -> [String: Any] {
    lock.lock(); defer { lock.unlock() }
    try validateInstallationUUID(installationId)
    guard !providerToken.isEmpty, providerToken.count <= 4096,
          ["android", "ios"].contains(platform),
          ["authorized", "provisional", "denied", "not_determined"].contains(permissionStatus),
          mutationRevision > 0 else {
      try NativeSessionProtocol.fail(
        "invalid_native_push_request", "The push registration request is invalid"
      )
    }
    var recovered = try recoverForManagedCall()
    defer { recovered.credential.accountScalar.resetBytes(in: 0..<recovered.credential.accountScalar.count) }
    let body = try requireManagedSuccess(
      http().registerPush(
        bearer: recovered.credential.bearerToken,
        installationId: installationId,
        providerToken: providerToken,
        platform: platform,
        permissionStatus: permissionStatus,
        mutationRevision: mutationRevision
      ),
      recovered: recovered
    )
    return try pushMutation(
      body,
      installationId: installationId,
      mutationRevision: mutationRevision,
      registered: true
    )
  }

  func unregisterPush(
    installationId: String,
    mutationRevision: UInt64,
    reason: String
  ) throws -> [String: Any] {
    lock.lock(); defer { lock.unlock() }
    try validateInstallationUUID(installationId)
    let reasons: Set<String> = [
      "client_request", "notifications_disabled", "permission_denied", "signed_out",
      "account_changed", "identity_boundary", "terminal_reset", "configuration_unavailable",
    ]
    guard mutationRevision > 0, reasons.contains(reason) else {
      try NativeSessionProtocol.fail(
        "invalid_native_push_request", "The push unregistration request is invalid"
      )
    }
    var recovered = try recoverForManagedCall()
    defer { recovered.credential.accountScalar.resetBytes(in: 0..<recovered.credential.accountScalar.count) }
    let body = try requireManagedSuccess(
      http().unregisterPush(
        bearer: recovered.credential.bearerToken,
        installationId: installationId,
        mutationRevision: mutationRevision,
        reason: reason
      ),
      recovered: recovered
    )
    return try pushMutation(
      body,
      installationId: installationId,
      mutationRevision: mutationRevision,
      registered: false
    )
  }

  func resolveLegacyZkPassportChallengeId() throws -> Int {
    lock.lock(); defer { lock.unlock() }
    var recovered = try recoverForManagedCall()
    defer { recovered.credential.accountScalar.resetBytes(in: 0..<recovered.credential.accountScalar.count) }
    let seasons = try requireArray(
      try requireManagedSuccess(
        http().getSeasons(bearer: recovered.credential.bearerToken), recovered: recovered
      )["data"],
      code: "invalid_native_zk_completion_response"
    )
    let seasonIds = try seasons.compactMap { raw -> Int? in
      guard let season = raw as? [String: Any], season["is_active"] as? Bool == true else {
        return nil
      }
      let id = try NativeSessionProtocol.exactInt(season["season_id"], "season id")
      guard id > 0 else {
        try NativeSessionProtocol.fail(
          "invalid_native_zk_completion_response", "The active season response is invalid"
        )
      }
      return id
    }
    guard seasonIds.count == 1 else {
      throw IOSNativeManagedHTTPError(
        statusCode: 409,
        errorCode: seasonIds.isEmpty ? "active_zk_challenge_unavailable" : "ambiguous_active_zk_challenge",
        latestMutationRevision: nil
      )
    }
    let challenges = try requireArray(
      try requireManagedSuccess(
        http().getChallenges(
          bearer: recovered.credential.bearerToken, seasonId: seasonIds[0]
        ),
        recovered: recovered
      )["data"],
      code: "invalid_native_zk_completion_response"
    )
    let ids = try challenges.compactMap { raw -> Int? in
      guard let challenge = raw as? [String: Any],
            challenge["kind"] as? String == "ZK_IDENTITY_VERIFICATION",
            challenge["enabled"] as? Bool != false else { return nil }
      let id = try NativeSessionProtocol.exactInt(challenge["id"], "challenge id")
      guard id > 0 else {
        try NativeSessionProtocol.fail(
          "invalid_native_zk_completion_response", "The active challenge response is invalid"
        )
      }
      return id
    }
    guard ids.count == 1 else {
      throw IOSNativeManagedHTTPError(
        statusCode: 409,
        errorCode: ids.isEmpty ? "active_zk_challenge_unavailable" : "ambiguous_active_zk_challenge",
        latestMutationRevision: nil
      )
    }
    return ids[0]
  }

  func completeLegacyZkPassport(
    challengeId: Int,
    sessionId: String,
    nullifierHex: String,
    completedAt: String?
  ) throws -> [String: Any] {
    lock.lock(); defer { lock.unlock() }
    guard challengeId > 0, !sessionId.isEmpty, sessionId.count <= 255,
          sessionId == sessionId.trimmingCharacters(in: .whitespacesAndNewlines),
          nullifierHex.range(of: "^0x[0-9a-fA-F]+$", options: .regularExpression) != nil,
          nullifierHex.count <= 255,
          completedAt.map({ !$0.isEmpty && $0.count <= 64 && $0 == $0.trimmingCharacters(in: .whitespacesAndNewlines) }) ?? true else {
      try NativeSessionProtocol.fail(
        "invalid_native_zk_completion", "The zkPassport completion is invalid"
      )
    }
    var recovered = try recoverForManagedCall()
    defer { recovered.credential.accountScalar.resetBytes(in: 0..<recovered.credential.accountScalar.count) }
    _ = try requireManagedSuccess(
      http().completeZkPassport(
        bearer: recovered.credential.bearerToken,
        challengeId: challengeId,
        walletAddress: recovered.credential.address,
        sessionId: sessionId,
        nullifierHex: nullifierHex,
        completedAt: completedAt
      ),
      recovered: recovered
    )
    return ["challengeId": challengeId]
  }

  func setReadyRevision(_ revision: UInt64) {
    lock.lock(); defer { lock.unlock() }
    defaults.set(String(revision), forKey: Self.readyRevisionKey)
  }

  func readyRevision() -> UInt64? {
    lock.lock(); defer { lock.unlock() }
    guard let raw = defaults.string(forKey: Self.readyRevisionKey) else { return nil }
    return UInt64(raw)
  }

  func isReadyRevision(_ revision: UInt64) -> Bool { readyRevision() == revision }

  func clearReadyRevision(expected: UInt64) throws {
    lock.lock(); defer { lock.unlock() }
    if let current = readyRevision(), current != expected {
      try NativeSessionProtocol.fail(
        "native_session_not_current", "The native session is not current"
      )
    }
    defaults.removeObject(forKey: Self.readyRevisionKey)
  }

  private func recoverForManagedCall() throws -> IOSRecoveredCredential {
    guard let raw = try readKeychain(account: Self.credentialAccount) else {
      try NativeSessionProtocol.fail("native_vault_absent", "The native credential is absent")
    }
    do {
      return try recoverCredential(raw)
    } catch let error as NativeSessionProtocolError where error.code == "native_credential_expired" {
      try? deleteKeychain(account: Self.credentialAccount, expected: raw)
      throw error
    }
  }

  private func requireManagedSuccess(
    _ response: IOSNativeHTTPResult,
    recovered: IOSRecoveredCredential
  ) throws -> [String: Any] {
    switch response {
    case .success(let body): return body
    case .unauthorized:
      try? deleteKeychain(account: Self.credentialAccount, expected: recovered.storedRaw)
      throw IOSNativeManagedHTTPError(
        statusCode: 401, errorCode: "native_credential_invalid", latestMutationRevision: nil
      )
    case .failure(let status, let code, let latest):
      throw IOSNativeManagedHTTPError(
        statusCode: status, errorCode: code, latestMutationRevision: latest
      )
    }
  }

  private func recoverCredential(_ raw: Data) throws -> IOSRecoveredCredential {
    let stored = try parseStoredRecord(raw)
    let installation = try loadInstallation()
    guard stored["installationId"] as? String == installation.installationId,
          try NativeSessionProtocol.exactInt(
            stored["installationGeneration"], "stored installation generation"
          ) == 1,
          stored["possessionKeyThumbprint"] as? String == installation.possessionThumbprint,
          stored["envelopeKeyThumbprint"] as? String == installation.envelopeThumbprint,
          stored["envelopeKeyId"] as? String == installation.envelopeKeyId,
          stored["envelopeAlgorithm"] as? String == "RSA-OAEP",
          stored["envelopeEncryption"] as? String == "A256GCM" else {
      try NativeSessionProtocol.fail(
        "native_credential_mismatch", "The stored native installation is mismatched"
      )
    }
    let binding = NativeCredentialBinding(
      attemptId: try NativeSessionProtocol.canonicalString(stored["attemptId"], "stored attempt"),
      ticketHash: try NativeSessionProtocol.canonicalString(stored["ticketHash"], "stored ticket hash"),
      requestDigest: try NativeSessionProtocol.canonicalString(stored["requestDigest"], "stored request digest"),
      exchangeRequestDigest: try NativeSessionProtocol.canonicalString(stored["exchangeRequestDigest"], "stored exchange digest"),
      exchangeChallenge: try NativeSessionProtocol.canonicalString(stored["exchangeChallenge"], "stored exchange challenge"),
      networkId: try NativeSessionProtocol.canonicalString(stored["networkId"], "stored network"),
      chainId: try NativeSessionProtocol.canonicalString(stored["chainId"], "stored chain"),
      credentialReference: try NativeSessionProtocol.canonicalString(stored["credentialReference"], "stored credential reference"),
      credentialGeneration: try NativeSessionProtocol.exactUInt64(stored["credentialGeneration"], "stored credential generation")
    )
    _ = try NativeSessionProtocol.decodeHex32(binding.ticketHash, label: "stored ticket hash")
    _ = try NativeSessionProtocol.decodeHex32(binding.requestDigest, label: "stored request digest")
    _ = try NativeSessionProtocol.decodeHex32(binding.exchangeRequestDigest, label: "stored exchange digest")
    _ = try NativeSessionProtocol.decodeBase64Url(binding.exchangeChallenge, expected: 32, label: "stored exchange challenge")
    let compact = try NativeSessionProtocol.canonicalString(stored["compactJwe"], "stored envelope")
    let plaintext = try decryptCompactJwe(compact, installation: installation)
    var credential = try NativeSessionProtocol.validateCredential(
      plaintext, binding: binding, installation: installation
    )
    do {
      let fingerprint = try credentialFingerprint(
        binding: binding, installation: installation, credential: credential
      )
      guard NativeSessionProtocol.base64Url(fingerprint) == stored["fingerprint"] as? String else {
        try NativeSessionProtocol.fail(
          "native_credential_mismatch", "The stored credential fingerprint is mismatched"
        )
      }
      let commitment = try NativeSessionProtocol.decodeBase64Url(
        stored["vaultCommitment"] as? String ?? "",
        expected: 32,
        label: "stored vault commitment"
      )
      let frame = try buildInstallFrame(
        binding: binding,
        installation: installation,
        credential: credential,
        commitment: commitment
      )
      return IOSRecoveredCredential(
        storedRaw: raw, binding: binding, installFrame: frame, credential: credential
      )
    } catch {
      credential.accountScalar.resetBytes(in: 0..<credential.accountScalar.count)
      throw error
    }
  }

  private func loadInstallation() throws -> NativeInstallationMaterial {
    let storedId = try readKeychain(account: Self.installationAccount)
      .flatMap { String(data: $0, encoding: .utf8) }
    let possession = try findPrivateKey(tag: Self.possessionTag)
    let envelope = try findPrivateKey(tag: Self.envelopeTag)
    if storedId != nil && (possession == nil || envelope == nil) {
      try NativeSessionProtocol.fail(
        "native_installation_recovery_required",
        "The native installation keys no longer match durable storage"
      )
    }
    let possessionKey = try possession ?? createPrivateKey(
      type: kSecAttrKeyTypeECSECPrimeRandom,
      size: 256,
      tag: Self.possessionTag
    )
    let envelopeKey = try envelope ?? createPrivateKey(
      type: kSecAttrKeyTypeRSA,
      size: 3072,
      tag: Self.envelopeTag
    )
    let installationId: String
    if let storedId {
      installationId = storedId
    } else {
      installationId = "nsi_\(NativeSessionProtocol.base64Url(try randomData(count: 32)))"
      try writeKeychain(account: Self.installationAccount, value: Data(installationId.utf8))
    }
    guard let possessionPublic = SecKeyCopyPublicKey(possessionKey),
          let envelopePublic = SecKeyCopyPublicKey(envelopeKey) else {
      try NativeSessionProtocol.fail(
        "native_key_unavailable", "A native installation key is unavailable"
      )
    }
    var error: Unmanaged<CFError>?
    guard let ec = SecKeyCopyExternalRepresentation(possessionPublic, &error) as Data?,
          ec.count == 65, ec.first == 0x04 else {
      try NativeSessionProtocol.fail(
        "invalid_native_installation", "The possession key is not P-256"
      )
    }
    let modulus = try NativeSessionProtocol.rsaModulus(from: envelopePublic)
    return NativeInstallationMaterial(
      installationId: installationId,
      possessionX: NativeSessionProtocol.base64Url(ec.subdata(in: 1..<33)),
      possessionY: NativeSessionProtocol.base64Url(ec.subdata(in: 33..<65)),
      envelopeModulus: NativeSessionProtocol.base64Url(modulus)
    )
  }

  private func decryptCompactJwe(
    _ compact: String,
    installation: NativeInstallationMaterial
  ) throws -> Data {
    let parts = compact.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
    guard parts.count == 5, parts.allSatisfy({ !$0.isEmpty }) else {
      try NativeSessionProtocol.fail(
        "invalid_native_credential_envelope", "The compact JWE is invalid"
      )
    }
    let protectedData = try NativeSessionProtocol.decodeBase64Url(parts[0], label: "JWE protected header")
    guard let header = try JSONSerialization.jsonObject(with: protectedData) as? [String: Any],
          Set(header.keys) == ["alg", "enc", "kid", "typ"],
          header["alg"] as? String == "RSA-OAEP",
          header["enc"] as? String == "A256GCM",
          header["kid"] as? String == installation.envelopeKeyId,
          header["typ"] as? String == "application/usernode-native-session-credential+jwe" else {
      try NativeSessionProtocol.fail(
        "native_credential_mismatch", "The JWE protected header is mismatched"
      )
    }
    let encryptedKey = try NativeSessionProtocol.decodeBase64Url(
      parts[1], expected: 384, label: "JWE encrypted key"
    )
    let iv = try NativeSessionProtocol.decodeBase64Url(parts[2], expected: 12, label: "JWE IV")
    let ciphertext = try NativeSessionProtocol.decodeBase64Url(parts[3], label: "JWE ciphertext")
    let tag = try NativeSessionProtocol.decodeBase64Url(parts[4], expected: 16, label: "JWE tag")
    guard !ciphertext.isEmpty, ciphertext.count <= 32 * 1024 else {
      try NativeSessionProtocol.fail(
        "invalid_native_credential_envelope", "The JWE ciphertext size is invalid"
      )
    }
    let privateKey = try loadPrivateKey(tag: Self.envelopeTag)
    var error: Unmanaged<CFError>?
    guard let cek = SecKeyCreateDecryptedData(
      privateKey, .rsaEncryptionOAEPSHA1, encryptedKey as CFData, &error
    ) as Data?, cek.count == 32 else {
      try NativeSessionProtocol.fail(
        "invalid_native_credential_envelope", "The JWE content key is invalid"
      )
    }
    do {
      let sealed = try AES.GCM.SealedBox(
        nonce: AES.GCM.Nonce(data: iv), ciphertext: ciphertext, tag: tag
      )
      let plaintext = try AES.GCM.open(
        sealed,
        using: SymmetricKey(data: cek),
        authenticating: Data(parts[0].utf8)
      )
      guard !plaintext.isEmpty, plaintext.count <= 32 * 1024 else {
        try NativeSessionProtocol.fail(
          "invalid_native_credential_envelope", "The credential plaintext size is invalid"
        )
      }
      return plaintext
    } catch let error as NativeSessionProtocolError {
      throw error
    } catch {
      try NativeSessionProtocol.fail(
        "invalid_native_credential_envelope", "The native credential could not be decrypted"
      )
    }
  }

  private func credentialFingerprint(
    binding: NativeCredentialBinding,
    installation: NativeInstallationMaterial,
    credential: NativeCredentialPlaintext
  ) throws -> Data {
    var frame = Data("UNVF".utf8)
    try NativeSessionProtocol.appendString(binding.attemptId, maximum: 64, to: &frame)
    frame.append(try NativeSessionProtocol.decodeHex32(binding.ticketHash, label: "ticket hash"))
    frame.append(try NativeSessionProtocol.decodeHex32(binding.requestDigest, label: "ticket request digest"))
    frame.append(try NativeSessionProtocol.decodeHex32(binding.exchangeRequestDigest, label: "exchange request digest"))
    try NativeSessionProtocol.appendString(binding.networkId, maximum: 32, to: &frame)
    try NativeSessionProtocol.appendString(binding.chainId, maximum: 96, to: &frame)
    try NativeSessionProtocol.appendString(installation.installationId, maximum: 64, to: &frame)
    frame.appendUInt64(1)
    frame.append(try NativeSessionProtocol.decodeBase64Url(installation.possessionThumbprint, expected: 32, label: "possession thumbprint"))
    frame.append(try NativeSessionProtocol.decodeBase64Url(installation.envelopeThumbprint, expected: 32, label: "envelope thumbprint"))
    try NativeSessionProtocol.appendString(binding.credentialReference, maximum: 64, to: &frame)
    frame.appendUInt64(binding.credentialGeneration)
    try NativeSessionProtocol.appendString(credential.participantId, maximum: 32, to: &frame)
    try NativeSessionProtocol.appendString(credential.accountId, maximum: 32, to: &frame)
    try NativeSessionProtocol.appendString(credential.address, maximum: 128, to: &frame)
    try NativeSessionProtocol.appendString(credential.publicKey, maximum: 128, to: &frame)
    frame.append(credential.blockProductionReleased ? 1 : 0)
    return NativeSessionProtocol.sha256(frame)
  }

  private func persistCredential(
    binding: NativeCredentialBinding,
    installation: NativeInstallationMaterial,
    exchange: NativeExchangeEnvelope,
    fingerprint: Data
  ) throws -> Data {
    if let existingRaw = try readKeychain(account: Self.credentialAccount) {
      let existing = try parseStoredRecord(existingRaw)
      guard existing["fingerprint"] as? String == NativeSessionProtocol.base64Url(fingerprint),
            existing["compactJwe"] as? String == exchange.compactJwe else {
        try NativeSessionProtocol.fail(
          "native_vault_occupied", "A different native credential is already installed"
        )
      }
      return try NativeSessionProtocol.decodeBase64Url(
        existing["vaultCommitment"] as? String ?? "",
        expected: 32,
        label: "stored vault commitment"
      )
    }
    let commitment = try randomData(count: 32)
    let record: [String: Any] = [
      "version": 3,
      "attemptId": binding.attemptId,
      "ticketHash": binding.ticketHash,
      "requestDigest": binding.requestDigest,
      "exchangeRequestDigest": binding.exchangeRequestDigest,
      "exchangeChallenge": binding.exchangeChallenge,
      "networkId": binding.networkId,
      "chainId": binding.chainId,
      "installationId": installation.installationId,
      "installationGeneration": 1,
      "possessionKeyThumbprint": installation.possessionThumbprint,
      "envelopeKeyThumbprint": installation.envelopeThumbprint,
      "credentialReference": binding.credentialReference,
      "credentialGeneration": NSNumber(value: binding.credentialGeneration),
      "envelopeAlgorithm": "RSA-OAEP",
      "envelopeEncryption": "A256GCM",
      "envelopeKeyId": installation.envelopeKeyId,
      "compactJwe": exchange.compactJwe,
      "fingerprint": NativeSessionProtocol.base64Url(fingerprint),
      "vaultCommitment": NativeSessionProtocol.base64Url(commitment),
    ]
    let raw = try JSONSerialization.data(withJSONObject: record, options: [.sortedKeys])
    try writeKeychain(account: Self.credentialAccount, value: raw)
    return commitment
  }

  private func buildInstallFrame(
    binding: NativeCredentialBinding,
    installation: NativeInstallationMaterial,
    credential: NativeCredentialPlaintext,
    commitment: Data
  ) throws -> Data {
    var frame = Data("UNSI".utf8)
    frame.append(1); frame.append(1)
    try NativeSessionProtocol.appendString(binding.attemptId, maximum: 64, to: &frame)
    frame.append(try NativeSessionProtocol.decodeHex32(binding.ticketHash, label: "ticket hash"))
    frame.append(try NativeSessionProtocol.decodeHex32(binding.requestDigest, label: "ticket request digest"))
    frame.append(try NativeSessionProtocol.decodeHex32(binding.exchangeRequestDigest, label: "exchange digest"))
    frame.append(try NativeSessionProtocol.decodeBase64Url(binding.exchangeChallenge, expected: 32, label: "exchange challenge"))
    try NativeSessionProtocol.appendString(binding.networkId, maximum: 32, to: &frame)
    try NativeSessionProtocol.appendString(binding.chainId, maximum: 96, to: &frame)
    try NativeSessionProtocol.appendString(installation.installationId, maximum: 64, to: &frame)
    frame.appendUInt64(1)
    frame.append(try NativeSessionProtocol.decodeBase64Url(installation.possessionThumbprint, expected: 32, label: "possession thumbprint"))
    frame.append(try NativeSessionProtocol.decodeBase64Url(installation.envelopeThumbprint, expected: 32, label: "envelope thumbprint"))
    try NativeSessionProtocol.appendString(binding.credentialReference, maximum: 64, to: &frame)
    frame.appendUInt64(binding.credentialGeneration)
    try NativeSessionProtocol.appendString(credential.participantId, maximum: 32, to: &frame)
    try NativeSessionProtocol.appendString(credential.accountId, maximum: 32, to: &frame)
    try NativeSessionProtocol.appendString(credential.address, maximum: 128, to: &frame)
    try NativeSessionProtocol.appendString(credential.publicKey, maximum: 128, to: &frame)
    frame.append(credential.blockProductionReleased ? 1 : 0)
    frame.append(commitment)
    frame.append(credential.accountScalar)
    guard frame.count <= 1024 else {
      try NativeSessionProtocol.fail(
        "native_install_frame_too_large", "The native install frame is too large"
      )
    }
    return frame
  }

  private func vaultEvidenceFrame(_ raw: Data, coldInstallClaim: Data?) throws -> Data {
    let stored = try parseStoredRecord(raw)
    let installation = try loadInstallation()
    guard stored["installationId"] as? String == installation.installationId,
          stored["possessionKeyThumbprint"] as? String == installation.possessionThumbprint,
          stored["envelopeKeyThumbprint"] as? String == installation.envelopeThumbprint,
          stored["envelopeKeyId"] as? String == installation.envelopeKeyId else {
      try NativeSessionProtocol.fail(
        "native_credential_mismatch", "The stored native installation is mismatched"
      )
    }
    let reference = try NativeSessionProtocol.canonicalString(
      stored["credentialReference"], "stored credential reference"
    )
    let generation = try NativeSessionProtocol.exactUInt64(
      stored["credentialGeneration"], "stored credential generation"
    )
    let commitment = try NativeSessionProtocol.decodeBase64Url(
      stored["vaultCommitment"] as? String ?? "", expected: 32, label: "stored vault commitment"
    )
    let fingerprint = try NativeSessionProtocol.decodeBase64Url(
      stored["fingerprint"] as? String ?? "", expected: 32, label: "stored request fingerprint"
    )
    var frame = Data("UNVE".utf8); frame.append(1)
    try NativeSessionProtocol.appendString(reference, maximum: 64, to: &frame)
    frame.appendUInt64(generation); frame.append(commitment); frame.append(fingerprint)
    if let coldInstallClaim { frame.append(32); frame.append(coldInstallClaim) } else { frame.append(0) }
    return frame
  }

  private func producerPolicyFrame(
    _ response: [String: Any],
    binding: NativeCredentialBinding,
    credential: NativeCredentialPlaintext
  ) throws -> Data {
    guard response["success"] as? Bool == true,
          let data = response["data"] as? [String: Any],
          try NativeSessionProtocol.exactInt(data["protocol"], "policy protocol") == 1,
          let account = data["account"] as? [String: Any],
          let network = data["network"] as? [String: Any],
          let epochs = data["epochs"] as? [Any], epochs.count == 3 else {
      try NativeSessionProtocol.fail(
        "invalid_native_policy_response", "The authenticated producer policy response is invalid"
      )
    }
    let policyRevision = try NativeSessionProtocol.canonicalString(data["policyRevision"], "policy revision")
    let reference = try NativeSessionProtocol.canonicalString(data["credentialReference"], "credential reference")
    let generation = try NativeSessionProtocol.exactUInt64(data["credentialGeneration"], "credential generation")
    let accountId = try NativeSessionProtocol.canonicalString(account["accountId"], "account id")
    let address = try NativeSessionProtocol.canonicalString(account["address"], "address")
    let networkId = try NativeSessionProtocol.canonicalString(network["id"], "network id")
    let chainId = try NativeSessionProtocol.canonicalString(network["chainId"], "chain id")
    let observed = try NativeSessionProtocol.exactInt(data["observedEpoch"], "observed epoch")
    guard policyRevision.utf8.count <= 32,
          reference == binding.credentialReference,
          generation == binding.credentialGeneration,
          accountId == credential.accountId,
          address == credential.address,
          networkId == binding.networkId,
          chainId == binding.chainId,
          observed >= 0,
          UInt64(observed) <= UInt64(UInt32.max) - 2 else {
      try NativeSessionProtocol.fail(
        "invalid_native_policy_response", "The authenticated producer policy response is invalid"
      )
    }
    var frame = Data("UNDP".utf8); frame.append(1); frame.append(1)
    try NativeSessionProtocol.appendString(policyRevision, maximum: 32, to: &frame)
    try NativeSessionProtocol.appendString(reference, maximum: 64, to: &frame)
    frame.appendUInt64(generation)
    try NativeSessionProtocol.appendString(accountId, maximum: 32, to: &frame)
    try NativeSessionProtocol.appendString(address, maximum: 128, to: &frame)
    try NativeSessionProtocol.appendString(networkId, maximum: 32, to: &frame)
    try NativeSessionProtocol.appendString(chainId, maximum: 96, to: &frame)
    frame.appendUInt32(UInt32(observed)); frame.append(3)
    for index in 0..<3 {
      guard let epoch = epochs[index] as? [String: Any],
            try NativeSessionProtocol.exactInt(epoch["epoch"], "epoch") == observed + index,
            let delegated = epoch["delegated"] as? Bool else {
        try NativeSessionProtocol.fail(
          "invalid_native_policy_response", "The authenticated producer policy response is invalid"
        )
      }
      frame.appendUInt32(UInt32(observed + index)); frame.append(delegated ? 1 : 0)
    }
    guard frame.count <= 512 else {
      try NativeSessionProtocol.fail(
        "invalid_native_policy_response", "The authenticated producer policy response is invalid"
      )
    }
    return frame
  }

  private func pushStatus(_ response: [String: Any]) throws -> [String: Any] {
    guard response["success"] as? Bool == true,
          let registered = response["registered"] as? Bool,
          let active = response["delivery_active"] as? Bool,
          let environment = response["environment"] as? String, !environment.isEmpty,
          environment.count <= 64,
          let project = response["firebase_project_id"] as? String, !project.isEmpty,
          project.count <= 128,
          registered || !active else {
      try NativeSessionProtocol.fail(
        "invalid_native_push_response", "The authenticated push response is invalid"
      )
    }
    return [
      "registered": registered,
      "deliveryActive": active,
      "environment": environment,
      "firebaseProjectId": project,
    ]
  }

  private func pushMutation(
    _ response: [String: Any],
    installationId: String,
    mutationRevision: UInt64,
    registered: Bool
  ) throws -> [String: Any] {
    var status = try pushStatus(response)
    guard status["registered"] as? Bool == registered,
          response["mutation_revision"] as? String == String(mutationRevision) else {
      try NativeSessionProtocol.fail(
        "invalid_native_push_response", "The authenticated push response is invalid"
      )
    }
    if !registered {
      guard let cleanup = response["installation_cleanup"] as? [String: Any],
            cleanup["installation_id"] as? String == installationId,
            cleanup["mutation_revision"] as? String == String(mutationRevision),
            cleanup["environment"] as? String == status["environment"] as? String else {
        try NativeSessionProtocol.fail(
          "invalid_native_push_response", "The authenticated push response is invalid"
        )
      }
    }
    status["mutationRevision"] = NSNumber(value: mutationRevision)
    return status
  }

  private func parseStoredRecord(_ raw: Data) throws -> [String: Any] {
    guard let record = try JSONSerialization.jsonObject(with: raw) as? [String: Any],
          Set(record.keys) == NativeSessionProtocol.storedRecordKeys,
          try NativeSessionProtocol.exactInt(record["version"], "stored version") == 3 else {
      try NativeSessionProtocol.fail(
        "native_vault_corrupt", "The native credential record is invalid"
      )
    }
    return record
  }

  private func http() throws -> IOSNativeSessionHTTP {
    if let configuredHTTP { return configuredHTTP }
    guard let persisted = defaults.string(forKey: Self.mobileApiBaseUrlKey) else {
      try NativeSessionProtocol.fail(
        "native_api_unavailable", "The native mobile API origin has not been configured"
      )
    }
    let configured = try IOSNativeSessionHTTP(persisted)
    configuredHTTP = configured
    return configured
  }

  private func validateInstallationUUID(_ value: String) throws {
    guard UUID(uuidString: value)?.uuidString.lowercased() == value.lowercased(),
          value == value.lowercased() else {
      try NativeSessionProtocol.fail(
        "invalid_native_push_request", "The push installation id is invalid"
      )
    }
  }

  private func requireArray(_ raw: Any?, code: String) throws -> [Any] {
    guard let value = raw as? [Any] else {
      try NativeSessionProtocol.fail(code, "The authenticated response is invalid")
    }
    return value
  }

  private func randomData(count: Int) throws -> Data {
    var bytes = Data(count: count)
    let status = bytes.withUnsafeMutableBytes {
      SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!)
    }
    guard status == errSecSuccess else {
      try NativeSessionProtocol.fail(
        "native_random_unavailable", "Secure random data is unavailable"
      )
    }
    return bytes
  }

  private func findPrivateKey(tag: Data) throws -> SecKey? {
    let query: [CFString: Any] = [
      kSecClass: kSecClassKey,
      kSecAttrApplicationTag: tag,
      kSecAttrKeyClass: kSecAttrKeyClassPrivate,
      kSecReturnRef: true,
    ]
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let key = result as! SecKey? else {
      try NativeSessionProtocol.fail("native_key_unavailable", "A native installation key is unavailable")
    }
    return key
  }

  private func loadPrivateKey(tag: Data) throws -> SecKey {
    guard let key = try findPrivateKey(tag: tag) else {
      try NativeSessionProtocol.fail("native_key_unavailable", "A native installation key is unavailable")
    }
    return key
  }

  private func createPrivateKey(type: CFString, size: Int, tag: Data) throws -> SecKey {
    let attributes: [CFString: Any] = [
      kSecAttrKeyType: type,
      kSecAttrKeySizeInBits: size,
      kSecPrivateKeyAttrs: [
        kSecAttrIsPermanent: true,
        kSecAttrApplicationTag: tag,
        kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      ],
    ]
    var error: Unmanaged<CFError>?
    guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
      try NativeSessionProtocol.fail("native_key_unavailable", "A native installation key could not be created")
    }
    return key
  }

  private func readKeychain(account: String) throws -> Data? {
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: Self.keychainService,
      kSecAttrAccount: account,
      kSecReturnData: true,
      kSecMatchLimit: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = result as? Data else {
      try NativeSessionProtocol.fail("native_vault_unavailable", "The native vault is unavailable")
    }
    return data
  }

  private func writeKeychain(account: String, value: Data) throws {
    guard try readKeychain(account: account) == nil else {
      try NativeSessionProtocol.fail("native_vault_occupied", "The native vault item already exists")
    }
    let attributes: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: Self.keychainService,
      kSecAttrAccount: account,
      kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      kSecValueData: value,
    ]
    guard SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess else {
      try NativeSessionProtocol.fail("native_vault_write_failed", "The native vault could not be persisted")
    }
  }

  private func deleteKeychain(account: String, expected: Data) throws {
    guard try readKeychain(account: account) == expected else {
      try NativeSessionProtocol.fail(
        "native_retirement_mismatch", "The native credential changed during retirement"
      )
    }
    let query: [CFString: Any] = [
      kSecClass: kSecClassGenericPassword,
      kSecAttrService: Self.keychainService,
      kSecAttrAccount: account,
    ]
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      try NativeSessionProtocol.fail("native_vault_write_failed", "The native credential could not be retired")
    }
  }

  private static let keychainService = "org.usernode.app.native-session-v2"
  private static let installationAccount = "installation-id"
  private static let credentialAccount = "credential-record"
  private static let possessionTag = Data("org.usernode.app.native-session-v2.possession.1".utf8)
  private static let envelopeTag = Data("org.usernode.app.native-session-v2.envelope.1".utf8)
  private static let mobileApiBaseUrlKey = "native_session_v2_mobile_api_base_url"
  private static let readyRevisionKey = "native_session_v2_ready_revision"
}

struct IOSNativeManagedHTTPError: Error {
  let statusCode: Int
  let errorCode: String?
  let latestMutationRevision: UInt64?
}

private enum IOSNativeHTTPResult {
  case success([String: Any])
  case unauthorized
  case failure(Int, String?, UInt64?)
}

private final class IOSNativeSessionHTTP: NSObject, URLSessionTaskDelegate {
  let canonicalBaseUrl: String

  init(_ raw: String) throws {
    let trimmed = raw.hasSuffix("/") ? String(raw.dropLast()) : raw
    guard let components = URLComponents(string: trimmed),
          components.scheme == "https", components.host != nil,
          components.user == nil, components.password == nil,
          components.query == nil, components.fragment == nil,
          components.path.hasSuffix("/api/v4/mobile") else {
      try NativeSessionProtocol.fail(
        "invalid_native_api_base_url", "The native mobile API base URL is invalid"
      )
    }
    canonicalBaseUrl = trimmed
  }

  func getProducerPolicy(bearer: String) -> IOSNativeHTTPResult {
    request(method: "GET", path: "native/delegation", bearer: bearer)
  }

  func setProducerPolicy(bearer: String, delegated: Bool, requestId: String) -> IOSNativeHTTPResult {
    request(
      method: "POST",
      path: "native/delegation",
      bearer: bearer,
      body: ["requestId": requestId, "delegated": delegated]
    )
  }

  func getPushStatus(bearer: String, installationId: String) -> IOSNativeHTTPResult {
    let encoded = installationId.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
    return request(
      method: "GET",
      path: "push-registration?installation_id=\(encoded)",
      bearer: bearer
    )
  }

  func registerPush(
    bearer: String,
    installationId: String,
    providerToken: String,
    platform: String,
    permissionStatus: String,
    mutationRevision: UInt64
  ) -> IOSNativeHTTPResult {
    request(
      method: "PUT",
      path: "push-registration",
      bearer: bearer,
      body: [
        "installation_id": installationId,
        "mutation_revision": String(mutationRevision),
        "provider": "fcm",
        "platform": platform,
        "permission_status": permissionStatus,
        "registration": providerToken,
      ]
    )
  }

  func unregisterPush(
    bearer: String,
    installationId: String,
    mutationRevision: UInt64,
    reason: String
  ) -> IOSNativeHTTPResult {
    request(
      method: "DELETE",
      path: "push-registration",
      bearer: bearer,
      body: [
        "installation_id": installationId,
        "mutation_revision": String(mutationRevision),
        "reason": reason,
      ]
    )
  }

  func getSeasons(bearer: String) -> IOSNativeHTTPResult {
    request(method: "GET", path: "seasons?include_challenges=0", bearer: bearer)
  }

  func getChallenges(bearer: String, seasonId: Int) -> IOSNativeHTTPResult {
    request(
      method: "GET", path: "challenges?season_id=\(seasonId)&active_only=1", bearer: bearer
    )
  }

  func completeZkPassport(
    bearer: String,
    challengeId: Int,
    walletAddress: String,
    sessionId: String,
    nullifierHex: String,
    completedAt: String?
  ) -> IOSNativeHTTPResult {
    var body: [String: Any] = [
      "challenge_id": challengeId,
      "wallet_address": walletAddress,
      "session_id": sessionId,
      "nullifier_hex": nullifierHex,
    ]
    if let completedAt { body["completed_at"] = completedAt }
    return request(method: "POST", path: "zkpassport/complete", bearer: bearer, body: body)
  }

  private func request(
    method: String,
    path: String,
    bearer: String,
    body: [String: Any]? = nil
  ) -> IOSNativeHTTPResult {
    guard let url = URL(string: "\(canonicalBaseUrl)/\(path)"), url.scheme == "https" else {
      return .failure(0, nil, nil)
    }
    var request = URLRequest(url: url, timeoutInterval: 15)
    request.httpMethod = method
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization")
    if let body {
      guard let encoded = try? JSONSerialization.data(withJSONObject: body), encoded.count <= 16 * 1024 else {
        return .failure(0, nil, nil)
      }
      request.httpBody = encoded
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 15
    configuration.timeoutIntervalForResource = 15
    let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    let semaphore = DispatchSemaphore(value: 0)
    var result: IOSNativeHTTPResult = .failure(0, nil, nil)
    session.dataTask(with: request) { data, response, _ in
      defer { semaphore.signal() }
      guard let response = response as? HTTPURLResponse,
            let data, data.count <= 64 * 1024 else { return }
      if response.statusCode == 401 { result = .unauthorized; return }
      let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
      if (200..<300).contains(response.statusCode), let json {
        result = .success(json)
      } else {
        let code = (json?["code"] as? String).flatMap {
          $0.range(of: "^[a-z0-9_]{1,64}$", options: .regularExpression) == nil ? nil : $0
        }
        let latest = (json?["latest_mutation_revision"] as? String).flatMap(UInt64.init)
        result = .failure(response.statusCode, code, latest)
      }
    }.resume()
    guard semaphore.wait(timeout: .now() + 20) == .success else {
      session.invalidateAndCancel()
      return .failure(0, nil, nil)
    }
    session.finishTasksAndInvalidate()
    return result
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping (URLRequest?) -> Void
  ) {
    completionHandler(nil)
  }
}
