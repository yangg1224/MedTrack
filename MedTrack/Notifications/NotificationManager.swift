import UserNotifications
import Foundation

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Permission

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func checkAuthorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                completion(settings.authorizationStatus)
            }
        }
    }

    // MARK: - Schedule

    /// Schedules one repeating daily notification per time slot in the medication's schedule.
    func scheduleNotifications(for medication: Medication) {
        for (index, time) in medication.scheduledTimes.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "\(medication.name) – Time to take your dose"
            content.body = "\(medication.dosage) \(medication.unit)"
            content.sound = .default

            let timeComponents = DateHelpers.calendar.dateComponents([.hour, .minute], from: time)
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: timeComponents,
                repeats: true
            )

            let request = UNNotificationRequest(
                identifier: notificationID(for: medication, slotIndex: index),
                content: content,
                trigger: trigger
            )

            center.add(request)
        }
    }

    // MARK: - Cancel

    /// Cancels all pending notifications for the given medication.
    func cancelNotifications(for medication: Medication) {
        let ids = (0..<medication.scheduledTimes.count).map {
            notificationID(for: medication, slotIndex: $0)
        }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Foreground display

    /// Show notification banner even when app is in foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Badge reset

    func resetBadge() {
        center.setBadgeCount(0)
    }

    // MARK: - Private

    private func notificationID(for medication: Medication, slotIndex: Int) -> String {
        "medtrack-\(medication.id.uuidString)-slot-\(slotIndex)"
    }
}
