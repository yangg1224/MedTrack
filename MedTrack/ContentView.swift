import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Medication.name) private var medications: [Medication]

    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "checkmark.circle.fill")
                }

            NavigationStack {
                MedicationListView()
            }
            .tabItem {
                Label("My Meds", systemImage: "pills.fill")
            }

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "calendar")
            }
        }
        .onAppear {
            NotificationManager.shared.requestPermission()
            rescheduleNotifications()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                rescheduleNotifications()
            }
        }
    }

    /// Safety-net: re-schedules notifications for all active medications on every app open.
    private func rescheduleNotifications() {
        let store = MedicationStore(context: context)
        store.rescheduleAllNotifications(medications: medications)
    }
}
