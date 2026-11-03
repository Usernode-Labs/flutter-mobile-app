import Flutter
import UIKit

/// Native side of the `com.onhomeroom.app/orientation` MethodChannel on iOS.
///
/// `OrientationPolicy` (lib/core/bootstrap/orientation_policy.dart) lets the
/// app turn once it is on a large screen, such as iPhone Duo's inner display.
/// Flutter hands the new list to UIKit once, and only when the list changes.
/// When that lands while the scene is still moving from the cover to the inner
/// display, UIKit keeps the portrait mask it read before and does not read it
/// again until the app comes back from the background: unfolded, the app
/// stayed portrait until a trip home (flutter-mobile-app#635). `refresh` asks
/// UIKit to read it again, once the policy has seen the screen settle.
class OrientationChannel {
  static let channelName = "com.onhomeroom.app/orientation"

  private var activationObserver: NSObjectProtocol?

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "refresh":
      refresh()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Re-reads the orientations on every active scene now, and on any other
  /// scene when it next becomes active.
  private func refresh() {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    var waiting = false
    for scene in scenes {
      if scene.activationState == .foregroundActive {
        reread(scene)
      } else {
        waiting = true
      }
    }
    if waiting {
      refreshOnNextActivation()
    }
  }

  private func refreshOnNextActivation() {
    guard activationObserver == nil else { return }
    activationObserver = NotificationCenter.default.addObserver(
      forName: UIScene.didActivateNotification,
      object: nil,
      queue: .main
    ) { [weak self] notification in
      guard let self else { return }
      if let observer = self.activationObserver {
        NotificationCenter.default.removeObserver(observer)
      }
      self.activationObserver = nil
      if let scene = notification.object as? UIWindowScene {
        self.reread(scene)
      }
    }
  }

  /// The same two calls Flutter makes when the list changes, made again.
  private func reread(_ scene: UIWindowScene) {
    guard let root = scene.keyWindow?.rootViewController ??
      scene.windows.first?.rootViewController else { return }
    guard #available(iOS 16.0, *) else {
      UIViewController.attemptRotationToDeviceOrientation()
      return
    }
    let orientations = root.supportedInterfaceOrientations
    print("[Orientation] Re-reading supported orientations: \(orientations.rawValue)")
    root.setNeedsUpdateOfSupportedInterfaceOrientations()
    let preferences = UIWindowScene.GeometryPreferences.iOS(
      interfaceOrientations: orientations
    )
    scene.requestGeometryUpdate(preferences) { error in
      print("[Orientation] Geometry update refused: \(error.localizedDescription)")
    }
  }
}
