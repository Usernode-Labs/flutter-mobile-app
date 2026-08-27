import UIKit
import Flutter
import BackgroundTasks
import UserNotifications
import WebKit

final class ApplicationIncarnationStore {
  static let shared = ApplicationIncarnationStore()
  static let eventKey = "applicationIncarnation"
  private static let defaultsKey = "application_incarnation"
  private let lock = NSLock()
  private var terminalResetRequested = false

  private init() {}

  func ensure() -> String? {
    lock.lock()
    defer { lock.unlock() }
    guard !terminalResetRequested else { return nil }
    if let current = storedCurrent() { return current }
    let created = UUID().uuidString
    UserDefaults.standard.set(created, forKey: Self.defaultsKey)
    return created
  }

  func current() -> String? {
    lock.lock()
    defer { lock.unlock() }
    guard !terminalResetRequested else { return nil }
    return storedCurrent()
  }

  private func storedCurrent() -> String? {
    guard let value = UserDefaults.standard.string(forKey: Self.defaultsKey),
          !value.isEmpty else {
      return nil
    }
    return value
  }

  func matches(_ captured: String?) -> Bool {
    guard let captured, let current = current() else { return false }
    return captured == current
  }

  func invalidate() -> Bool {
    lock.lock()
    defer { lock.unlock() }
    terminalResetRequested = true
    UserDefaults.standard.removeObject(forKey: Self.defaultsKey)
    return UserDefaults.standard.synchronize() && storedCurrent() == nil
  }

  /// Retires the current token and issues a fresh one.
  ///
  /// The reversible twin of `invalidate()`, for the one boundary that keeps
  /// the process alive: a scoped sign-out. Work scheduled by the retired
  /// session no longer `matches`, while this process keeps scheduling under
  /// the returned token. Returns nil once a terminal reset has latched the
  /// store shut.
  func rotate() -> String? {
    lock.lock()
    defer { lock.unlock() }
    guard !terminalResetRequested else { return nil }
    let created = UUID().uuidString
    UserDefaults.standard.set(created, forKey: Self.defaultsKey)
    guard UserDefaults.standard.synchronize(), storedCurrent() == created else {
      return nil
    }
    return created
  }
}

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private static let socialNotificationSource = "usernode_social"
  private static let socialNotificationCategory = "USERNODE_SOCIAL"
  private let alarmChannelName = "com.usernode.app/alarm"
  private let screenshotChannelName = "com.usernode.app/screenshot"
  private var alarmChannel: FlutterMethodChannel?
  private var screenshotChannel: FlutterMethodChannel?
  private var nativeSessionChannel: IOSNativeSessionChannel?
  private let homeShortcutsChannel = HomeShortcutsChannel()
  private let bgTaskScheduler = BGTaskSchedulerManager()
  private var transientBackgroundTask: UIBackgroundTaskIdentifier = .invalid

  // Singleton access for notification scheduling callbacks.
  static var shared: AppDelegate?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    print("[AppDelegate] ✓ Application launching - iOS \(UIDevice.current.systemVersion), Device: \(UIDevice.current.model)")
    print("[AppDelegate] Launch options: \(launchOptions?.keys.map { $0.rawValue } ?? [])")

    // Set singleton instance
    AppDelegate.shared = self
    print("[AppDelegate] Singleton instance set")

    // Set notification center delegate to receive notification events
    UNUserNotificationCenter.current().delegate = self
    registerSocialNotificationCategory()
    print("[AppDelegate] UNUserNotificationCenter delegate set")

    // Register a no-op legacy BGTask handler during launch. New versions do
    // not submit BGTasks, but old installed requests still need a safe drain.
    if #available(iOS 13.0, *) {
      print("[AppDelegate] Registering legacy BGTask drain (iOS 13+)...")
      let success = bgTaskScheduler.registerBGTasks()
      if success {
        print("[AppDelegate] ✓ Legacy BGTask drain registered during app launch")
      } else {
        print("[AppDelegate] ✗ WARNING - Failed to register legacy BGTask drain")
      }
    } else {
      print("[AppDelegate] Skipping legacy BGTask drain (iOS < 13)")
    }

    // Enable background fetch
    if #available(iOS 13.0, *) {
      print("[AppDelegate] Setting minimum background fetch interval")
      UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
    }

    // Check notification permissions on launch
    checkAndNotifyNotificationPermissionStatus()

    print("[AppDelegate] Calling super.application(didFinishLaunchingWithOptions:)")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    print("[AppDelegate] Plugin registrant registered")

    setupApplicationChannels(
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
  }

  private func setupApplicationChannels(binaryMessenger: FlutterBinaryMessenger) {
    alarmChannel = FlutterMethodChannel(
      name: alarmChannelName,
      binaryMessenger: binaryMessenger
    )
    setupMethodChannelHandlers()
    print("[AppDelegate] Method channel '\(alarmChannelName)' configured")

    let shortcutsChannel = FlutterMethodChannel(
      name: HomeShortcutsChannel.channelName,
      binaryMessenger: binaryMessenger
    )
    shortcutsChannel.setMethodCallHandler { [weak self] (call, result) in
      self?.homeShortcutsChannel.handle(call, result: result)
    }
    print("[AppDelegate] Method channel '\(HomeShortcutsChannel.channelName)' configured")

    screenshotChannel = FlutterMethodChannel(
      name: screenshotChannelName,
      binaryMessenger: binaryMessenger
    )
    screenshotChannel?.setMethodCallHandler { [weak self] (call, result) in
      guard call.method == "capture" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.captureCurrentScreen(result: result)
    }
    print("[AppDelegate] Method channel '\(screenshotChannelName)' configured")

    nativeSessionChannel?.close()
    nativeSessionChannel = IOSNativeSessionChannel(messenger: binaryMessenger)
    print("[AppDelegate] Private native-session channel configured")
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

  private func blockProductionSlot(from content: UNNotificationContent) -> Int? {
    if let slot = content.userInfo["slotNumber"] as? Int {
      return slot
    }
    return (content.userInfo["slotNumber"] as? NSNumber)?.intValue
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

  // Handle background fetch
  override func application(
    _ application: UIApplication,
    performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    IOSNativeProducerWakeCoordinator.shared.runBackground { [weak self] wake in
      if wake.outcome == "retired", let revision = wake.nativeRevision {
        self?.nativeSessionChannel?.notifyRetired(nativeRevision: revision)
      }
      switch wake.outcome {
      case "completed", "retired": completionHandler(.newData)
      case "retry": completionHandler(.failed)
      default: completionHandler(.noData)
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
    case "ensureApplicationIncarnation":
      result(ApplicationIncarnationStore.shared.ensure())

    case "invalidateApplicationIncarnation":
      result(ApplicationIncarnationStore.shared.invalidate())

    case "rotateApplicationIncarnation":
      result(ApplicationIncarnationStore.shared.rotate())

    case "clearSessionNotifications":
      clearSessionNotifications(result: result)

    case "clearWebSessionData":
      clearWebSessionData(result: result)

    case "clearNativeResetState":
      result(clearNativeResetState())

    case "enterTerminalReset":
      // iOS does not expose a supported self-termination API. Dart has already
      // replaced the functional app with the inert reset-complete surface.
      result(nil)

    case "registerBGTasks":
      print("[AppDelegate] registerBGTasks called via MethodChannel")
      if #available(iOS 13.0, *) {
        // The legacy drain is already registered in didFinishLaunching.
        // This compatibility method intentionally does no additional work.
        print("[AppDelegate] Legacy BGTask drain already registered, returning true")
        result(true)
      } else {
        print("[AppDelegate] BGTasks unavailable (iOS < 13)")
        result(FlutterError(code: "UNAVAILABLE", message: "BGTasks require iOS 13+", details: nil))
      }

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

    case "scheduleIOSBGTask":
      print("[AppDelegate] Legacy scheduleIOSBGTask API called for notification")
      guard let args = call.arguments as? [String: Any],
            let alarmId = args["alarmId"] as? String,
            let delayMs = (args["delayMs"] as? NSNumber)?.int64Value,
            let slotNumber = (args["globalSlot"] as? NSNumber)?.intValue,
            let applicationIncarnation =
              args[ApplicationIncarnationStore.eventKey] as? String,
            ApplicationIncarnationStore.shared.matches(applicationIncarnation) else {
        print("[AppDelegate] ✗ Invalid arguments for scheduleIOSBGTask")
        result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
        return
      }
      print("[AppDelegate] Scheduling slot notification - Slot: \(slotNumber), AlarmId: \(alarmId)")
      if #available(iOS 13.0, *) {
        bgTaskScheduler.scheduleBGTask(
          alarmId: alarmId,
          delayMs: delayMs,
          slotNumber: slotNumber,
          applicationIncarnation: applicationIncarnation
        ) { success in
          DispatchQueue.main.async {
            print(
              "[AppDelegate] Slot notification scheduling result - " +
              "AlarmId: \(alarmId), Slot: \(slotNumber), Success: \(success)"
            )
            result(success)
          }
        }
      } else {
        print("[AppDelegate] Slot notification scheduling failed (iOS < 13)")
        result(false)
      }

    case "cancelAlarm":
      print("[AppDelegate] cancelAlarm called")
      guard let args = call.arguments as? [String: Any],
            let alarmId = args["alarmId"] as? String else {
        print("[AppDelegate] ✗ Invalid arguments for cancelAlarm")
        result(FlutterError(code: "INVALID_ARGS", message: "Missing alarmId", details: nil))
        return
      }
      print("[AppDelegate] Cancelling alarm: \(alarmId)")
      if #available(iOS 13.0, *) {
        bgTaskScheduler.cancelBGTask(alarmId: alarmId)
      }
      result(true)

    case "cancelAllAlarms":
      print("[AppDelegate] cancelAllAlarms called")
      if #available(iOS 13.0, *) {
        bgTaskScheduler.cancelAllBGTasks()
      }
      print("[AppDelegate] All alarms cancelled")
      result(true)

    case "getBackgroundTaskStats":
      print("[AppDelegate] getBackgroundTaskStats called")
      let stats = getBackgroundTaskStats()
      print("[AppDelegate] Returning stats: \(stats)")
      result(stats)

    case "incrementBackgroundTaskCount":
      print("[AppDelegate] incrementBackgroundTaskCount called")
      incrementBackgroundTaskCount()
      result(true)

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

  private func clearNativeResetState() -> Bool {
    if #available(iOS 13.0, *) {
      bgTaskScheduler.cancelAllBGTasks()
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

  private func getBackgroundTaskStats() -> [String: Any] {
    let defaults = UserDefaults.standard
    return [
      "execution_count": defaults.integer(forKey: "bg_task_execution_count"),
      "last_execution_time": defaults.object(forKey: "bg_task_last_execution_time") as? Int64 ?? 0,
      "success_count": defaults.integer(forKey: "bg_task_success_count"),
      "failure_count": defaults.integer(forKey: "bg_task_failure_count")
    ]
  }

  private func incrementBackgroundTaskCount() {
    let defaults = UserDefaults.standard
    let currentCount = defaults.integer(forKey: "bg_task_execution_count")
    defaults.set(currentCount + 1, forKey: "bg_task_execution_count")
    defaults.set(Int64(Date().timeIntervalSince1970 * 1000), forKey: "bg_task_last_execution_time")
    defaults.synchronize()
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

  // Send block production event to Flutter
  func sendEventToFlutter(eventType: String, eventData: [String: Any] = [:]) {
    if requiresApplicationIncarnation(eventType),
       !ApplicationIncarnationStore.shared.matches(
         eventData[ApplicationIncarnationStore.eventKey] as? String
       ) {
      print("[AppDelegate] Ignoring stale event '\(eventType)'")
      return
    }
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

  private func requiresApplicationIncarnation(_ eventType: String) -> Bool {
    guard eventType.hasPrefix("ios_") else { return false }
    return eventType != "ios_notification_permission_granted" &&
      eventType != "ios_notification_permission_denied"
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
    guard let slotNumber = blockProductionSlot(from: content) else {
      super.userNotificationCenter(
        center,
        willPresent: notification,
        withCompletionHandler: completionHandler
      )
      return
    }
    guard let applicationIncarnation =
            content.userInfo[ApplicationIncarnationStore.eventKey] as? String,
          ApplicationIncarnationStore.shared.matches(applicationIncarnation) else {
      print("[AppDelegate] Suppressing stale slot notification")
      completionHandler([])
      return
    }

    // Send ios_notification_delivered event to Flutter
    print("[AppDelegate] Sending ios_notification_delivered event to Flutter")
    let eventData: [String: Any] = [
      "slotNumber": slotNumber,
      ApplicationIncarnationStore.eventKey: applicationIncarnation
    ]
    DispatchQueue.main.async {
      self.sendEventToFlutter(eventType: "ios_notification_delivered", eventData: eventData)
    }

    // Show notification even when app is in foreground
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  // Called when user taps on notification
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    print("[AppDelegate] Notification tapped - ID: \(response.notification.request.identifier)")

    let content = response.notification.request.content
    if isSocialNotification(content) {
      // Forward exactly once so firebase_messaging emits opened/initial data.
      super.userNotificationCenter(
        center,
        didReceive: response,
        withCompletionHandler: completionHandler
      )
      return
    }
    guard let slotNumber = blockProductionSlot(from: content) else {
      super.userNotificationCenter(
        center,
        didReceive: response,
        withCompletionHandler: completionHandler
      )
      return
    }

    // Send ios_notification_tapped event to Flutter
    print("[AppDelegate] Sending ios_notification_tapped event to Flutter")
    let eventData: [String: Any] = [
      "slotNumber": slotNumber,
      ApplicationIncarnationStore.eventKey:
        content.userInfo[ApplicationIncarnationStore.eventKey] as? String ?? ""
    ]
    DispatchQueue.main.async {
      self.sendEventToFlutter(eventType: "ios_notification_tapped", eventData: eventData)
    }

    completionHandler()
  }
}
