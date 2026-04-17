import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \Medication.name) private var medications: [Medication]

    /// Fetch today's DoseRecords only.
    @Query private var allRecords: [DoseRecord]

    @State private var notificationsDenied = false

    private var todayRecords: [DoseRecord] {
        let today = DateHelpers.startOfDay()
        return allRecords.filter { DateHelpers.isSameDay($0.scheduledDate, today) }
    }

    private var pending: [DoseRecord] { todayRecords.filter { $0.status == .pending } }
    private var taken: [DoseRecord]   { todayRecords.filter { $0.status == .taken } }
    private var missed: [DoseRecord]  { todayRecords.filter { $0.status == .missed } }

    private var viewModel: TodayViewModel { TodayViewModel(context: context) }

    var body: some View {
        NavigationStack {
            Group {
                if todayRecords.isEmpty && medications.isEmpty {
                    ContentUnavailableView(
                        "No Medications",
                        systemImage: "pills",
                        description: Text("Go to My Medications to add your first medication.")
                    )
                } else if todayRecords.isEmpty {
                    ContentUnavailableView(
                        "All Done!",
                        systemImage: "checkmark.seal.fill",
                        description: Text("No doses scheduled yet for today.")
                    )
                } else {
                    List {
                        if notificationsDenied {
                            notificationBanner
                        }

                        if !pending.isEmpty {
                            Section("Pending") {
                                ForEach(pending) { record in
                                    DoseRowView(record: record) {
                                        viewModel.markTaken(record)
                                    }
                                }
                            }
                        }

                        if !taken.isEmpty {
                            Section("Taken") {
                                ForEach(taken) { record in
                                    DoseRowView(record: record) { }
                                }
                            }
                        }

                        if !missed.isEmpty {
                            Section("Missed") {
                                ForEach(missed) { record in
                                    DoseRowView(record: record) { }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Today")
        }
        .onAppear { refresh() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { refresh() }
        }
    }

    // MARK: - Helpers

    private func refresh() {
        viewModel.generateDoseRecordsForToday(medications: medications)
        viewModel.reconcileMissedDoses(records: todayRecords)
        NotificationManager.shared.resetBadge()
        checkNotificationPermission()
    }

    private func checkNotificationPermission() {
        NotificationManager.shared.checkAuthorizationStatus { status in
            notificationsDenied = status == .denied
        }
    }

    // MARK: - Notification denied banner

    private var notificationBanner: some View {
        HStack {
            Image(systemName: "bell.slash.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications are disabled")
                    .font(.body.weight(.semibold))
                Text("Tap to enable in Settings")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .frame(minHeight: A11y.minRowHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
        .accessibilityLabel("Notifications disabled. Tap to open Settings.")
        .listRowBackground(Color.orange.opacity(0.12))
    }
}
