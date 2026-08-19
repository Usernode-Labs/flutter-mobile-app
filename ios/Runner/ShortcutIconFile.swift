import Foundation

/// Cross-target naming contract for PNGs in the pinned shortcut icon store.
/// IDs are validated as hex digests by the Runner before this helper is used.
enum ShortcutIconFile {
  static let directoryName = "pinned_icons"

  static func name(id: String, dark: Bool) -> String {
    dark ? "\(id).dark.png" : "\(id).png"
  }
}
