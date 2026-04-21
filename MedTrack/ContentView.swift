import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Medication.name) private var medications: [Medication]

    @State private var selectedTab = 0
    @State private var pillBox = PillBoxState()

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(selectedTab: $selectedTab)
                .environment(pillBox)
                .tabItem { Label("Today", systemImage: "house.fill") }
                .tag(0)

            NavigationStack {
                MedicationListView()
            }
            .tabItem { Label("Schedule", systemImage: "calendar") }
            .tag(1)

            PillBoxView()
                .environment(pillBox)
                .tabItem { Label("PillBox", systemImage: "cross.case.fill") }
                .tag(2)
        }
        .tint(Color.dsAccent)
        .onAppear {
            NotificationManager.shared.requestPermission()
            rescheduleNotifications()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { rescheduleNotifications() }
        }
    }

    private func rescheduleNotifications() {
        let store = MedicationStore(context: context)
        store.rescheduleAllNotifications(medications: medications)
    }
}
