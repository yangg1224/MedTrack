import Observation
import Foundation

@Observable
final class PillBoxState {
    var connected: Bool = false
    var battery: Int = 78
    var daysRemaining: Int = 14
    var signal: String = "Strong"
    var lastDispensedAt: Date? = Calendar.current.date(
        bySettingHour: 8, minute: 0, second: 0, of: .now
    )
}
