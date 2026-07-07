import Foundation
import SwiftUI

#if canImport(AppIntents)
import AppIntents

/// Per-icon launch for the small (2x2) homescreen widget. Small widgets
/// ignore `Link` (single widgetURL only), so individual tap targets need
/// an intent button.
///
/// IMPORTANT: this file is compiled into BOTH the Runner app target and
/// the UsernodeWidgets extension target. `openAppWhenRun = true` makes
/// the system execute the intent in the app's process — if the type only
/// exists in the widget extension, the tap silently does nothing.
@available(iOS 18.0, *)
struct OpenPinnedDappIntent: AppIntent {
  static var title: LocalizedStringResource = "Open pinned dApp"
  static var isDiscoverable: Bool = false
  static var openAppWhenRun: Bool = true

  @Parameter(title: "Deep link")
  var deepLink: String

  init() {}
  init(deepLink: String) { self.deepLink = deepLink }

  @MainActor
  func perform() async throws -> some IntentResult & OpensIntent {
    let url = URL(string: deepLink) ?? URL(string: "usernode://app")!
    // OpenURLIntent only officially supports universal links — handing it
    // a custom usernode:// URL silently does nothing. The documented
    // workaround is to fire the URL through EnvironmentValues().openURL
    // (running in the app process thanks to openAppWhenRun), returning
    // the OpenURLIntent as well for the universal-link case.
    EnvironmentValues().openURL(url)
    return .result(opensIntent: OpenURLIntent(url))
  }
}
#endif
