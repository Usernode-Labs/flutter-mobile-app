import Flutter
import Foundation
import WidgetKit

/// Native side of the `com.usernode.app/home_shortcuts` MethodChannel on iOS.
///
/// iOS cannot pin homescreen shortcuts programmatically, so instead the
/// pinned-dapps registry is mirrored into the App Group container consumed
/// by the `UsernodeWidgets` WidgetKit extension: a JSON list in the shared
/// UserDefaults plus one PNG per dapp in `pinned_icons/`.
class HomeShortcutsChannel {
  static let channelName = "com.usernode.app/home_shortcuts"
  static let appGroupId = "group.org.usernode.app"
  static let pinnedDappsKey = "pinned_dapps"

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "syncPinnedDapps":
      syncPinnedDapps(call, result: result)
    case "saveWidgetIcon":
      saveWidgetIcon(call, result: result)
    case "deleteWidgetIcon":
      deleteWidgetIcon(call, result: result)
    case "listWidgetIconIds":
      listWidgetIconIds(result: result)
    case "isWidgetInstalled":
      isWidgetInstalled(result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func syncPinnedDapps(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let json = args["json"] as? String else {
      result(FlutterError(code: "invalid_args", message: "json is required", details: nil))
      return
    }
    guard let defaults = UserDefaults(suiteName: HomeShortcutsChannel.appGroupId) else {
      print("[HomeShortcuts] App Group \(HomeShortcutsChannel.appGroupId) unavailable")
      result(false)
      return
    }
    defaults.set(json, forKey: HomeShortcutsChannel.pinnedDappsKey)
    WidgetCenter.shared.reloadAllTimelines()
    result(true)
  }

  private func saveWidgetIcon(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let id = args["id"] as? String,
          let bytes = args["bytes"] as? FlutterStandardTypedData else {
      result(FlutterError(code: "invalid_args", message: "id and bytes are required", details: nil))
      return
    }
    // Ids are hex digests; reject anything else so the id can't traverse paths.
    guard id.range(of: "^[a-f0-9]+$", options: .regularExpression) != nil else {
      result(FlutterError(code: "invalid_args", message: "id must be a hex digest", details: nil))
      return
    }
    let dark = (args["dark"] as? Bool) ?? false
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: HomeShortcutsChannel.appGroupId
    ) else {
      print("[HomeShortcuts] App Group container unavailable")
      result(false)
      return
    }

    let iconsDir = container.appendingPathComponent(ShortcutIconFile.directoryName, isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: iconsDir, withIntermediateDirectories: true)
      try bytes.data.write(
        to: iconsDir.appendingPathComponent(ShortcutIconFile.name(id: id, dark: dark)),
        options: .atomic
      )
      result(true)
    } catch {
      print("[HomeShortcuts] Failed to save icon: \(error)")
      result(false)
    }
  }

  /// Without `dark`, removes BOTH appearance assets (the unpin path — an
  /// entry leaving the registry must not leak either PNG, or a later re-pin
  /// of the same URL would resurrect a stale image). With `dark: true`,
  /// removes only the dark slot: a re-add without `icon_url_dark` reverts
  /// the entry to single-asset while the light PNG stays untouched.
  private func deleteWidgetIcon(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let id = args["id"] as? String else {
      result(FlutterError(code: "invalid_args", message: "id is required", details: nil))
      return
    }
    // Ids are hex digests; reject anything else so the id can't traverse paths.
    guard id.range(of: "^[a-f0-9]+$", options: .regularExpression) != nil else {
      result(FlutterError(code: "invalid_args", message: "id must be a hex digest", details: nil))
      return
    }
    let darkOnly = (args["dark"] as? Bool) ?? false
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: HomeShortcutsChannel.appGroupId
    ) else {
      print("[HomeShortcuts] App Group container unavailable")
      result(false)
      return
    }
    let iconsDir = container.appendingPathComponent(ShortcutIconFile.directoryName, isDirectory: true)
    let fileNames = darkOnly
      ? [ShortcutIconFile.name(id: id, dark: true)]
      : [ShortcutIconFile.name(id: id, dark: false), ShortcutIconFile.name(id: id, dark: true)]
    do {
      for fileName in fileNames {
        let iconURL = iconsDir.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: iconURL.path) {
          try FileManager.default.removeItem(at: iconURL)
        }
      }
      result(true)
    } catch {
      print("[HomeShortcuts] Failed to delete icon: \(error)")
      result(false)
    }
  }

  /// Filename stems (minus .png) present in the App Group icon store.
  /// Light assets yield the bare id, dark assets yield `<id>.dark`; the
  /// Flutter side splits the two and surfaces them as `has_icon` /
  /// `has_icon_dark` on the registry snapshot so the dapps home can
  /// re-send icons that never landed.
  private func listWidgetIconIds(result: @escaping FlutterResult) {
    guard let container = FileManager.default.containerURL(
      forSecurityApplicationGroupIdentifier: HomeShortcutsChannel.appGroupId
    ) else {
      result([String]())
      return
    }
    let iconsDir = container.appendingPathComponent(ShortcutIconFile.directoryName, isDirectory: true)
    let files = (try? FileManager.default.contentsOfDirectory(atPath: iconsDir.path)) ?? []
    result(files.filter { $0.hasSuffix(".png") }.map { String($0.dropLast(4)) })
  }

  private func isWidgetInstalled(result: @escaping FlutterResult) {
    WidgetCenter.shared.getCurrentConfigurations { configurations in
      let installed: Bool
      switch configurations {
      case .success(let infos):
        installed = !infos.isEmpty
      case .failure(let error):
        print("[HomeShortcuts] getCurrentConfigurations failed: \(error)")
        installed = false
      }
      DispatchQueue.main.async {
        result(installed)
      }
    }
  }
}
