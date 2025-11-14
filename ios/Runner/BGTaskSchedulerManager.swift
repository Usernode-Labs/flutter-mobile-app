import Foundation
import BackgroundTasks
import UIKit

@available(iOS 13.0, *)
class BGTaskSchedulerManager {
    private let taskIdentifier = "com.usernode.lingash.slotmonitoring"
    private let notificationCenter = UNUserNotificationCenter.current()

    // Register BGProcessingTask
    func registerBGTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            self.handleBGTask(task: task as! BGProcessingTask)
        }

        print("BGTaskScheduler: Registered task \(taskIdentifier)")
    }

    // Schedule a BGProcessingTask for a specific slot
    func scheduleBGTask(alarmId: String, alarmTimeMs: Int64, slotNumber: Int) -> Bool {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)

        // Schedule for the alarm time
        let alarmDate = Date(timeIntervalSince1970: Double(alarmTimeMs) / 1000.0)
        request.earliestBeginDate = alarmDate

        // Allow execution while on battery
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
            print("BGTaskScheduler: Scheduled task for slot \(slotNumber) at \(alarmDate)")

            // Also schedule a local notification as backup
            scheduleSlotNotification(slotNumber: slotNumber, alarmDate: alarmDate)

            return true
        } catch {
            print("BGTaskScheduler: Failed to schedule task - \(error.localizedDescription)")

            // Still schedule notification even if BG task fails
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
        print("BGTaskScheduler: BGTask started execution")

        // Schedule next task (BGTasks need to be rescheduled)
        scheduleNextBGTask()

        // Start monitoring work
        let workItem = DispatchWorkItem {
            // Try to wake up the app
            self.attemptAppWakeup(task: task)
        }

        // Cancel if task expires
        task.expirationHandler = {
            print("BGTaskScheduler: Task expired")
            workItem.cancel()
        }

        // Execute work
        DispatchQueue.global().async(execute: workItem)

        // Wait for completion
        workItem.notify(queue: .main) {
            task.setTaskCompleted(success: !workItem.isCancelled)
        }
    }

    // Attempt to wake up the Flutter app
    private func attemptAppWakeup(task: BGProcessingTask) {
        print("BGTaskScheduler: Attempting to wake up app for slot monitoring")

        // The app should handle monitoring via foreground notification tap
        // BGTask alone cannot reliably start the Rust node

        // Mark as complete
        task.setTaskCompleted(success: true)
    }

    // Schedule local notification for slot
    private func scheduleSlotNotification(slotNumber: Int, alarmDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Block Production Time"
        content.body = "Slot \(slotNumber) is coming up. Tap to start monitoring."
        content.sound = .default
        content.interruptionLevel = .timeSensitive
        content.categoryIdentifier = "SLOT_MONITORING"
        content.userInfo = ["slotNumber": slotNumber]

        // Schedule for 2 minutes before slot time
        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: alarmDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)

        let request = UNNotificationRequest(
            identifier: "slot_\(slotNumber)",
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request) { error in
            if let error = error {
                print("BGTaskScheduler: Failed to schedule notification - \(error.localizedDescription)")
            } else {
                print("BGTaskScheduler: Scheduled notification for slot \(slotNumber)")
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
}
