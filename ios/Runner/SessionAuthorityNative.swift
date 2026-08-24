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
