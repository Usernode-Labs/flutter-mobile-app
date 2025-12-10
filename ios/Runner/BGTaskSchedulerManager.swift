import Foundation
import BackgroundTasks
import UIKit

@available(iOS 13.0, *)
class BGTaskSchedulerManager {
    private let taskIdentifier = "com.usernode.app.slotmonitoring"
    private let notificationCenter = UNUserNotificationCenter.current()
    private var isRegistered = false

    // Register BGProcessingTask
    // NOTE: This MUST be called during or before didFinishLaunchingWithOptions returns
    // Calling it later can cause main thread blocking or undefined behavior
    func registerBGTasks() -> Bool {
        print("[BGTaskScheduler] Attempting to register BGTask - Identifier: \(taskIdentifier)")
        print("[BGTaskScheduler] iOS Version: \(UIDevice.current.systemVersion), Device: \(UIDevice.current.model)")

        // Prevent duplicate registration
        if isRegistered {
            print("[BGTaskScheduler] Already registered, skipping duplicate registration")
            return true
        }

        print("[BGTaskScheduler] Calling BGTaskScheduler.shared.register...")

        // Use background queue to avoid blocking main thread
        let success = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: DispatchQueue.global()
        ) { task in
            print("[BGTaskScheduler] BGTask handler called - Task: \(type(of: task))")

            // Safe cast instead of force unwrap
            guard let bgTask = task as? BGProcessingTask else {
                print("[BGTaskScheduler] ERROR - Unexpected task type: \(type(of: task))")
                task.setTaskCompleted(success: false)
                return
            }
            self.handleBGTask(task: bgTask)
        }

        if success {
            isRegistered = true
            print("[BGTaskScheduler] ✓ Successfully registered task \(taskIdentifier)")
        } else {
            print("[BGTaskScheduler] ✗ Failed to register task \(taskIdentifier)")
        }

        return success
    }

    // Schedule a BGProcessingTask for a specific slot
    func scheduleBGTask(alarmId: String, alarmTimeMs: Int64, slotNumber: Int) -> Bool {
        print("[BGTaskScheduler] Scheduling BGTask for slot \(slotNumber)")
        print("[BGTaskScheduler] AlarmId: \(alarmId), AlarmTimeMs: \(alarmTimeMs)")

        let request = BGProcessingTaskRequest(identifier: taskIdentifier)

        // Schedule for the alarm time
        let alarmDate = Date(timeIntervalSince1970: Double(alarmTimeMs) / 1000.0)
        let delaySeconds = alarmDate.timeIntervalSinceNow
        print("[BGTaskScheduler] EarliestBeginDate: \(alarmDate), Delay: \(Int(delaySeconds))s")

        request.earliestBeginDate = alarmDate

        // Allow execution while on battery
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        print("[BGTaskScheduler] NetworkConnectivity: true, ExternalPower: false")

        do {
            try BGTaskScheduler.shared.submit(request)
            print("[BGTaskScheduler] ✓ BGTask submitted successfully for slot \(slotNumber)")

            // Send ios_bgtask_scheduled event to Flutter
            print("[BGTaskScheduler] Sending ios_bgtask_scheduled event to Flutter")
            let eventData: [String: Any] = [
                "slotNumber": slotNumber,
                "scheduledTime": alarmTimeMs
            ]
            AppDelegate.shared?.sendEventToFlutter(eventType: "ios_bgtask_scheduled", eventData: eventData)

            // Also schedule a local notification as backup
            print("[BGTaskScheduler] Scheduling backup notification...")
            scheduleSlotNotification(slotNumber: slotNumber, alarmDate: alarmDate)

            return true
        } catch {
            print("[BGTaskScheduler] ✗ Failed to submit BGTask - Error: \(error.localizedDescription)")

            // Still schedule notification even if BG task fails
            print("[BGTaskScheduler] Scheduling notification despite BGTask failure...")
            scheduleSlotNotification(slotNumber: slotNumber, alarmDate: alarmDate)

            return false
        }
    }

    // Cancel a specific BGTask
    func cancelBGTask(alarmId: String) {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)

        // Also cancel corresponding notification
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [alarmId])

        print("BGTaskScheduler: Cancelled task")
    }

    // Cancel all BGTasks
    func cancelAllBGTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        notificationCenter.removeAllPendingNotificationRequests()

        print("BGTaskScheduler: Cancelled all tasks and notifications")
    }

    // Handle when BGTask executes
    private func handleBGTask(task: BGProcessingTask) {
        let startTime = Date().timeIntervalSince1970 * 1000
        print("[BGTaskScheduler] ✓ BGTask EXECUTED - Time: \(Int64(startTime))")
        print("[BGTaskScheduler] Task identifier: \(task.identifier)")

        // Send ios_bgtask_executed event to Flutter
        print("[BGTaskScheduler] Sending ios_bgtask_executed event to Flutter")
        let eventData: [String: Any] = [
            "slotNumber": 0, // Unknown slot number in BGTask handler
            "executionDuration": 0 // Will update on completion
        ]
        AppDelegate.shared?.sendEventToFlutter(eventType: "ios_bgtask_executed", eventData: eventData)

        // Track background task execution for metrics
        incrementBackgroundTaskStats()

        // Schedule next task (BGTasks need to be rescheduled)
        print("[BGTaskScheduler] Scheduling next BGTask...")
        scheduleNextBGTask()

        // Start monitoring work
        let workItem = DispatchWorkItem {
            print("[BGTaskScheduler] Work item executing...")
            // Try to wake up the app
            self.attemptAppWakeup(task: task)
        }

        // Cancel if task expires
        task.expirationHandler = {
            let expirationTime = Date().timeIntervalSince1970 * 1000
            let duration = Int64(expirationTime - startTime)
            print("[BGTaskScheduler] ⚠ Task EXPIRED after \(duration)ms")

            // Send ios_bgtask_expired event to Flutter
            print("[BGTaskScheduler] Sending ios_bgtask_expired event to Flutter")
            let expiredEventData: [String: Any] = [
                "slotNumber": 0 // Unknown slot number in BGTask handler
            ]
            AppDelegate.shared?.sendEventToFlutter(eventType: "ios_bgtask_expired", eventData: expiredEventData)

            workItem.cancel()
        }

        // Execute work
        print("[BGTaskScheduler] Dispatching work item...")
        DispatchQueue.global().async(execute: workItem)

        // Wait for completion
        workItem.notify(queue: .main) {
            let endTime = Date().timeIntervalSince1970 * 1000
            let duration = Int64(endTime - startTime)
            let success = !workItem.isCancelled
            print("[BGTaskScheduler] Task completed - Success: \(success), Duration: \(duration)ms")
            task.setTaskCompleted(success: success)
        }
    }

    // Attempt to wake up the Flutter app
    private func attemptAppWakeup(task: BGProcessingTask) {
        print("[BGTaskScheduler] Attempting to wake up app for slot monitoring")
        print("[BGTaskScheduler] NOTE: BGTask has 30s execution limit, cannot start Rust node")

        // The app should handle monitoring via foreground notification tap
        // BGTask alone cannot reliably start the Rust node

        // Mark as complete
        print("[BGTaskScheduler] Marking task as complete")
        task.setTaskCompleted(success: true)
    }

    // Schedule local notification for slot
    private func scheduleSlotNotification(slotNumber: Int, alarmDate: Date) {
        print("[BGTaskScheduler] Scheduling local notification for slot \(slotNumber)")
        print("[BGTaskScheduler] Notification time: \(alarmDate)")

        let content = UNMutableNotificationContent()
        content.title = "Slots Coming Up"
        content.body = "Open the app to increase your chances of producing blocks"
        content.sound = .default

        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
            print("[BGTaskScheduler] Using timeSensitive interruption level (iOS 15+)")
        } else {
            print("[BGTaskScheduler] Standard notification (iOS < 15)")
        }

        content.categoryIdentifier = "SLOT_MONITORING"
        content.userInfo = ["slotNumber": slotNumber]
        print("[BGTaskScheduler] UserInfo: slot \(slotNumber)")

        // Schedule for the alarm time
        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: alarmDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        print("[BGTaskScheduler] Trigger date components: \(triggerDate)")

        let notificationId = "slot_\(slotNumber)"
        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: trigger
        )

        print("[BGTaskScheduler] Adding notification request - ID: \(notificationId)")
        notificationCenter.add(request) { error in
            if let error = error {
                print("[BGTaskScheduler] ✗ Failed to schedule notification - Error: \(error.localizedDescription)")
            } else {
                print("[BGTaskScheduler] ✓ Notification scheduled successfully for slot \(slotNumber)")

                // Send ios_notification_scheduled event to Flutter
                print("[BGTaskScheduler] Sending ios_notification_scheduled event to Flutter")
                let eventData: [String: Any] = [
                    "slotNumber": slotNumber,
                    "scheduledTime": Int64(alarmDate.timeIntervalSince1970 * 1000)
                ]
                AppDelegate.shared?.sendEventToFlutter(eventType: "ios_notification_scheduled", eventData: eventData)
            }
        }
    }

    // Schedule the next BGTask (required since they don't auto-repeat)
    private func scheduleNextBGTask() {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)

        // Schedule for 15 minutes from now (just to keep tasks running)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
            print("BGTaskScheduler: Scheduled next BGTask")
        } catch {
            print("BGTaskScheduler: Failed to schedule next task - \(error.localizedDescription)")
        }
    }

    // Track background task execution for metrics
    private func incrementBackgroundTaskStats() {
        let defaults = UserDefaults.standard
        let currentCount = defaults.integer(forKey: "bg_task_execution_count")
        defaults.set(currentCount + 1, forKey: "bg_task_execution_count")
        defaults.set(Int64(Date().timeIntervalSince1970 * 1000), forKey: "bg_task_last_execution_time")
        defaults.synchronize()
        print("BGTaskScheduler: Incremented background task execution count to \(currentCount + 1)")
    }
}
