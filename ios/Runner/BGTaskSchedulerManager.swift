import Foundation
import BackgroundTasks
import UIKit

@available(iOS 13.0, *)
class BGTaskSchedulerManager {
    private let taskIdentifier = "com.usernode.app.slotmonitoring"
    private let notificationCenter = UNUserNotificationCenter.current()
    private var isRegistered = false

    // Keep the registered handler so a request submitted by an older app
    // version is drained harmlessly. New requests are not submitted: iOS
    // BGProcessingTask callbacks carry no request payload, so they cannot be
    // bound to the application incarnation that scheduled them.
    func registerBGTasks() -> Bool {
        if isRegistered {
            print("[BGTaskScheduler] Legacy drain already registered - Identifier: \(taskIdentifier)")
            return true
        }
        print(
            "[BGTaskScheduler] Registering legacy drain - Identifier: \(taskIdentifier), " +
            "iOS: \(UIDevice.current.systemVersion), Device: \(UIDevice.current.model)"
        )
        let success = BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: DispatchQueue.global()
        ) { task in
            print(
                "[BGTaskScheduler] Completing legacy task without lifecycle work - " +
                "Identifier: \(task.identifier), Type: \(type(of: task))"
            )
            task.setTaskCompleted(success: true)
        }
        isRegistered = success
        let registrationStatus = success ? "succeeded" : "failed"
        print(
            "[BGTaskScheduler] Legacy drain registration \(registrationStatus) - " +
            "Identifier: \(taskIdentifier)"
        )
        return success
    }

    // Retains the existing Dart/native API while using only a request whose
    // notification payload can carry and later validate the exact incarnation.
    func scheduleBGTask(
        alarmId: String,
        delayMs: Int64,
        slotNumber: Int,
        applicationIncarnation: String,
        completion: @escaping (Bool) -> Void
    ) {
        print(
            "[BGTaskScheduler] Scheduling slot notification - AlarmId: \(alarmId), " +
            "Slot: \(slotNumber), DelayMs: \(delayMs)"
        )
        guard ApplicationIncarnationStore.shared.matches(applicationIncarnation) else {
            print(
                "[BGTaskScheduler] Refusing stale slot notification - " +
                "AlarmId: \(alarmId), Slot: \(slotNumber)"
            )
            completion(false)
            return
        }
        let effectiveDelayMs = max(delayMs, Int64(0))
        let alarmDate = Date().addingTimeInterval(Double(effectiveDelayMs) / 1000.0)
        scheduleSlotNotification(
            alarmId: alarmId,
            slotNumber: slotNumber,
            alarmDate: alarmDate,
            applicationIncarnation: applicationIncarnation,
            completion: completion
        )
    }

    func cancelBGTask(alarmId: String) {
        // Also remove legacy BGTask requests left by an older app version.
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [alarmId])
        print("[BGTaskScheduler] Requested notification cancellation - AlarmId: \(alarmId)")
    }

    func cancelAllBGTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
        print("[BGTaskScheduler] Requested cancellation of all legacy tasks and notifications")
    }

    private func scheduleSlotNotification(
        alarmId: String,
        slotNumber: Int,
        alarmDate: Date,
        applicationIncarnation: String,
        completion: @escaping (Bool) -> Void
    ) {
        guard ApplicationIncarnationStore.shared.matches(applicationIncarnation) else {
            print(
                "[BGTaskScheduler] Refusing stale notification before add - " +
                "AlarmId: \(alarmId), Slot: \(slotNumber)"
            )
            completion(false)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Block Production Time"
        content.body = "Slot \(slotNumber) is coming up. Tap to start monitoring."
        content.sound = .default
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        content.categoryIdentifier = "SLOT_MONITORING"
        content.userInfo = [
            "alarmId": alarmId,
            "slotNumber": slotNumber,
            ApplicationIncarnationStore.eventKey: applicationIncarnation
        ]

        let triggerDate = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: alarmDate
        )
        let request = UNNotificationRequest(
            identifier: alarmId,
            content: content,
            trigger: UNCalendarNotificationTrigger(
                dateMatching: triggerDate,
                repeats: false
            )
        )

        print(
            "[BGTaskScheduler] Adding notification request - AlarmId: \(alarmId), " +
            "Slot: \(slotNumber), FireDate: \(alarmDate)"
        )
        notificationCenter.add(request) { error in
            guard ApplicationIncarnationStore.shared.matches(applicationIncarnation) else {
                self.notificationCenter.removePendingNotificationRequests(
                    withIdentifiers: [request.identifier]
                )
                print(
                    "[BGTaskScheduler] Removed stale notification after add - " +
                    "AlarmId: \(alarmId), Slot: \(slotNumber)"
                )
                completion(false)
                return
            }
            if let error = error {
                print(
                    "[BGTaskScheduler] Failed to schedule notification - " +
                    "AlarmId: \(alarmId), Slot: \(slotNumber), " +
                    "Error: \(error.localizedDescription)"
                )
                completion(false)
                return
            }
            print(
                "[BGTaskScheduler] Notification scheduled - AlarmId: \(alarmId), " +
                "Slot: \(slotNumber), FireDate: \(alarmDate)"
            )
            let eventData: [String: Any] = [
                "alarmId": alarmId,
                "slotNumber": slotNumber,
                "scheduledTime": Int64(alarmDate.timeIntervalSince1970 * 1000),
                ApplicationIncarnationStore.eventKey: applicationIncarnation
            ]
            DispatchQueue.main.async {
                AppDelegate.shared?.sendEventToFlutter(
                    eventType: "ios_notification_scheduled",
                    eventData: eventData
                )
            }
            completion(true)
        }
    }
}
