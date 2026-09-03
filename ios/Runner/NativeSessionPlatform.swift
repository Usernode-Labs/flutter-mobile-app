import Flutter
import Foundation
import Security
import UIKit
import WebKit

private enum IOSProducerWakeSource: UInt8 {
  case foregroundResume = 5
  case iosBackground = 6
}

private enum IOSProducerWakeDirective {
  case keep(revision: UInt64, applyRequired: Bool)
  case schedule(revision: UInt64, applyRequired: Bool)
  case cancel(revision: UInt64, terminateProcess: Bool, applyRequired: Bool)
  case retry(revision: UInt64, applyRequired: Bool)
  case install(revision: UInt64)

  var revision: UInt64 {
    switch self {
    case .keep(let value, _), .schedule(let value, _), .cancel(let value, _, _),
         .retry(let value, _), .install(let value): return value
    }
  }

  var applyRequired: Bool {
    switch self {
    case .keep(_, let value), .schedule(_, let value), .cancel(_, _, let value),
         .retry(_, let value): return value
    case .install: return false
    }
  }
}

struct IOSProducerWakeResult {
  let outcome: String
  let nativeRevision: UInt64?

  var flutterValue: [String: Any] {
    var result: [String: Any] = ["outcome": outcome]
    if let nativeRevision { result["nativeRevision"] = NSNumber(value: nativeRevision) }
    return result
  }
}

enum IOSNativeSessionRust {
  static func installProcessAuthority(directory: String) throws {
    let bytes = Data(directory.utf8)
    let status = bytes.withUnsafeBytes {
      usernode_mobile_install_process_authority_v1($0.bindMemory(to: UInt8.self).baseAddress, bytes.count)
    }
    try requireZero(status, "native_process_authority_failed")
  }

  static func issueProcessRootProof() throws -> Data {
    try output(capacity: 32, code: "process_root_proof_invalid") {
      usernode_mobile_issue_process_root_proof_v1($0, $1)
    }
  }

  static func revokeProcessRoot() { _ = usernode_mobile_revoke_process_root_v1() }

  static func stageInstalledCredential(_ frame: inout Data) throws -> Data {
    try mutableInputOutput(&frame, capacity: 32, code: "native_install_claim_invalid") {
      usernode_mobile_stage_installed_credential_v1($0, $1, $2, $3)
    }
  }

  static func stageColdInstalledCredential(_ frame: inout Data) throws -> Data {
    try mutableInputOutput(&frame, capacity: 32, code: "native_install_claim_invalid") {
      usernode_mobile_stage_cold_installed_credential_v1($0, $1, $2, $3)
    }
  }

  static func applyCredentialLease(_ frame: inout Data) throws {
    let length = frame.count
    let status = frame.withUnsafeBytes {
      usernode_mobile_apply_credential_lease_v1(
        $0.bindMemory(to: UInt8.self).baseAddress,
        length
      )
    }
    try requireZero(status, "native_credential_lease_update_failed")
  }

  static func resolveColdCredentialAbsent(expectedRevision: UInt64) throws -> UInt64 {
    var committed: UInt64 = 0
    let status = usernode_mobile_resolve_cold_credential_absent_v1(expectedRevision, &committed)
    try requireZero(status, "native_cold_absence_failed")
    return committed
  }

  static func stageProducerPolicy(_ frame: inout Data) throws -> Data {
    try inputOutput(frame, capacity: 32, code: "native_policy_claim_invalid") {
      usernode_mobile_stage_producer_policy_v1($0, $1, $2, $3)
    }
  }

  static func stageProducerWake(_ frame: inout Data) throws -> Data {
    try mutableInputOutput(&frame, capacity: 32, code: "native_producer_wake_failed") {
      usernode_mobile_stage_producer_wake_v1($0, $1, $2, $3)
    }
  }

  static func runProducerWakeClaim(_ claim: inout Data) throws -> Data {
    try mutableInputOutput(&claim, capacity: 160, code: "native_producer_wake_failed") {
      usernode_mobile_run_producer_wake_claim_v1($0, $1, $2, $3)
    }
  }

  static func resolveProducerCredentialAbsent(_ frame: inout Data) throws -> Data {
    try mutableInputOutput(&frame, capacity: 160, code: "native_producer_wake_failed") {
      usernode_mobile_resolve_producer_credential_absent_v1($0, $1, $2, $3)
    }
  }

  static func completeProducerWakeApply(_ response: Data, success: Bool) throws {
    let status = response.withUnsafeBytes {
      usernode_mobile_complete_producer_wake_apply_v1(
        $0.bindMemory(to: UInt8.self).baseAddress,
        response.count,
        success ? 1 : 0
      )
    }
    try requireZero(status, "native_producer_apply_rejected")
  }

  private static func output(
    capacity: Int,
    code: String,
    call: (UnsafeMutablePointer<UInt8>?, Int) -> Int32
  ) throws -> Data {
    var output = Data(count: capacity)
    let length = output.withUnsafeMutableBytes {
      call($0.bindMemory(to: UInt8.self).baseAddress, capacity)
    }
    guard length > 0, Int(length) <= capacity else {
      output.resetBytes(in: 0..<output.count)
      try NativeSessionProtocol.fail(code, "The private Rust operation failed")
    }
    output.count = Int(length)
    return output
  }

  private static func inputOutput(
    _ input: Data,
    capacity: Int,
    code: String,
    call: (UnsafePointer<UInt8>?, Int, UnsafeMutablePointer<UInt8>?, Int) -> Int32
  ) throws -> Data {
    try input.withUnsafeBytes { source in
      try output(capacity: capacity, code: code) { destination, size in
        call(source.bindMemory(to: UInt8.self).baseAddress, input.count, destination, size)
      }
    }
  }

  private static func mutableInputOutput(
    _ input: inout Data,
    capacity: Int,
    code: String,
    call: (UnsafeMutablePointer<UInt8>?, Int, UnsafeMutablePointer<UInt8>?, Int) -> Int32
  ) throws -> Data {
    let inputCount = input.count
    return try input.withUnsafeMutableBytes { source in
      try output(capacity: capacity, code: code) { destination, size in
        call(source.bindMemory(to: UInt8.self).baseAddress, inputCount, destination, size)
      }
    }
  }

  private static func requireZero(_ status: Int32, _ code: String) throws {
    guard status == 0 else {
      try NativeSessionProtocol.fail(code, "The private Rust operation failed")
    }
  }
}

/// Best-effort iOS callback owner. It deliberately does not invent an iOS
/// scheduler: unsupported Schedule/Retry effects are completed as failure.
final class IOSNativeProducerWakeCoordinator {
  static let shared = IOSNativeProducerWakeCoordinator()
  private let queue = DispatchQueue(label: "org.usernode.native-session.wake")
  private let vault = IOSNativeSessionVault.shared

  private init() {}

  func runInteractive(
    expectedRevision: UInt64,
    refreshPolicy: Bool,
    completion: @escaping (Result<IOSProducerWakeResult, Error>) -> Void
  ) {
    run(
      source: .foregroundResume,
      expectedRevision: expectedRevision,
      refreshPolicy: refreshPolicy,
      completion: completion
    )
  }

  func runBackground(completion: @escaping (IOSProducerWakeResult) -> Void) {
    guard let revision = vault.readyRevision() else {
      completion(IOSProducerWakeResult(outcome: "ignored", nativeRevision: nil))
      return
    }
    run(
      source: .iosBackground,
      expectedRevision: revision,
      refreshPolicy: true
    ) { result in
      completion((try? result.get()) ?? IOSProducerWakeResult(outcome: "retry", nativeRevision: nil))
    }
  }

  private func run(
    source: IOSProducerWakeSource,
    expectedRevision: UInt64,
    refreshPolicy: Bool,
    completion: @escaping (Result<IOSProducerWakeResult, Error>) -> Void
  ) {
    queue.async {
      do {
        completion(.success(try self.runLocked(
          source: source,
          expectedRevision: expectedRevision,
          refreshPolicy: refreshPolicy
        )))
      } catch {
        completion(.failure(error))
      }
    }
  }

  private func runLocked(
    source: IOSProducerWakeSource,
    expectedRevision: UInt64,
    refreshPolicy: Bool
  ) throws -> IOSProducerWakeResult {
    var coldClaim: Data?
    for attempt in 0...1 {
      let credential = vault.producerWakeCredential(
        refreshPolicy: refreshPolicy,
        coldInstallClaim: coldClaim
      )
      if case .uncertain = credential {
        return IOSProducerWakeResult(outcome: "retry", nativeRevision: nil)
      }
      var request = try encodeRequest(
        source: source,
        expectedRevision: expectedRevision,
        credential: credential
      )
      var response: Data
      switch credential {
      case .present:
        var claim = try IOSNativeSessionRust.stageProducerWake(&request)
        defer { claim.resetBytes(in: 0..<claim.count) }
        response = try IOSNativeSessionRust.runProducerWakeClaim(&claim)
      case .absent:
        response = try IOSNativeSessionRust.resolveProducerCredentialAbsent(&request)
      case .uncertain:
        return IOSProducerWakeResult(outcome: "retry", nativeRevision: nil)
      }
      defer { response.resetBytes(in: 0..<response.count) }
      let directive = try decodeDirective(response)
      if case .install = directive {
        guard attempt == 0 else {
          return IOSProducerWakeResult(outcome: "retry", nativeRevision: nil)
        }
        switch vault.stageBackgroundColdInstalledCredential() {
        case .present(let claim): coldClaim = claim
        case .absent: coldClaim = nil
        case .uncertain:
          return IOSProducerWakeResult(outcome: "retry", nativeRevision: nil)
        }
        continue
      }
      return try apply(
        directive,
        exactResponse: response,
        expectedRevision: expectedRevision,
        source: source
      )
    }
    return IOSProducerWakeResult(outcome: "retry", nativeRevision: nil)
  }

  private func apply(
    _ directive: IOSProducerWakeDirective,
    exactResponse: Data,
    expectedRevision: UInt64,
    source: IOSProducerWakeSource
  ) throws -> IOSProducerWakeResult {
    switch directive {
    case .cancel(let revision, let terminateProcess, let applyRequired):
      if applyRequired {
        guard revision == expectedRevision, !terminateProcess else {
          try IOSNativeSessionRust.completeProducerWakeApply(exactResponse, success: false)
          return IOSProducerWakeResult(outcome: "retry", nativeRevision: nil)
        }
        if let current = vault.readyRevision(), current != expectedRevision {
          try IOSNativeSessionRust.completeProducerWakeApply(exactResponse, success: false)
          return IOSProducerWakeResult(outcome: "retry", nativeRevision: nil)
        }
        // Delegation stops producer scheduling, not the retained native
        // session. Persist Ready before releasing Rust's apply claim so
        // managed session operations remain available after this boundary.
        vault.setReadyRevision(revision)
        try IOSNativeSessionRust.completeProducerWakeApply(exactResponse, success: true)
        return IOSProducerWakeResult(outcome: "completed", nativeRevision: nil)
      }
      if let current = vault.readyRevision(), current != expectedRevision {
        return IOSProducerWakeResult(outcome: "retry", nativeRevision: nil)
      }
      try vault.clearReadyRevision(expected: expectedRevision)
      // Approved iOS terminal behavior is inert signed-out. Rust has already
      // closed A; UIKit is not exited or crashed.
      return IOSProducerWakeResult(outcome: "retired", nativeRevision: revision)

    case .keep(let revision, let applyRequired):
      guard revision == expectedRevision, applyRequired else {
        if applyRequired {
          try? IOSNativeSessionRust.completeProducerWakeApply(exactResponse, success: false)
        }
        return IOSProducerWakeResult(outcome: "retry", nativeRevision: nil)
      }
      // Keeping an already-active runtime is the complete iOS effect.
      try IOSNativeSessionRust.completeProducerWakeApply(exactResponse, success: true)
      vault.setReadyRevision(revision)
      return IOSProducerWakeResult(outcome: "completed", nativeRevision: nil)

    case .schedule(let revision, let applyRequired), .retry(let revision, let applyRequired):
      guard revision == expectedRevision else {
        if applyRequired {
          try? IOSNativeSessionRust.completeProducerWakeApply(exactResponse, success: false)
        }
        return IOSProducerWakeResult(outcome: "retry", nativeRevision: nil)
      }
      // iOS provides no exact/retry scheduling guarantee. Report truthfully;
      // Rust keeps the foreground runtime active and releases the permit.
      if applyRequired {
        try IOSNativeSessionRust.completeProducerWakeApply(exactResponse, success: false)
      }
      vault.setReadyRevision(revision)
      // No iOS exact/retry scheduler is claimed. An interactive Ready remains
      // usable with Rust kept active; a noninteractive callback reports retry.
      return IOSProducerWakeResult(
        outcome: source == .foregroundResume ? "completed" : "retry",
        nativeRevision: nil
      )

    case .install:
      return IOSProducerWakeResult(outcome: "retry", nativeRevision: nil)
    }
  }

  private func encodeRequest(
    source: IOSProducerWakeSource,
    expectedRevision: UInt64,
    credential: IOSProducerWakeCredential
  ) throws -> Data {
    var frame = Data("UNPW".utf8)
    frame.append(1); frame.append(source.rawValue)
    switch credential {
    case .present: frame.append(1)
    case .absent: frame.append(2)
    case .uncertain: frame.append(3)
    }
    frame.appendUInt64(expectedRevision)
    frame.append(Data(repeating: 0, count: 32))
    frame.appendUInt32(0); frame.appendUInt64(0)
    switch credential {
    case .present(let evidence, let policy):
      guard evidence.count <= 0xffff, policy.count <= 0xffff else {
        try NativeSessionProtocol.fail(
          "invalid_native_wake", "The producer wake request is too large"
        )
      }
      frame.appendUInt16(UInt16(evidence.count)); frame.append(evidence)
      frame.appendUInt16(UInt16(policy.count)); frame.append(policy)
    case .absent, .uncertain:
      frame.appendUInt16(0); frame.appendUInt16(0)
    }
    guard frame.count <= 2048 else {
      try NativeSessionProtocol.fail(
        "invalid_native_wake", "The producer wake request is too large"
      )
    }
    return frame
  }

  private func decodeDirective(_ frame: Data) throws -> IOSProducerWakeDirective {
    guard frame.count >= 15, frame.count <= 109,
          frame.prefix(4) == Data("UNPR".utf8), frame[4] == 1,
          let revision = frame.uint64(at: 6) else {
      try NativeSessionProtocol.fail(
        "invalid_native_wake_response", "The producer wake response is invalid"
      )
    }
    let tag = frame[5]
    let fixedLength: Int
    let directive: IOSProducerWakeDirective
    switch tag {
    case 1:
      fixedLength = 19
      directive = .keep(revision: revision, applyRequired: false)
    case 2:
      guard frame.count >= 76, frame[14..<46].contains(where: { $0 != 0 }) else {
        try NativeSessionProtocol.fail(
          "invalid_native_wake_response", "The producer wake response is invalid"
        )
      }
      fixedLength = 76
      directive = .schedule(revision: revision, applyRequired: false)
    case 3:
      fixedLength = 16
      guard frame.count > 14, frame[14] <= 1 else {
        try NativeSessionProtocol.fail(
          "invalid_native_wake_response", "The producer wake response is invalid"
        )
      }
      directive = .cancel(
        revision: revision, terminateProcess: frame[14] == 1, applyRequired: false
      )
    case 4:
      fixedLength = 19
      directive = .retry(revision: revision, applyRequired: false)
    case 5:
      guard frame.count == 15, frame[14] == 0 else {
        try NativeSessionProtocol.fail(
          "invalid_native_wake_response", "The producer wake response is invalid"
        )
      }
      return .install(revision: revision)
    default:
      try NativeSessionProtocol.fail(
        "invalid_native_wake_response", "The producer wake response is invalid"
      )
    }
    guard frame.count > fixedLength else {
      try NativeSessionProtocol.fail(
        "invalid_native_wake_response", "The producer wake response is invalid"
      )
    }
    let required = frame[fixedLength]
    guard required <= 1,
          frame.count == fixedLength + 1 + (required == 1 ? 32 : 0),
          required == 0 || frame[(fixedLength + 1)...].contains(where: { $0 != 0 }) else {
      try NativeSessionProtocol.fail(
        "invalid_native_wake_response", "The producer wake response is invalid"
      )
    }
    switch directive {
    case .keep: return .keep(revision: revision, applyRequired: required == 1)
    case .schedule: return .schedule(revision: revision, applyRequired: required == 1)
    case .cancel(_, let terminate, _):
      return .cancel(revision: revision, terminateProcess: terminate, applyRequired: required == 1)
    case .retry: return .retry(revision: revision, applyRequired: required == 1)
    case .install: return directive
    }
  }
}

/// One private MethodChannel per current Flutter engine. The random transport
/// claim is injected by the Dart composition root and required on every
/// subsequent call; no bearer, key, or generic HTTP primitive is exposed.
final class IOSNativeSessionChannel {
  static let channelName = "com.usernode.app/native_session"

  private let channel: FlutterMethodChannel
  private let vault = IOSNativeSessionVault.shared
  private let worker = DispatchQueue(label: "org.usernode.native-session.interactive")
  private var proofIssued = false
  private var closed = false
  private var processTransportClaim = Data()

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: Self.channelName, binaryMessenger: messenger)
    processTransportClaim = (try? randomData(count: 32)) ?? Data()
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  func close() {
    guard !closed else { return }
    closed = true
    channel.setMethodCallHandler(nil)
    processTransportClaim.resetBytes(in: 0..<processTransportClaim.count)
    IOSNativeSessionRust.revokeProcessRoot()
  }

  func notifyRetired(nativeRevision: UInt64) {
    DispatchQueue.main.async { [weak self] in
      self?.channel.invokeMethod(
        "nativeSessionRetired",
        arguments: ["nativeRevision": NSNumber(value: nativeRevision)]
      )
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard !closed else {
      result(FlutterError(code: "stale_interactive_engine", message: "The Flutter engine no longer owns native session authority", details: nil))
      return
    }
    do {
      switch call.method {
      case "bootstrapInteractiveRoot": try bootstrap(call, result)
      case "redeemNativeSessionHandoff": try redeemHandoff(call, result)
      case "prepareNativeSessionExchange": try prepare(call, result)
      case "installNativeSessionCredential": try install(call, result)
      case "discardUncommittedNativeSessionCredential": try discardUncommitted(call, result)
      case "clearOrphanedNativeSessionState": try clearOrphaned(call, result)
      case "retireNativeSessionCredential": try retire(call, result)
      case "revokeNativeSessionCredential": try revoke(call, result)
      case "recoverNativeSession": try recover(call, result)
      case "runInteractiveProducerWake": try runInteractive(call, result)
      case "stageNativeProducerPolicy": try stagePolicy(call, result)
      case "getNativePushStatus": try getPush(call, result)
      case "registerNativePush": try registerPush(call, result)
      case "unregisterNativePush": try unregisterPush(call, result)
      case "resolveNativeZkPassportChallenge": try resolveZk(call, result)
      case "completeNativeZkPassport": try completeZk(call, result)
      default: result(FlutterMethodNotImplemented)
      }
    } catch { finish(result, value: nil, error: error) }
  }

  private func bootstrap(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) throws {
    let arguments = try exactArguments(call.arguments, keys: ["mobileApiBaseUrl"], label: call.method)
    guard !proofIssued, processTransportClaim.count == 32,
          let baseUrl = arguments["mobileApiBaseUrl"] as? String else {
      try NativeSessionProtocol.fail(
        "process_root_proof_already_issued", "The process-root proof was already issued"
      )
    }
    guard UIApplication.shared.applicationState == .active,
          UIApplication.shared.isProtectedDataAvailable else {
      try NativeSessionProtocol.fail(
        "native_interactive_bootstrap_unavailable",
        "Interactive protected data is unavailable"
      )
    }
    let support = try FileManager.default.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    ).appendingPathComponent("native_session_v2", isDirectory: true)
    try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
    var values = URLResourceValues(); values.isExcludedFromBackup = true
    var mutableSupport = support; try mutableSupport.setResourceValues(values)
    try IOSNativeSessionRust.installProcessAuthority(directory: support.path)
    try vault.configureMobileApiBaseUrl(baseUrl)
    let proof = try IOSNativeSessionRust.issueProcessRootProof()
    guard proof.count == 32 else {
      try NativeSessionProtocol.fail("process_root_proof_invalid", "Rust returned an invalid process-root proof")
    }
    proofIssued = true
    result([
      "processRootProof": FlutterStandardTypedData(bytes: proof),
      "processTransportClaim": FlutterStandardTypedData(bytes: processTransportClaim),
    ])
  }

  private func prepare(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) throws {
    let arguments = try authorized(call, keys: ["nativeEstablishTicket", "processTransportClaim"])
    result(try vault.prepareExchange(arguments["nativeEstablishTicket"]))
  }

  private func redeemHandoff(
    _ call: FlutterMethodCall,
    _ result: @escaping FlutterResult
  ) throws {
    let arguments = try authorized(
      call, keys: ["attemptId", "processTransportClaim"]
    )
    guard let attemptId = arguments["attemptId"] as? String else {
      try NativeSessionProtocol.fail(
        "native_establish_request_invalid", "The native attempt id is invalid"
      )
    }
    WKWebsiteDataStore.default().httpCookieStore.getAllCookies { [weak self] cookies in
      guard let self else {
        result(FlutterError(
          code: "stale_interactive_engine",
          message: "The Flutter engine no longer owns native session authority",
          details: nil
        ))
        return
      }
      self.worker.async {
        do {
          self.finish(
            result,
            value: try self.vault.redeemHandoff(
              attemptId: attemptId, cookies: cookies
            ),
            error: nil
          )
        } catch {
          self.finish(result, value: nil, error: error)
        }
      }
    }
  }

  private func install(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) throws {
    let arguments = try authorized(
      call, keys: ["nativeEstablishTicket", "exchange", "processTransportClaim"]
    )
    let claim = try vault.installCredential(
      ticket: arguments["nativeEstablishTicket"], exchange: arguments["exchange"]
    )
    result(["installClaim": FlutterStandardTypedData(bytes: claim)])
  }

  private func discardUncommitted(
    _ call: FlutterMethodCall,
    _ result: @escaping FlutterResult
  ) throws {
    let arguments = try authorized(
      call, keys: ["attemptId", "processTransportClaim"]
    )
    guard let attemptId = arguments["attemptId"] as? String else {
      try NativeSessionProtocol.fail(
        "invalid_native_establishment_cleanup", "The native attempt id is invalid"
      )
    }
    try vault.discardUncommittedCredential(attemptId: attemptId)
    result(nil)
  }

  private func clearOrphaned(
    _ call: FlutterMethodCall,
    _ result: @escaping FlutterResult
  ) throws {
    _ = try authorized(call, keys: ["processTransportClaim"])
    try vault.clearOrphanedSessionState()
    result(nil)
  }

  private func revoke(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) throws {
    // Terminal intent may already have cleared the producer Ready selector.
    // The private process-root transport claim is the authority for teardown.
    let arguments = try authorized(
      call, keys: ["expectedRevision", "processTransportClaim"]
    )
    _ = try NativeSessionProtocol.exactUInt64(
      arguments["expectedRevision"], "expected revision"
    )
    work(result) {
      let status: String
      switch self.vault.revokeCredentialOnServer() {
      case .definitivelyAbsent: status = "definitivelyAbsent"
      case .uncertain: status = "uncertain"
      }
      return ["status": status]
    }
  }

  private func retire(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) throws {
    let arguments = try authorized(
      call,
      keys: [
        "credentialReference", "credentialGeneration", "vaultCommitment",
        "readyRevision", "processTransportClaim",
      ]
    )
    guard let reference = arguments["credentialReference"] as? String,
          let commitment = typedData(arguments["vaultCommitment"]) else {
      try NativeSessionProtocol.fail("invalid_native_retirement", "The native retirement directive is invalid")
    }
    try vault.retireCredential(
      reference: reference,
      generation: try NativeSessionProtocol.exactUInt64(arguments["credentialGeneration"], "credential generation"),
      commitment: commitment,
      readyRevision: try NativeSessionProtocol.exactUInt64(arguments["readyRevision"], "ready revision")
    )
    result(nil)
  }

  private func recover(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) throws {
    let arguments = try authorized(call, keys: ["expectedRevision", "processTransportClaim"])
    let revision = try NativeSessionProtocol.exactUInt64(arguments["expectedRevision"], "expected revision")
    work(result) {
      switch self.vault.stageColdInstalledCredential() {
      case .present(let claim):
        return ["status": "present", "installClaim": FlutterStandardTypedData(bytes: claim)]
      case .absent:
        return [
          "status": "absent",
          "nativeRevision": NSNumber(value: try IOSNativeSessionRust.resolveColdCredentialAbsent(expectedRevision: revision)),
        ]
      case .uncertain: return ["status": "uncertain"]
      }
    }
  }

  private func runInteractive(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) throws {
    let arguments = try authorized(
      call, keys: ["expectedRevision", "refreshPolicy", "processTransportClaim"]
    )
    let revision = try NativeSessionProtocol.exactUInt64(arguments["expectedRevision"], "expected revision")
    guard let refresh = arguments["refreshPolicy"] as? Bool else {
      try NativeSessionProtocol.fail("invalid_native_wake", "The native wake request is invalid")
    }
    // Rust is already durably Ready when this port is called. Persist only its
    // non-secret revision so a later best-effort iOS fetch can present exact evidence.
    vault.setReadyRevision(revision)
    IOSNativeProducerWakeCoordinator.shared.runInteractive(
      expectedRevision: revision,
      refreshPolicy: refresh
    ) { [weak self] wake in
      switch wake {
      case .success(let value):
        if value.outcome == "retired", let retired = value.nativeRevision {
          self?.notifyRetired(nativeRevision: retired)
        }
        self?.finish(result, value: value.flutterValue, error: nil)
      case .failure(let error): self?.finish(result, value: nil, error: error)
      }
    }
  }

  private func stagePolicy(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) throws {
    let arguments = try managed(
      call, keys: ["delegated", "expectedRevision", "processTransportClaim"]
    )
    guard arguments["delegated"] == nil || arguments["delegated"] is Bool else {
      try NativeSessionProtocol.fail("invalid_native_policy_request", "The producer policy request is invalid")
    }
    work(result) {
      ["installClaim": FlutterStandardTypedData(
        bytes: try self.vault.stageProducerPolicy(delegated: arguments["delegated"] as? Bool)
      )]
    }
  }

  private func getPush(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) throws {
    let arguments = try managed(
      call, keys: ["installationId", "expectedRevision", "processTransportClaim"]
    )
    guard let installationId = arguments["installationId"] as? String else {
      try NativeSessionProtocol.fail("invalid_native_push_request", "The push status request is invalid")
    }
    work(result) { try self.vault.getPushStatus(installationId: installationId) }
  }

  private func registerPush(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) throws {
    let arguments = try managed(
      call,
      keys: [
        "installationId", "providerToken", "platform", "permissionStatus",
        "mutationRevision", "expectedRevision", "processTransportClaim",
      ]
    )
    work(result) {
      guard let installation = arguments["installationId"] as? String,
            let token = arguments["providerToken"] as? String,
            let platform = arguments["platform"] as? String,
            let permission = arguments["permissionStatus"] as? String else {
        try NativeSessionProtocol.fail("invalid_native_push_request", "The push registration request is invalid")
      }
      return try self.vault.registerPush(
        installationId: installation,
        providerToken: token,
        platform: platform,
        permissionStatus: permission,
        mutationRevision: try NativeSessionProtocol.exactUInt64(arguments["mutationRevision"], "mutation revision")
      )
    }
  }

  private func unregisterPush(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) throws {
    let arguments = try managed(
      call,
      keys: [
        "installationId", "mutationRevision", "reason", "expectedRevision",
        "processTransportClaim",
      ]
    )
    work(result) {
      guard let installation = arguments["installationId"] as? String,
            let reason = arguments["reason"] as? String else {
        try NativeSessionProtocol.fail("invalid_native_push_request", "The push unregistration request is invalid")
      }
      return try self.vault.unregisterPush(
        installationId: installation,
        mutationRevision: try NativeSessionProtocol.exactUInt64(arguments["mutationRevision"], "mutation revision"),
        reason: reason
      )
    }
  }

  private func resolveZk(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) throws {
    _ = try managed(call, keys: ["expectedRevision", "processTransportClaim"])
    work(result) { ["challengeId": try self.vault.resolveLegacyZkPassportChallengeId()] }
  }

  private func completeZk(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) throws {
    let arguments = try managed(
      call,
      keys: [
        "challengeId", "sessionId", "nullifierHex", "completedAt", "expectedRevision",
        "processTransportClaim",
      ]
    )
    work(result) {
      guard let sessionId = arguments["sessionId"] as? String,
            let nullifier = arguments["nullifierHex"] as? String,
            arguments["completedAt"] == nil || arguments["completedAt"] is String else {
        try NativeSessionProtocol.fail("invalid_native_zk_completion", "The zkPassport completion is invalid")
      }
      return try self.vault.completeLegacyZkPassport(
        challengeId: try NativeSessionProtocol.exactInt(arguments["challengeId"], "challenge id"),
        sessionId: sessionId,
        nullifierHex: nullifier,
        completedAt: arguments["completedAt"] as? String
      )
    }
  }

  private func authorized(_ call: FlutterMethodCall, keys: Set<String>) throws -> [String: Any] {
    guard proofIssued else {
      try NativeSessionProtocol.fail("process_root_unavailable", "The interactive process root is unavailable")
    }
    let arguments = try exactArguments(call.arguments, keys: keys, label: call.method)
    guard let presented = typedData(arguments["processTransportClaim"]),
          presented.count == processTransportClaim.count,
          constantTimeEqual(presented, processTransportClaim) else {
      try NativeSessionProtocol.fail("process_transport_claim_invalid", "The process transport claim is invalid")
    }
    return arguments
  }

  private func managed(_ call: FlutterMethodCall, keys: Set<String>) throws -> [String: Any] {
    let arguments = try authorized(call, keys: keys)
    let revision = try NativeSessionProtocol.exactUInt64(arguments["expectedRevision"], "expected revision")
    guard vault.isReadyRevision(revision) else {
      try NativeSessionProtocol.fail("native_session_not_current", "The native session is not current")
    }
    return arguments
  }

  private func exactArguments(_ raw: Any?, keys: Set<String>, label: String) throws -> [String: Any] {
    guard let arguments = raw as? [String: Any], Set(arguments.keys) == keys else {
      try NativeSessionProtocol.fail("invalid_native_session_arguments", "\(label) arguments are invalid")
    }
    return arguments
  }

  private func work(_ result: @escaping FlutterResult, body: @escaping () throws -> Any?) {
    worker.async {
      do { self.finish(result, value: try body(), error: nil) }
      catch { self.finish(result, value: nil, error: error) }
    }
  }

  private func finish(_ result: @escaping FlutterResult, value: Any?, error: Error?) {
    DispatchQueue.main.async {
      if let error = error as? NativeSessionProtocolError {
        result(FlutterError(code: error.code, message: error.message, details: nil))
      } else if let error = error as? IOSNativeManagedHTTPError {
        result(FlutterError(
          code: "native_managed_http_error",
          message: "The native managed request failed",
          details: [
            "statusCode": error.statusCode,
            "code": error.errorCode as Any,
            "latestMutationRevision": error.latestMutationRevision.map(NSNumber.init(value:)) as Any,
          ]
        ))
      } else if error != nil {
        result(FlutterError(code: "native_session_unavailable", message: "The native session operation could not be completed", details: nil))
      } else {
        result(value)
      }
    }
  }

  private func typedData(_ raw: Any?) -> Data? {
    (raw as? FlutterStandardTypedData)?.data ?? raw as? Data
  }

  private func constantTimeEqual(_ left: Data, _ right: Data) -> Bool {
    guard left.count == right.count else { return false }
    return zip(left, right).reduce(UInt8(0)) { $0 | ($1.0 ^ $1.1) } == 0
  }

  private func randomData(count: Int) throws -> Data {
    var data = Data(count: count)
    let status = data.withUnsafeMutableBytes {
      SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!)
    }
    guard status == errSecSuccess else {
      try NativeSessionProtocol.fail("native_random_unavailable", "Secure random data is unavailable")
    }
    return data
  }
}
