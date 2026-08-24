import UIKit
import Flutter
import BackgroundTasks
import UserNotifications
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private static let socialNotificationSource = "usernode_social"
  private static let socialNotificationCategory = "USERNODE_SOCIAL"
  private let alarmChannelName = "com.usernode.app/alarm"
  private let screenshotChannelName = "com.usernode.app/screenshot"
  private var alarmChannel: FlutterMethodChannel?
  private var screenshotChannel: FlutterMethodChannel?
  private let homeShortcutsChannel = HomeShortcutsChannel()
  private var transientBackgroundTask: UIBackgroundTaskIdentifier = .invalid

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    print("[AppDelegate] ✓ Application launching - iOS \(UIDevice.current.systemVersion), Device: \(UIDevice.current.model)")
    print("[AppDelegate] Launch options: \(launchOptions?.keys.map { $0.rawValue } ?? [])")

    // Set notification center delegate to receive notification events
    UNUserNotificationCenter.current().delegate = self
    registerSocialNotificationCategory()
    print("[AppDelegate] UNUserNotificationCenter delegate set")

    GeneratedPluginRegistrant.register(with: self)
    print("[AppDelegate] Plugin registrant registered")

    // Setup method channel for alarm service
    // Use safe unwrapping instead of accessing rootViewController directly (Flutter deprecation fix)
    if let flutterViewController = window?.rootViewController as? FlutterViewController {
      print("[AppDelegate] FlutterViewController found, setting up method channel")
      alarmChannel = FlutterMethodChannel(
        name: alarmChannelName,
        binaryMessenger: flutterViewController.binaryMessenger
      )
      setupMethodChannelHandlers()
      print("[AppDelegate] Method channel '\(alarmChannelName)' configured")

      let shortcutsChannel = FlutterMethodChannel(
        name: HomeShortcutsChannel.channelName,
        binaryMessenger: flutterViewController.binaryMessenger
      )
      shortcutsChannel.setMethodCallHandler { [weak self] (call, result) in
        self?.homeShortcutsChannel.handle(call, result: result)
      }
      print("[AppDelegate] Method channel '\(HomeShortcutsChannel.channelName)' configured")

      screenshotChannel = FlutterMethodChannel(
        name: screenshotChannelName,
        binaryMessenger: flutterViewController.binaryMessenger
      )
      screenshotChannel?.setMethodCallHandler { [weak self] (call, result) in
        guard call.method == "capture" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.captureCurrentScreen(result: result)
      }
      print("[AppDelegate] Method channel '\(screenshotChannelName)' configured")
    } else {
      print("[AppDelegate] ⚠ Warning - Could not access FlutterViewController")
    }

    // Check notification permissions on launch
    checkAndNotifyNotificationPermissionStatus()

    print("[AppDelegate] Calling super.application(didFinishLaunchingWithOptions:)")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    print("[AppDelegate] openURL received: \(url.absoluteString)")
    let handled = super.application(app, open: url, options: options)
    print("[AppDelegate] openURL handled by Flutter/plugins: \(handled)")
    return handled
  }

  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    let webpage = userActivity.webpageURL?.absoluteString ?? "<none>"
    print("[AppDelegate] continueUserActivity type=\(userActivity.activityType) url=\(webpage)")
    let handled = super.application(
      application,
      continue: userActivity,
      restorationHandler: restorationHandler
    )
    print("[AppDelegate] continueUserActivity handled by Flutter/plugins: \(handled)")
    return handled
  }

  // Check and notify current notification permission status
  private func registerSocialNotificationCategory() {
    let center = UNUserNotificationCenter.current()
    center.getNotificationCategories { categories in
      var updated = categories
      updated.insert(
        UNNotificationCategory(
          identifier: AppDelegate.socialNotificationCategory,
          actions: [],
          intentIdentifiers: [],
          options: []
        )
      )
      center.setNotificationCategories(updated)
    }
  }

  private func isSocialNotification(_ content: UNNotificationContent) -> Bool {
    let source = content.userInfo["source"] as? String
    return source == AppDelegate.socialNotificationSource ||
      content.categoryIdentifier == AppDelegate.socialNotificationCategory
  }

  private func checkAndNotifyNotificationPermissionStatus() {
    print("[AppDelegate] Checking notification permission status...")
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        print("[AppDelegate] Notification authorization status: \(settings.authorizationStatus.rawValue)")
        if settings.authorizationStatus == .authorized {
          print("[AppDelegate] Sending ios_notification_permission_granted event (already authorized)")
          DispatchQueue.main.async {
            self.sendEventToFlutter(eventType: "ios_notification_permission_granted", eventData: [:])
          }
        } else if settings.authorizationStatus == .denied {
          print("[AppDelegate] Sending ios_notification_permission_denied event (denied)")
          DispatchQueue.main.async {
            self.sendEventToFlutter(eventType: "ios_notification_permission_denied", eventData: [:])
          }
        }
        // For .notDetermined status, we don't send an event - wait for explicit request
      }
    }
  }

  private func setupMethodChannelHandlers() {
    alarmChannel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handleMethodCall(call, result: result)
    }
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("[AppDelegate] Method channel call received: \(call.method)")

    switch call.method {
    case "clearSessionNotifications":
      clearSessionNotifications(result: result)

    case "clearWebSessionData":
      clearWebSessionData(result: result)

    case "clearLegacySessionAuthority":
      result(clearLegacySessionAuthority())

    case "clearNativeResetState":
      result(clearNativeResetState())

    case "enterTerminalReset":
      // iOS does not expose a supported self-termination API. Dart has already
      // replaced the functional app with the inert reset-complete surface.
      result(nil)

    case "requestNotificationPermission":
      print("[AppDelegate] requestNotificationPermission called")
      requestNotificationPermission(result: result)

    case "hasNotificationPermission":
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        DispatchQueue.main.async {
          result(settings.authorizationStatus == .authorized ||
                 settings.authorizationStatus == .provisional)
        }
      }

    case "openNotificationSettings":
      DispatchQueue.main.async {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else {
          result(false)
          return
        }
        UIApplication.shared.open(url) { opened in
          result(opened)
        }
      }

    case "beginTransientBackgroundTask":
      print("[AppDelegate] beginTransientBackgroundTask called")
      beginTransientBackgroundTask(result: result)

    case "endTransientBackgroundTask":
      print("[AppDelegate] endTransientBackgroundTask called")
      endTransientBackgroundTask()
      result(true)

    default:
      print("[AppDelegate] ⚠ Unknown method: \(call.method)")
      result(FlutterMethodNotImplemented)
    }
  }

  /// Removes this app's delivered notifications and the pending requests
  /// behind them. A scoped sign-out keeps the process, so nothing else takes
  /// the retired session's Social/slot text off the lock screen.
  private func clearSessionNotifications(result: @escaping FlutterResult) {
    let center = UNUserNotificationCenter.current()
    center.removeAllPendingNotificationRequests()
    center.removeAllDeliveredNotifications()
    // Removing the delivered notifications does not clear the badge they
    // raised, so the retired session's unread count would survive on the
    // home screen.
    if #available(iOS 16.0, *) {
      center.setBadgeCount(0)
    } else {
      DispatchQueue.main.async {
        UIApplication.shared.applicationIconBadgeNumber = 0
      }
    }
    result(true)
  }

  private func clearWebSessionData(result: @escaping FlutterResult) {
    let dataStore = WKWebsiteDataStore.default()
    dataStore.removeData(
      ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
      modifiedSince: .distantPast
    ) {
      DispatchQueue.main.async {
        result(true)
      }
    }
  }

  /// Captures the visible app window after the feedback dialog has hidden.
  private func captureCurrentScreen(result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self, let window = self.window, !window.bounds.isEmpty else {
        result(FlutterError(
          code: "capture_unavailable",
          message: "The app window is not ready.",
          details: nil
        ))
        return
      }

      let format = UIGraphicsImageRendererFormat.default()
      format.opaque = true
      let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
      let image = renderer.image { context in
        if !window.drawHierarchy(in: window.bounds, afterScreenUpdates: true) {
          window.layer.render(in: context.cgContext)
        }
      }

      guard let data = self.encodeScreenshot(image) else {
        result(FlutterError(
          code: "capture_too_large",
          message: "The screenshot is larger than 4 MB.",
          details: nil
        ))
        return
      }
      result(FlutterStandardTypedData(bytes: data))
    }
  }

  /// JPEG quality steps first, then bounded downscaling to meet 4 MB.
  private func encodeScreenshot(_ source: UIImage) -> Data? {
    let maxBytes = 4 * 1024 * 1024
    let qualities: [CGFloat] = [0.85, 0.70, 0.55]
    var current = source

    for pass in 0..<5 {
      for quality in qualities {
        if let data = current.jpegData(compressionQuality: quality),
           data.count <= maxBytes {
          return data
        }
      }

      if pass == 4 { break }
      let nextSize = CGSize(
        width: max(1, current.size.width * 0.75),
        height: max(1, current.size.height * 0.75)
      )
      let format = UIGraphicsImageRendererFormat.default()
      format.opaque = true
      format.scale = current.scale
      current = UIGraphicsImageRenderer(size: nextSize, format: format).image { _ in
        current.draw(in: CGRect(origin: .zero, size: nextSize))
      }
    }
    return nil
  }

  /// Clears only pre-journal native authority. Account preferences, app-group
  /// shortcuts, audit counters and files are intentionally retained.
  private func clearLegacySessionAuthority() -> Bool {
    if #available(iOS 13.0, *) {
      BGTaskScheduler.shared.cancelAllTaskRequests()
    }
    endTransientBackgroundTask()
    let center = UNUserNotificationCenter.current()
    center.removeAllPendingNotificationRequests()
    center.removeAllDeliveredNotifications()
    let defaults = UserDefaults.standard
    defaults.removeObject(forKey: "application_incarnation")
    return defaults.synchronize() &&
      defaults.object(forKey: "application_incarnation") == nil
  }

  private func clearNativeResetState() -> Bool {
    if #available(iOS 13.0, *) {
      BGTaskScheduler.shared.cancelAllTaskRequests()
    }
    endTransientBackgroundTask()
    let center = UNUserNotificationCenter.current()
    center.removeAllPendingNotificationRequests()
    center.removeAllDeliveredNotifications()
    var durableStateCleared = homeShortcutsChannel.clearForTerminalReset()

    let defaults = UserDefaults.standard
    for key in defaults.dictionaryRepresentation().keys {
      defaults.removeObject(forKey: key)
    }
    durableStateCleared = defaults.synchronize() && durableStateCleared
    return durableStateCleared
  }

  private func beginTransientBackgroundTask(result: @escaping FlutterResult) {
    if transientBackgroundTask != .invalid {
      result(true)
      return
    }

    transientBackgroundTask = UIApplication.shared.beginBackgroundTask(withName: "zkpassport-launch") { [weak self] in
      self?.endTransientBackgroundTask()
    }

    if transientBackgroundTask == .invalid {
      print("[AppDelegate] ✗ Failed to acquire transient background task")
      result(false)
      return
    }

    // Keep Usernode alive briefly during app-switch handshake.
    DispatchQueue.main.asyncAfter(deadline: .now() + 20.0) { [weak self] in
      self?.endTransientBackgroundTask()
    }

    result(true)
  }

  private func endTransientBackgroundTask() {
    guard transientBackgroundTask != .invalid else {
      return
    }
    UIApplication.shared.endBackgroundTask(transientBackgroundTask)
    transientBackgroundTask = .invalid
  }

  private func requestNotificationPermission(result: @escaping FlutterResult) {
    print("[AppDelegate] Requesting notification permission - Options: [alert, sound, badge]")

    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      DispatchQueue.main.async {
        if let error = error {
          print("[AppDelegate] ✗ Notification permission request error: \(error.localizedDescription)")
        } else if granted {
          print("[AppDelegate] ✓ Notification permission GRANTED")

          // Send permission granted event to Flutter
          print("[AppDelegate] Sending ios_notification_permission_granted event to Flutter")
          DispatchQueue.main.async {
            self.sendEventToFlutter(eventType: "ios_notification_permission_granted", eventData: [:])
          }
        } else {
          print("[AppDelegate] ✗ Notification permission DENIED")

          // Send permission denied event to Flutter
          print("[AppDelegate] Sending ios_notification_permission_denied event to Flutter")
          DispatchQueue.main.async {
            self.sendEventToFlutter(eventType: "ios_notification_permission_denied", eventData: [:])
          }
        }

        // Check detailed permission status
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          print("[AppDelegate] Notification settings:")
          print("[AppDelegate]   Authorization status: \(settings.authorizationStatus.rawValue)")
          print("[AppDelegate]   Alert: \(settings.alertSetting.rawValue)")
          print("[AppDelegate]   Sound: \(settings.soundSetting.rawValue)")
          print("[AppDelegate]   Badge: \(settings.badgeSetting.rawValue)")
        }

        result(granted)
      }
    }
  }

  func sendEventToFlutter(eventType: String, eventData: [String: Any] = [:]) {
    guard let channel = alarmChannel else {
      print("[AppDelegate] ⚠ Cannot send event '\(eventType)' - alarm channel not initialized")
      return
    }

    print("[AppDelegate] Sending event to Flutter: \(eventType)")

    let args: [String: Any] = [
      "eventType": eventType,
      "eventData": eventData
    ]

    channel.invokeMethod("onBlockProductionEvent", arguments: args)
  }
}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate {

  // Called when notification is delivered while app is in foreground
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    print("[AppDelegate] Notification delivered (foreground) - ID: \(notification.request.identifier)")

    let content = notification.request.content
    if isSocialNotification(content) {
      // FlutterFire owns the message event. The Social page already renders
      // foreground activity, so suppress a duplicate system banner.
      super.userNotificationCenter(center, willPresent: notification) { _ in
        completionHandler([])
      }
      return
    }
    super.userNotificationCenter(
      center,
      willPresent: notification,
      withCompletionHandler: completionHandler
    )
  }
}
