import SwiftData
import Foundation

enum DoseStatus: String, Codable {
    case pending
    case taken
    case missed
}

@Model
final class DoseRecord {
    @Attribute(.unique) var id: UUID
    /// The calendar date this dose belongs to (year/month/day, time zeroed out).
    var scheduledDate: Date
    /// The time slot for this dose (only hour+minute matter).
    var scheduledTime: Date
    var status: DoseStatus
    /// Set when the user taps "Mark as Taken".
    var takenAt: Date?

    var medication: Medication?

    init(
        id: UUID = UUID(),
        medication: Medication,
        scheduledDate: Date,
        scheduledTime: Date,
        status: DoseStatus = .pending
    ) {
        self.id = id
        self.medication = medication
        self.scheduledDate = scheduledDate
        self.scheduledTime = scheduledTime
        self.status = status
        self.takenAt = nil
    }
}
