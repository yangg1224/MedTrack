import SwiftData
import Foundation

struct DaySummary: Identifiable {
    var id: Date { date }
    let date: Date
    let taken: Int
    let total: Int

    var adherenceRatio: Double {
        total == 0 ? 0 : Double(taken) / Double(total)
    }

    var adherenceColor: AdherenceColor {
        switch adherenceRatio {
        case 0.8...: return .good
        case 0.5..<0.8: return .fair
        default: return .poor
        }
    }

    enum AdherenceColor {
        case good, fair, poor
    }
}

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var summaries: [DaySummary] = []

    func load(from records: [DoseRecord]) {
        let today = DateHelpers.startOfDay()
        // Only show past days (not today)
        let pastRecords = records.filter { $0.scheduledDate < today }

        // Group by calendar day
        let grouped = Dictionary(grouping: pastRecords) {
            DateHelpers.startOfDay($0.scheduledDate)
        }

        summaries = grouped
            .map { date, dayRecords in
                DaySummary(
                    date: date,
                    taken: dayRecords.filter { $0.status == .taken }.count,
                    total: dayRecords.count
                )
            }
            .sorted { $0.date > $1.date } // newest first
    }
}
