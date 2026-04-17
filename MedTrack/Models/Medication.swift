import SwiftData
import Foundation

@Model
final class Medication {
    @Attribute(.unique) var id: UUID
    var name: String
    var dosage: String
    var unit: String
    var isActive: Bool
    var createdAt: Date
    /// Each element represents one scheduled time per day. Only hour+minute components are used.
    var scheduledTimes: [Date]

    @Relationship(deleteRule: .cascade, inverse: \DoseRecord.medication)
    var doseRecords: [DoseRecord]

    init(
        id: UUID = UUID(),
        name: String,
        dosage: String,
        unit: String,
        scheduledTimes: [Date] = [],
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.unit = unit
        self.scheduledTimes = scheduledTimes
        self.isActive = isActive
        self.createdAt = Date()
        self.doseRecords = []
    }
}
