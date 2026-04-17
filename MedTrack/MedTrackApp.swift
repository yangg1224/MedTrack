import SwiftUI
import SwiftData

@main
struct MedTrackApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Medication.self, DoseRecord.self])
    }
}
