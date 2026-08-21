import Foundation

/// Thin, read-only iOS client for the Rust-owned process authority.
enum SessionAuthorityNative {
  private static let directoryName = "session-authority"

  static func admissionJSON() -> String {
    guard let directory = journalDirectory() else {
      return #"{"status":"terminal","reason":"Application Support unavailable"}"#
    }
    let value = directory.path.withCString {
      usernode_session_authority_admission_json($0)
    }
    guard let value else {
      return #"{"status":"terminal","reason":"Rust authority returned no value"}"#
    }
    defer { usernode_session_authority_string_free(value) }
    return String(cString: value)
  }

  static func isBackgroundRuntimeAdmitted(
    sessionID: String,
    runtimeGeneration: UInt64
  ) -> Bool {
    guard let directory = journalDirectory(),
          !sessionID.isEmpty,
          runtimeGeneration > 0 else {
      return false
    }
    return directory.path.withCString { directoryPointer in
      sessionID.withCString { sessionPointer in
        usernode_session_authority_admits_background_runtime(
          directoryPointer,
          sessionPointer,
          runtimeGeneration
        )
      }
    }
  }

  private static func journalDirectory() -> URL? {
    try? FileManager.default
      .url(
        for: .applicationSupportDirectory,
        in: .userDomainMask,
        appropriateFor: nil,
        create: false
      )
      .appendingPathComponent(directoryName, isDirectory: true)
  }
}
