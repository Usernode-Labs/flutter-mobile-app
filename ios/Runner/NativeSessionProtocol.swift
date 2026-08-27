import CryptoKit
import Foundation
import Security

struct NativeSessionProtocolError: Error {
  let code: String
  let message: String
}

struct NativeEstablishTicket {
  let attemptId: String
  let ticket: String
  let requestDigest: String
  let exchangeChallenge: String
  let networkId: String
  let chainId: String
}

struct NativeInstallationMaterial {
  let installationId: String
  let possessionX: String
  let possessionY: String
  let envelopeModulus: String

  var possessionJwk: [String: Any] {
    ["kty": "EC", "crv": "P-256", "x": possessionX, "y": possessionY]
  }

  var envelopeJwk: [String: Any] {
    ["kty": "RSA", "n": envelopeModulus, "e": "AQAB"]
  }

  var possessionCanonicalJwk: String {
    "{\"crv\":\"P-256\",\"kty\":\"EC\",\"x\":\"\(possessionX)\",\"y\":\"\(possessionY)\"}"
  }

  var envelopeCanonicalJwk: String {
    "{\"e\":\"AQAB\",\"kty\":\"RSA\",\"n\":\"\(envelopeModulus)\"}"
  }

  var possessionThumbprint: String {
    NativeSessionProtocol.sha256Base64Url(Data(possessionCanonicalJwk.utf8))
  }

  var envelopeThumbprint: String {
    NativeSessionProtocol.sha256Base64Url(Data(envelopeCanonicalJwk.utf8))
  }

  var possessionKeyId: String { "nskp_\(possessionThumbprint)" }
  var envelopeKeyId: String { "nske_\(envelopeThumbprint)" }
}

struct NativeExchangeEnvelope {
  let credentialReference: String
  let credentialGeneration: UInt64
  let compactJwe: String
}

struct NativeCredentialBinding {
  let attemptId: String
  let ticketHash: String
  let requestDigest: String
  let exchangeRequestDigest: String
  let exchangeChallenge: String
  let networkId: String
  let chainId: String
  let credentialReference: String
  let credentialGeneration: UInt64
}

struct NativeCredentialPlaintext {
  let participantId: String
  let accountId: String
  let address: String
  let publicKey: String
  let bearerToken: String
  let bearerExpiresAt: String
  var accountScalar: Data
  let blockProductionReleased: Bool
}

enum NativeSessionProtocol {
  static let storedRecordKeys: Set<String> = [
    "version", "attemptId", "ticketHash", "requestDigest",
    "exchangeRequestDigest", "exchangeChallenge", "networkId", "chainId",
    "installationId", "installationGeneration", "possessionKeyThumbprint",
    "envelopeKeyThumbprint", "credentialReference", "credentialGeneration",
    "envelopeAlgorithm", "envelopeEncryption", "envelopeKeyId", "compactJwe",
    "fingerprint", "vaultCommitment",
  ]

  static func fail(_ code: String, _ message: String) throws -> Never {
    throw NativeSessionProtocolError(code: code, message: message)
  }

  static func exactDictionary(
    _ raw: Any?,
    keys: Set<String>,
    label: String
  ) throws -> [String: Any] {
    guard let dictionary = raw as? [String: Any], Set(dictionary.keys) == keys else {
      try fail("invalid_native_protocol_object", "\(label) has unexpected fields")
    }
    return dictionary
  }

  static func canonicalString(_ raw: Any?, _ label: String) throws -> String {
    guard let value = raw as? String, !value.isEmpty,
          value == value.trimmingCharacters(in: .whitespacesAndNewlines) else {
      try fail("invalid_native_string", "\(label) must be a canonical string")
    }
    return value
  }

  static func exactInt(_ raw: Any?, _ label: String) throws -> Int {
    guard let number = raw as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else {
      try fail("invalid_native_integer", "\(label) must be an integer")
    }
    let value = number.int64Value
    guard NSNumber(value: value) == number,
          value >= Int64(Int.min), value <= Int64(Int.max) else {
      try fail("invalid_native_integer", "\(label) is out of range")
    }
    return Int(value)
  }

  static func exactUInt64(_ raw: Any?, _ label: String) throws -> UInt64 {
    guard let number = raw as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
          number.int64Value >= 0, NSNumber(value: number.int64Value) == number else {
      try fail("invalid_native_integer", "\(label) must be a non-negative integer")
    }
    return UInt64(number.int64Value)
  }

  static func parseTicket(_ raw: Any?) throws -> NativeEstablishTicket {
    let map = try exactDictionary(
      raw,
      keys: [
        "protocol", "attemptId", "desiredRuntime", "ticket", "requestDigest",
        "exchangeChallenge", "network", "issuedAt", "expiresAt",
      ],
      label: "nativeEstablishTicket"
    )
    let network = try exactDictionary(
      map["network"], keys: ["id", "chainId"], label: "nativeEstablishTicket.network"
    )
    let attemptId = try canonicalString(map["attemptId"], "nativeEstablishTicket.attemptId")
    let ticket = try canonicalString(map["ticket"], "nativeEstablishTicket.ticket")
    let digest = try canonicalString(map["requestDigest"], "nativeEstablishTicket.requestDigest")
    let challenge = try canonicalString(
      map["exchangeChallenge"], "nativeEstablishTicket.exchangeChallenge"
    )
    let networkId = try canonicalString(network["id"], "nativeEstablishTicket.network.id")
    let chainId = try canonicalString(network["chainId"], "nativeEstablishTicket.network.chainId")
    let issued = try canonicalString(map["issuedAt"], "nativeEstablishTicket.issuedAt")
    let expires = try canonicalString(map["expiresAt"], "nativeEstablishTicket.expiresAt")
    guard try exactInt(map["protocol"], "nativeEstablishTicket.protocol") == 2,
          try canonicalString(map["desiredRuntime"], "nativeEstablishTicket.desiredRuntime") == "running",
          networkId == "testnet", isHex32(digest), !Data(chainId.utf8).isEmpty,
          Data(chainId.utf8).count <= 96 else {
      try fail("invalid_native_establish_ticket", "The native establishment ticket is invalid")
    }
    try validateOpaque(attemptId, prefix: "nsa_", label: "nativeEstablishTicket.attemptId")
    try validateOpaque(ticket, prefix: "nst_", label: "nativeEstablishTicket.ticket")
    _ = try decodeBase64Url(challenge, expected: 32, label: "nativeEstablishTicket.exchangeChallenge")
    guard let issuedDate = parseDate(issued), let expiresDate = parseDate(expires),
          expiresDate > issuedDate else {
      try fail("invalid_native_establish_ticket", "The ticket timestamps are invalid")
    }
    return NativeEstablishTicket(
      attemptId: attemptId,
      ticket: ticket,
      requestDigest: digest,
      exchangeChallenge: challenge,
      networkId: networkId,
      chainId: chainId
    )
  }

  static func possessionTranscript(
    _ ticket: NativeEstablishTicket,
    _ installation: NativeInstallationMaterial
  ) -> Data {
    frame(
      domain: "usernode.native-session.exchange-pop.v2",
      fields: [
        ("protocol", "2"),
        ("attemptId", ticket.attemptId),
        ("desiredRuntime", "running"),
        ("ticketHash", sha256Hex(Data(ticket.ticket.utf8))),
        ("ticketRequestDigest", ticket.requestDigest),
        ("exchangeChallenge", ticket.exchangeChallenge),
        ("installationId", installation.installationId),
        ("keyGeneration", "1"),
        ("possessionKeyThumbprint", installation.possessionThumbprint),
        ("envelopeKeyThumbprint", installation.envelopeThumbprint),
        ("networkId", ticket.networkId),
        ("chainId", ticket.chainId),
      ]
    )
  }

  static func exchangeRequest(
    _ ticket: NativeEstablishTicket,
    _ installation: NativeInstallationMaterial,
    _ signature: Data
  ) throws -> [String: Any] {
    guard signature.count == 64 else {
      try fail("invalid_native_possession_proof", "The possession signature is invalid")
    }
    return [
      "protocol": 2,
      "attemptId": ticket.attemptId,
      "desiredRuntime": "running",
      "ticket": ticket.ticket,
      "requestDigest": ticket.requestDigest,
      "installation": [
        "id": installation.installationId,
        "keyGeneration": 1,
        "possessionPublicJwk": installation.possessionJwk,
        "envelopePublicJwk": installation.envelopeJwk,
      ],
      "proof": ["algorithm": "ES256", "signature": base64Url(signature)],
    ]
  }

  static func parseExchange(
    _ raw: Any?,
    ticket: NativeEstablishTicket,
    installation: NativeInstallationMaterial
  ) throws -> NativeExchangeEnvelope {
    let map = try exactDictionary(
      raw,
      keys: [
        "protocol", "attemptId", "requestDigest", "credentialReference",
        "credentialGeneration", "envelope",
      ],
      label: "nativeEstablishExchange"
    )
    let envelope = try exactDictionary(
      map["envelope"],
      keys: ["format", "algorithm", "encryption", "keyId", "compactJwe"],
      label: "nativeEstablishExchange.envelope"
    )
    let reference = try canonicalString(
      map["credentialReference"], "nativeEstablishExchange.credentialReference"
    )
    let generation = try exactUInt64(
      map["credentialGeneration"], "nativeEstablishExchange.credentialGeneration"
    )
    guard try exactInt(map["protocol"], "nativeEstablishExchange.protocol") == 2,
          try canonicalString(map["attemptId"], "nativeEstablishExchange.attemptId") == ticket.attemptId,
          try canonicalString(map["requestDigest"], "nativeEstablishExchange.requestDigest") == ticket.requestDigest,
          generation == 1,
          envelope["format"] as? String == "compact-jwe",
          envelope["algorithm"] as? String == "RSA-OAEP",
          envelope["encryption"] as? String == "A256GCM",
          envelope["keyId"] as? String == installation.envelopeKeyId else {
      try fail("native_exchange_mismatch", "The native exchange response is mismatched")
    }
    try validateOpaque(reference, prefix: "nsc_", label: "native credential reference")
    let compactJwe = try canonicalString(
      envelope["compactJwe"], "nativeEstablishExchange.envelope.compactJwe"
    )
    guard compactJwe.count <= 65_536 else {
      try fail("invalid_native_credential_envelope", "The credential envelope is too large")
    }
    return NativeExchangeEnvelope(
      credentialReference: reference,
      credentialGeneration: generation,
      compactJwe: compactJwe
    )
  }

  static func binding(
    ticket: NativeEstablishTicket,
    installation: NativeInstallationMaterial,
    exchange: NativeExchangeEnvelope
  ) -> NativeCredentialBinding {
    NativeCredentialBinding(
      attemptId: ticket.attemptId,
      ticketHash: sha256Hex(Data(ticket.ticket.utf8)),
      requestDigest: ticket.requestDigest,
      exchangeRequestDigest: exchangeRequestDigest(ticket, installation),
      exchangeChallenge: ticket.exchangeChallenge,
      networkId: ticket.networkId,
      chainId: ticket.chainId,
      credentialReference: exchange.credentialReference,
      credentialGeneration: exchange.credentialGeneration
    )
  }

  static func exchangeRequestDigest(
    _ ticket: NativeEstablishTicket,
    _ installation: NativeInstallationMaterial
  ) -> String {
    sha256Hex(frame(
      domain: "usernode.native-session.exchange-request.v2",
      fields: [
        ("protocol", "2"),
        ("attemptId", ticket.attemptId),
        ("desiredRuntime", "running"),
        ("ticketHash", sha256Hex(Data(ticket.ticket.utf8))),
        ("ticketRequestDigest", ticket.requestDigest),
        ("installationId", installation.installationId),
        ("keyGeneration", "1"),
        ("possessionPublicJwk", installation.possessionCanonicalJwk),
        ("envelopePublicJwk", installation.envelopeCanonicalJwk),
        ("proofAlgorithm", "ES256"),
      ]
    ))
  }

  static func validateCredential(
    _ plaintext: Data,
    binding: NativeCredentialBinding,
    installation: NativeInstallationMaterial
  ) throws -> NativeCredentialPlaintext {
    guard !plaintext.isEmpty, plaintext.count <= 32 * 1024,
          let root = try JSONSerialization.jsonObject(with: plaintext) as? [String: Any],
          Set(root.keys) == [
            "protocol", "attemptId", "ticketRequestDigest", "exchangeRequestDigest",
            "ticketHash", "subject", "network", "installation", "credential", "account",
          ] else {
      try fail("invalid_native_credential", "The native credential is not valid JSON")
    }
    guard try exactInt(root["protocol"], "protocol") == 2,
          try canonicalString(root["attemptId"], "attemptId") == binding.attemptId,
          try canonicalString(root["ticketRequestDigest"], "ticketRequestDigest") == binding.requestDigest,
          try canonicalString(root["exchangeRequestDigest"], "exchangeRequestDigest") == binding.exchangeRequestDigest,
          try canonicalString(root["ticketHash"], "ticketHash") == binding.ticketHash else {
      try fail("native_credential_mismatch", "The native credential request binding is invalid")
    }
    let subject = try exactDictionary(root["subject"], keys: ["userId"], label: "native credential subject")
    let participantId = try canonicalString(subject["userId"], "subject.userId")
    guard isPositiveDecimal(participantId), participantId.utf8.count <= 32 else {
      try fail("invalid_native_credential", "The credential subject is invalid")
    }
    let network = try exactDictionary(root["network"], keys: ["id", "chainId"], label: "native credential network")
    guard try canonicalString(network["id"], "network.id") == binding.networkId,
          try canonicalString(network["chainId"], "network.chainId") == binding.chainId else {
      try fail("native_credential_mismatch", "The native credential network is invalid")
    }
    let installed = try exactDictionary(
      root["installation"],
      keys: [
        "id", "keyGeneration", "possessionKeyId", "possessionKeyThumbprint",
        "envelopeKeyId", "envelopeKeyThumbprint",
      ],
      label: "native credential installation"
    )
    guard try canonicalString(installed["id"], "installation.id") == installation.installationId,
          try exactInt(installed["keyGeneration"], "installation.keyGeneration") == 1,
          try canonicalString(installed["possessionKeyId"], "installation.possessionKeyId") == installation.possessionKeyId,
          try canonicalString(installed["possessionKeyThumbprint"], "installation.possessionKeyThumbprint") == installation.possessionThumbprint,
          try canonicalString(installed["envelopeKeyId"], "installation.envelopeKeyId") == installation.envelopeKeyId,
          try canonicalString(installed["envelopeKeyThumbprint"], "installation.envelopeKeyThumbprint") == installation.envelopeThumbprint else {
      try fail("native_credential_mismatch", "The native credential installation is invalid")
    }
    let authority = try exactDictionary(
      root["credential"],
      keys: ["reference", "generation", "bearerToken", "bearerExpiresAt"],
      label: "native credential authority"
    )
    let reference = try canonicalString(authority["reference"], "credential.reference")
    let generation = try exactUInt64(authority["generation"], "credential.generation")
    let bearer = try canonicalString(authority["bearerToken"], "credential.bearerToken")
    let expires = try canonicalString(authority["bearerExpiresAt"], "credential.bearerExpiresAt")
    guard reference == binding.credentialReference,
          generation == binding.credentialGeneration,
          bearer.count == 80, bearer.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) else {
      try fail("native_credential_mismatch", "The native credential authority is invalid")
    }
    guard let expiry = parseDate(expires) else {
      try fail("invalid_native_credential", "The native credential expiry is invalid")
    }
    guard expiry > Date() else {
      try fail("native_credential_expired", "The native credential is expired")
    }
    let account = try exactDictionary(
      root["account"],
      keys: [
        "accountId", "address", "publicKey", "secretKey", "seasonId",
        "seasonEventId", "newlyAllocated", "blockProductionReleased",
      ],
      label: "native credential account"
    )
    let accountId = try canonicalString(account["accountId"], "account.accountId")
    let address = try boundedString(account["address"], "account.address", 128)
    let publicKey = try boundedString(account["publicKey"], "account.publicKey", 128)
    let secretKey = try boundedString(account["secretKey"], "account.secretKey", 128)
    guard isPositiveDecimal(accountId), accountId.utf8.count <= 32,
          let released = account["blockProductionReleased"] as? Bool else {
      try fail("invalid_native_credential", "The native credential account is invalid")
    }
    return NativeCredentialPlaintext(
      participantId: participantId,
      accountId: accountId,
      address: address,
      publicKey: publicKey,
      bearerToken: bearer,
      bearerExpiresAt: expires,
      accountScalar: try decodeAccountScalar(secretKey),
      blockProductionReleased: released
    )
  }

  static func derEcdsaToP1363(_ der: Data) throws -> Data {
    var reader = DerReader(der)
    let sequence = try reader.read(tag: 0x30)
    guard reader.isAtEnd else {
      try fail("invalid_native_possession_proof", "Trailing ECDSA data")
    }
    var integers = DerReader(sequence)
    let r = try canonicalUnsignedInteger(integers.read(tag: 0x02), size: 32)
    let s = try canonicalUnsignedInteger(integers.read(tag: 0x02), size: 32)
    guard integers.isAtEnd else {
      try fail("invalid_native_possession_proof", "Trailing ECDSA data")
    }
    return r + s
  }

  static func rsaModulus(from publicKey: SecKey) throws -> Data {
    var error: Unmanaged<CFError>?
    guard let representation = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
      try fail("native_key_unavailable", "The native envelope public key is unavailable")
    }
    var reader = DerReader(representation)
    let sequence = try reader.read(tag: 0x30)
    guard reader.isAtEnd else {
      try fail("invalid_native_installation", "The envelope public key is invalid")
    }
    var body = DerReader(sequence)
    let modulus = try canonicalUnsignedInteger(body.read(tag: 0x02), size: 384)
    let exponent = try body.read(tag: 0x02)
    guard body.isAtEnd, exponent == Data([0x01, 0x00, 0x01]) else {
      try fail("invalid_native_installation", "The envelope public exponent is invalid")
    }
    return modulus
  }

  static func base64Url(_ data: Data) -> String {
    data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  static func decodeBase64Url(
    _ value: String,
    expected: Int? = nil,
    label: String
  ) throws -> Data {
    guard !value.contains("="),
          value.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else {
      try fail("invalid_native_base64", "\(label) is not canonical base64url")
    }
    var padded = value.replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    padded += String(repeating: "=", count: (4 - padded.count % 4) % 4)
    guard let decoded = Data(base64Encoded: padded),
          (expected == nil || decoded.count == expected), base64Url(decoded) == value else {
      try fail("invalid_native_base64", "\(label) is not canonical base64url")
    }
    return decoded
  }

  static func sha256(_ data: Data) -> Data { Data(SHA256.hash(data: data)) }
  static func sha256Hex(_ data: Data) -> String {
    sha256(data).map { String(format: "%02x", $0) }.joined()
  }
  static func sha256Base64Url(_ data: Data) -> String { base64Url(sha256(data)) }

  static func decodeHex32(_ value: String, label: String) throws -> Data {
    guard isHex32(value) else {
      try fail("invalid_native_hex", "\(label) is not a canonical 32-byte hex value")
    }
    var result = Data(capacity: 32)
    var index = value.startIndex
    for _ in 0..<32 {
      let next = value.index(index, offsetBy: 2)
      result.append(UInt8(value[index..<next], radix: 16)!)
      index = next
    }
    return result
  }

  static func appendString(_ value: String, maximum: Int, to data: inout Data) throws {
    let encoded = Data(value.utf8)
    guard !encoded.isEmpty, encoded.count <= maximum, encoded.count <= 0xffff else {
      try fail("native_install_frame_invalid", "A native install field is invalid")
    }
    data.appendUInt16(UInt16(encoded.count))
    data.append(encoded)
  }

  private static func frame(domain: String, fields: [(String, String)]) -> Data {
    var output = Data(domain.utf8)
    output.append(0)
    for (name, value) in fields {
      let encoded = Data(value.utf8)
      output.append(Data("\(name):\(encoded.count):".utf8))
      output.append(encoded)
      output.append(0x0a)
    }
    return output
  }

  private static func validateOpaque(_ value: String, prefix: String, label: String) throws {
    guard value.hasPrefix(prefix) else {
      try fail("invalid_native_base64", "\(label) is not a canonical opaque value")
    }
    _ = try decodeBase64Url(String(value.dropFirst(prefix.count)), expected: 32, label: label)
  }

  private static func boundedString(_ raw: Any?, _ label: String, _ maximum: Int) throws -> String {
    let value = try canonicalString(raw, label)
    guard value.utf8.count <= maximum else {
      try fail("invalid_native_credential", "\(label) is too long")
    }
    return value
  }

  private static func isHex32(_ value: String) -> Bool {
    value.count == 64 && value.allSatisfy { $0.isHexDigit && !$0.isUppercase }
  }

  private static func isPositiveDecimal(_ value: String) -> Bool {
    guard let first = value.first, first >= "1", first <= "9" else { return false }
    return value.allSatisfy(\.isNumber)
  }

  private static func parseDate(_ value: String) -> Date? {
    let fractional = ISO8601DateFormatter()
    fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
  }

  private static func canonicalUnsignedInteger(_ raw: Data, size: Int) throws -> Data {
    guard !raw.isEmpty, raw.count <= size + 1, raw.first! & 0x80 == 0 else {
      try fail("invalid_native_installation", "A public key integer is invalid")
    }
    var value = raw
    if value.count > 1, value.first == 0 {
      guard value[value.index(after: value.startIndex)] & 0x80 != 0 else {
        try fail("invalid_native_installation", "A public key integer is non-canonical")
      }
      value.removeFirst()
    }
    guard value.count <= size else {
      try fail("invalid_native_installation", "A public key integer is oversized")
    }
    return Data(repeating: 0, count: size - value.count) + value
  }

  private static func decodeAccountScalar(_ value: String) throws -> Data {
    guard value.hasPrefix("utsk1"), value == value.lowercased(), value.count <= 128 else {
      try fail("invalid_native_credential", "The account secret key is invalid")
    }
    let alphabet = Array("qpzry9x8gf2tvdw0s3jn54khce6mua7l")
    let encoded = value.dropFirst(5)
    var words = [Int]()
    for character in encoded {
      guard let digit = alphabet.firstIndex(of: character) else {
        try fail("invalid_native_credential", "The account secret key is invalid")
      }
      words.append(digit)
    }
    guard words.count >= 7, bech32Polymod(hrp: "utsk", data: words) == 0x2bc830a3 else {
      try fail("invalid_native_credential", "The account secret key checksum is invalid")
    }
    var accumulator = 0
    var bits = 0
    var output = Data()
    for digit in words.dropLast(6) {
      accumulator = ((accumulator & 0xfff) << 5) | digit
      bits += 5
      while bits >= 8 {
        bits -= 8
        output.append(UInt8((accumulator >> bits) & 0xff))
      }
    }
    guard bits < 5, ((accumulator << (8 - bits)) & 0xff) == 0, output.count == 32 else {
      try fail("invalid_native_credential", "The account secret key scalar is invalid")
    }
    return output
  }

  private static func bech32Polymod(hrp: String, data: [Int]) -> Int {
    let generators = [0x3b6a57b2, 0x26508e6d, 0x1ea119fa, 0x3d4233dd, 0x2a1462b3]
    var checksum = 1
    func step(_ value: Int) {
      let top = checksum >> 25
      checksum = ((checksum & 0x1ffffff) << 5) ^ value
      for index in generators.indices where ((top >> index) & 1) != 0 {
        checksum ^= generators[index]
      }
    }
    for scalar in hrp.unicodeScalars { step(Int(scalar.value) >> 5) }
    step(0)
    for scalar in hrp.unicodeScalars { step(Int(scalar.value) & 31) }
    data.forEach(step)
    return checksum
  }
}

struct DerReader {
  private let data: Data
  private var offset = 0

  init(_ data: Data) { self.data = data }
  var isAtEnd: Bool { offset == data.count }

  mutating func read(tag: UInt8) throws -> Data {
    guard offset < data.count, data[offset] == tag else {
      try NativeSessionProtocol.fail("invalid_native_installation", "Invalid DER tag")
    }
    offset += 1
    let length = try readLength()
    guard length >= 0, offset + length <= data.count else {
      try NativeSessionProtocol.fail("invalid_native_installation", "Truncated DER value")
    }
    defer { offset += length }
    return data.subdata(in: offset..<(offset + length))
  }

  private mutating func readLength() throws -> Int {
    guard offset < data.count else {
      try NativeSessionProtocol.fail("invalid_native_installation", "Truncated DER length")
    }
    let first = Int(data[offset])
    offset += 1
    if first < 0x80 { return first }
    let count = first & 0x7f
    guard count > 0, count <= 4, offset + count <= data.count else {
      try NativeSessionProtocol.fail("invalid_native_installation", "Invalid DER length")
    }
    var length = 0
    for _ in 0..<count {
      length = (length << 8) | Int(data[offset])
      offset += 1
    }
    guard length >= 0x80 else {
      try NativeSessionProtocol.fail("invalid_native_installation", "Non-canonical DER length")
    }
    return length
  }
}

extension Data {
  mutating func appendUInt16(_ value: UInt16) {
    append(UInt8((value >> 8) & 0xff)); append(UInt8(value & 0xff))
  }

  mutating func appendUInt32(_ value: UInt32) {
    append(UInt8((value >> 24) & 0xff)); append(UInt8((value >> 16) & 0xff))
    append(UInt8((value >> 8) & 0xff)); append(UInt8(value & 0xff))
  }

  mutating func appendUInt64(_ value: UInt64) {
    for shift in stride(from: 56, through: 0, by: -8) {
      append(UInt8((value >> UInt64(shift)) & 0xff))
    }
  }

  func uint32(at offset: Int) -> UInt32? {
    guard offset >= 0, offset + 4 <= count else { return nil }
    return self[offset..<(offset + 4)].reduce(0) { ($0 << 8) | UInt32($1) }
  }

  func uint64(at offset: Int) -> UInt64? {
    guard offset >= 0, offset + 8 <= count else { return nil }
    return self[offset..<(offset + 8)].reduce(0) { ($0 << 8) | UInt64($1) }
  }
}
