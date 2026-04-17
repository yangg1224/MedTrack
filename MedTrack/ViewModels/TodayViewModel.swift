import SwiftData
import Foundation

@MainActor
final class TodayViewModel {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Creates a DoseRecord for every (medication × scheduledTime) pair for today, if one doesn't exist yet.
    /// This is idempotent — safe to call multiple times.
    func generateDoseRecordsForToday(medications: [Medication]) {
        let today = DateHelpers.startOfDay()

        for med in medications where med.isActive {
            for time in med.scheduledTimes {
                let exists = med.doseRecords.contains {
                    DateHelpers.isSameDay($0.scheduledDate, today) &&
                    timesMatch($0.scheduledTime, time)
                }
                if !exists {
                    let record = DoseRecord(
                        medication: med,
                        scheduledDate: today,
                        scheduledTime: time
                    )
                    context.insert(record)
                }
            }
        }
    }

    /// Marks any pending dose from today whose scheduled time + 1 hour has passed as missed.
    func reconcileMissedDoses(records: [DoseRecord]) {
        let now = Date()
        let gracePeriod: TimeInterval = 60 * 60 // 1 hour

        for record in records where record.status == .pending {
            let scheduledDateTime = DateHelpers.combining(
                date: record.scheduledDate,
                withTimeFrom: record.scheduledTime
            )
            if scheduledDateTime.addingTimeInterval(gracePeriod) < now {
                record.status = .missed
            }
        }
    }

    /// Marks a dose as taken right now.
    func markTaken(_ record: DoseRecord) {
        record.status = .taken
        record.takenAt = Date()
    }

    // MARK: - Private

    private func timesMatch(_ a: Date, _ b: Date) -> Bool {
        let ca = DateHelpers.calendar.dateComponents([.hour, .minute], from: a)
        let cb = DateHelpers.calendar.dateComponents([.hour, .minute], from: b)
        return ca.hour == cb.hour && ca.minute == cb.minute
    }
}
