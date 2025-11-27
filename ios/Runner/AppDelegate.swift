import UIKit
import Flutter
import BackgroundTasks
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let alarmChannelName = "com.usernode.app/alarm"
  private var alarmChannel: FlutterMethodChannel?
  private let bgTaskScheduler = BGTaskSchedulerManager()

  // Singleton access for sending events from BGTaskSchedulerManager
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
    } else {
      print("[AppDelegate] ⚠ Warning - Could not access FlutterViewController")
    }

    // Register BGTaskScheduler tasks (MUST be done during app launch)
    // Apple requires this to happen before didFinishLaunchingWithOptions returns
    if #available(iOS 13.0, *) {
      print("[AppDelegate] Registering BGTasks (iOS 13+)...")
      let success = bgTaskScheduler.registerBGTasks()
      if success {
        print("[AppDelegate] ✓ BGTasks registered successfully during app launch")
      } else {
        print("[AppDelegate] ✗ WARNING - Failed to register BGTasks")
      }
    } else {
      print("[AppDelegate] Skipping BGTask registration (iOS < 13)")
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

  // Check and notify current notification permission status
  private func checkAndNotifyNotificationPermissionStatus() {
    print("[AppDelegate] Checking notification permission status...")
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      DispatchQueue.main.async {
        print("[AppDelegate] Notification authorization status: \(settings.authorizationStatus.rawValue)")
        if settings.authorizationStatus == .authorized {
          print("[AppDelegate] Sending ios_notification_permission_granted event (already authorized)")
          self.sendEventToFlutter(eventType: "ios_notification_permission_granted", eventData: [:])
        } else if settings.authorizationStatus == .denied {
          print("[AppDelegate] Sending ios_notification_permission_denied event (denied)")
          self.sendEventToFlutter(eventType: "ios_notification_permission_denied", eventData: [:])
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
    super.application(application, performFetchWithCompletionHandler: completionHandler)
  }

  private func setupMethodChannelHandlers() {
    alarmChannel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handleMethodCall(call, result: result)
    }
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    print("[AppDelegate] Method channel call received: \(call.method)")

    switch call.method {
    case "registerBGTasks":
      print("[AppDelegate] registerBGTasks called via MethodChannel")
      if #available(iOS 13.0, *) {
        // NOTE: BGTasks are already registered in didFinishLaunchingWithOptions
        // This method is kept for backward compatibility but does nothing
        // Calling registerBGTasks() again would violate Apple's requirement
        // that it must be called before app launch completes
        print("[AppDelegate] BGTasks already registered during app launch, returning true")
        result(true)
      } else {
        print("[AppDelegate] BGTasks unavailable (iOS < 13)")
        result(FlutterError(code: "UNAVAILABLE", message: "BGTasks require iOS 13+", details: nil))
      }

    case "requestNotificationPermission":
      print("[AppDelegate] requestNotificationPermission called")
      requestNotificationPermission(result: result)

    case "scheduleIOSBGTask":
      print("[AppDelegate] scheduleIOSBGTask called")
      guard let args = call.arguments as? [String: Any],
            let alarmId = args["alarmId"] as? String,
            let alarmTimeMs = args["alarmTimeMs"] as? Int64,
            let slotNumber = args["slotNumber"] as? Int else {
        print("[AppDelegate] ✗ Invalid arguments for scheduleIOSBGTask")
        result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
        return
      }
      print("[AppDelegate] Scheduling BGTask - Slot: \(slotNumber), AlarmId: \(alarmId)")
      if #available(iOS 13.0, *) {
        let success = bgTaskScheduler.scheduleBGTask(
          alarmId: alarmId,
          alarmTimeMs: alarmTimeMs,
          slotNumber: slotNumber
        )
        print("[AppDelegate] BGTask scheduling result: \(success)")
        result(success)
      } else {
        print("[AppDelegate] BGTask scheduling failed (iOS < 13)")
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

    default:
      print("[AppDelegate] ⚠ Unknown method: \(call.method)")
      result(FlutterMethodNotImplemented)
    }
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
          self.sendEventToFlutter(eventType: "ios_notification_permission_granted", eventData: [:])
        } else {
          print("[AppDelegate] ✗ Notification permission DENIED")

          // Send permission denied event to Flutter
          print("[AppDelegate] Sending ios_notification_permission_denied event to Flutter")
          self.sendEventToFlutter(eventType: "ios_notification_permission_denied", eventData: [:])
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

    // Extract slot number from notification
    let slotNumber = notification.request.content.userInfo["slotNumber"] as? Int ?? 0

    // Send ios_notification_delivered event to Flutter
    print("[AppDelegate] Sending ios_notification_delivered event to Flutter")
    let eventData: [String: Any] = ["slotNumber": slotNumber]
    sendEventToFlutter(eventType: "ios_notification_delivered", eventData: eventData)

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

    // Extract slot number from notification
    let slotNumber = response.notification.request.content.userInfo["slotNumber"] as? Int ?? 0

    // Send ios_notification_tapped event to Flutter
    print("[AppDelegate] Sending ios_notification_tapped event to Flutter")
    let eventData: [String: Any] = ["slotNumber": slotNumber]
    sendEventToFlutter(eventType: "ios_notification_tapped", eventData: eventData)

    completionHandler()
  }
}
