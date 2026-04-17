import SwiftData
import Foundation

/// Handles add / update / delete of Medication objects and keeps notifications in sync.
@MainActor
final class MedicationStore {
    private let context: ModelContext
    private let notifications = NotificationManager.shared

    init(context: ModelContext) {
        self.context = context
    }

    func add(name: String, dosage: String, unit: String, scheduledTimes: [Date]) {
        let med = Medication(
            name: name,
            dosage: dosage,
            unit: unit,
            scheduledTimes: scheduledTimes
        )
        context.insert(med)
        notifications.scheduleNotifications(for: med)
    }

    func update(_ med: Medication, name: String, dosage: String, unit: String, scheduledTimes: [Date]) {
        notifications.cancelNotifications(for: med)
        med.name = name
        med.dosage = dosage
        med.unit = unit
        med.scheduledTimes = scheduledTimes
        notifications.scheduleNotifications(for: med)
    }

    func delete(_ med: Medication) {
        notifications.cancelNotifications(for: med)
        context.delete(med)
    }

    /// Safety-net: re-schedules notifications for all active medications (idempotent).
    func rescheduleAllNotifications(medications: [Medication]) {
        for med in medications where med.isActive {
            notifications.scheduleNotifications(for: med)
        }
    }
}
