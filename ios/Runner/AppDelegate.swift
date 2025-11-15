import UIKit
import Flutter
import BackgroundTasks
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let alarmChannelName = "com.usernode.app/alarm"
  private var alarmChannel: FlutterMethodChannel?
  private let bgTaskScheduler = BGTaskSchedulerManager()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Setup method channel for alarm service
    // Use safe unwrapping instead of accessing rootViewController directly (Flutter deprecation fix)
    if let flutterViewController = window?.rootViewController as? FlutterViewController {
      alarmChannel = FlutterMethodChannel(
        name: alarmChannelName,
        binaryMessenger: flutterViewController.binaryMessenger
      )
      setupMethodChannelHandlers()
    } else {
      print("AppDelegate: Warning - Could not access FlutterViewController")
    }

    // Register WorkManager for background tasks
    WorkmanagerPlugin.setPluginRegistrantCallback { registry in
        GeneratedPluginRegistrant.register(with: registry)
    }

    // Register BGTaskScheduler tasks (MUST be done during app launch)
    // Apple requires this to happen before didFinishLaunchingWithOptions returns
    if #available(iOS 13.0, *) {
      let success = bgTaskScheduler.registerBGTasks()
      if success {
        print("AppDelegate: BGTasks registered successfully during app launch")
      } else {
        print("AppDelegate: WARNING - Failed to register BGTasks")
      }
    }

    // Enable background fetch
    if #available(iOS 13.0, *) {
      UIApplication.shared.setMinimumBackgroundFetchInterval(UIApplication.backgroundFetchIntervalMinimum)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle background task performance
  override func application(
    _ application: UIApplication,
    performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
  ) {
    // Let WorkManager handle the callback
    super.application(application, performFetchWithCompletionHandler: completionHandler)
  }

  private func setupMethodChannelHandlers() {
    alarmChannel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handleMethodCall(call, result: result)
    }
  }

  private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "registerBGTasks":
      if #available(iOS 13.0, *) {
        // NOTE: BGTasks are already registered in didFinishLaunchingWithOptions
        // This method is kept for backward compatibility but does nothing
        // Calling registerBGTasks() again would violate Apple's requirement
        // that it must be called before app launch completes
        print("AppDelegate: registerBGTasks called via MethodChannel (already registered during app launch)")
        result(true)
      } else {
        result(FlutterError(code: "UNAVAILABLE", message: "BGTasks require iOS 13+", details: nil))
      }
    case "requestNotificationPermission":
      requestNotificationPermission(result: result)
    case "scheduleIOSBGTask":
      guard let args = call.arguments as? [String: Any],
            let alarmId = args["alarmId"] as? String,
            let alarmTimeMs = args["alarmTimeMs"] as? Int64,
            let slotNumber = args["slotNumber"] as? Int else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing arguments", details: nil))
        return
      }
      if #available(iOS 13.0, *) {
        let success = bgTaskScheduler.scheduleBGTask(
          alarmId: alarmId,
          alarmTimeMs: alarmTimeMs,
          slotNumber: slotNumber
        )
        result(success)
      } else {
        result(false)
      }
    case "cancelAlarm":
      guard let args = call.arguments as? [String: Any],
            let alarmId = args["alarmId"] as? String else {
        result(FlutterError(code: "INVALID_ARGS", message: "Missing alarmId", details: nil))
        return
      }
      if #available(iOS 13.0, *) {
        bgTaskScheduler.cancelBGTask(alarmId: alarmId)
      }
      result(true)
    case "cancelAllAlarms":
      if #available(iOS 13.0, *) {
        bgTaskScheduler.cancelAllBGTasks()
      }
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func requestNotificationPermission(result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
      DispatchQueue.main.async {
        result(granted)
      }
    }
  }
}
