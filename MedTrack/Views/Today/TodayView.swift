import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PillBoxState.self) private var pillBox

    @Binding var selectedTab: Int

    @Query(sort: \Medication.name) private var medications: [Medication]
    @Query private var allRecords: [DoseRecord]

    @State private var activeDoseRecord: DoseRecord? = nil
    @State private var dispensingRecord: DoseRecord? = nil
    @State private var confirmToast = false
    @State private var confirmMedName = ""
    @State private var notificationsDenied = false

    private var viewModel: TodayViewModel { TodayViewModel(context: context) }

    private var todayRecords: [DoseRecord] {
        let today = DateHelpers.startOfDay()
        return allRecords
            .filter { DateHelpers.isSameDay($0.scheduledDate, today) }
            .sorted { $0.scheduledTime < $1.scheduledTime }
    }

    private var takenCount: Int  { todayRecords.filter { $0.status == .taken }.count }
    private var totalCount: Int  { todayRecords.count }
    private var progress: Double { totalCount > 0 ? Double(takenCount) / Double(totalCount) : 0 }
    private var upNextRecord: DoseRecord? { todayRecords.first { $0.status == .pending } }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.dsBackground.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    headerSection
                    progressCard
                    pillBoxCard
                    scheduleSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
        }
        // Reminder banner overlay
        .overlay(alignment: .top) {
            if let record = activeDoseRecord, dispensingRecord == nil {
                ReminderBannerView(
                    record: record,
                    pillColor: pillColorFor(record),
                    pillShape: pillShapeFor(record),
                    onDispense: {
                        dispensingRecord = record
                        withAnimation(.spring(response: 0.3)) { activeDoseRecord = nil }
                    },
                    onSnooze: {
                        withAnimation(.spring(response: 0.3)) { activeDoseRecord = nil }
                    }
                )
                .padding(.top, 16)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(.spring(response: 0.4), value: activeDoseRecord?.id)
        // Dispense full-screen flow
        .fullScreenCover(item: $dispensingRecord) { record in
            DispenseView(
                record: record,
                pillColor: pillColorFor(record),
                pillShape: pillShapeFor(record)
            ) {
                dispensingRecord = nil
                viewModel.markTaken(record)
                confirmMedName = record.medication?.name ?? "Medication"
                withAnimation { confirmToast = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
                    withAnimation { confirmToast = false }
                }
            }
        }
        // Confirmation toast
        .overlay(alignment: .bottom) {
            if confirmToast { toastView }
        }
        .onAppear { refresh() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { refresh() }
        }
    }

    // MARK: - Greeting section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.system(size: 17 * dsScale, weight: .medium))
                .foregroundStyle(Color.dsInk2)

            // "Today, Thursday" — day name in accent italic
            (Text("Today, ") + Text(dayName).italic().foregroundStyle(Color.dsAccent))
                .font(.system(size: 34 * dsScale, design: .serif))
                .foregroundStyle(Color.dsInk)

            Text(dateSubtitle)
                .font(.system(size: 15 * dsScale))
                .foregroundStyle(Color.dsInk3)

            if notificationsDenied {
                notificationBanner
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    // MARK: - Progress ring card

    private var progressCard: some View {
        HStack(spacing: 18) {
            ProgressRingView(value: progress, size: 74)

            VStack(alignment: .leading, spacing: 2) {
                Text("Today's progress")
                    .font(.system(size: 13 * dsScale, weight: .semibold))
                    .foregroundStyle(Color.dsInk3)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Text("\(takenCount) of \(totalCount) taken")
                    .font(.system(size: 22 * dsScale, weight: .semibold))
                    .foregroundStyle(Color.dsInk)

                if let next = upNextRecord {
                    Text("Next: \(DateHelpers.timeFormatter.string(from: next.scheduledTime))")
                        .font(.system(size: 14 * dsScale))
                        .foregroundStyle(Color.dsInk3)
                } else if takenCount == totalCount && totalCount > 0 {
                    Text("All done for today!")
                        .font(.system(size: 14 * dsScale))
                        .foregroundStyle(Color.dsSuccess)
                }
            }

            Spacer()
        }
        .padding(22)
        .background(Color.dsCard)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.dsLine, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        .padding(.bottom, 14)
    }

    // MARK: - PillBox status card

    private var pillBoxCard: some View {
        Button {
            withAnimation { selectedTab = 2 }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(pillBox.connected ? Color.dsAccentSoft : Color(hex: "#EEE9E2"))
                        .frame(width: 52, height: 52)
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(pillBox.connected ? Color.dsAccent : Color.dsInk3)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(pillBox.connected ? "PillBox connected" : "PillBox offline")
                        .font(.system(size: 16 * dsScale, weight: .semibold))
                        .foregroundStyle(Color.dsInk)

                    Text(pillBox.connected
                         ? "\(pillBox.battery)% battery · \(pillBox.daysRemaining) days loaded"
                         : "Tap to reconnect")
                        .font(.system(size: 13 * dsScale))
                        .foregroundStyle(Color.dsInk3)
                }

                Spacer()

                Circle()
                    .fill(pillBox.connected ? Color.dsSuccess : Color.dsInk3)
                    .frame(width: 10, height: 10)
                    .shadow(color: pillBox.connected ? Color.dsSuccess.opacity(0.35) : .clear,
                            radius: 4)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .buttonStyle(.plain)
        .background(Color.dsCard)
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.dsLine, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
        .padding(.bottom, 28)
    }

    // MARK: - Schedule list

    @ViewBuilder
    private var scheduleSection: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Today's Schedule")
                    .font(.system(size: 13 * dsScale, weight: .semibold))
                    .foregroundStyle(Color.dsInk3)
                    .textCase(.uppercase)
                    .tracking(0.5)
                Spacer()
            }
            .padding(.leading, 4)

            if todayRecords.isEmpty {
                Text(medications.isEmpty
                     ? "Add medications in the Schedule tab."
                     : "No doses scheduled for today.")
                    .font(.system(size: 15 * dsScale))
                    .foregroundStyle(Color.dsInk3)
                    .multilineTextAlignment(.center)
                    .padding(.top, 20)
            } else {
                ForEach(todayRecords) { record in
                    MedRowView(
                        record: record,
                        isUpNext: record.id == upNextRecord?.id,
                        pillColor: pillColorFor(record),
                        pillShape: pillShapeFor(record)
                    ) {
                        guard record.status == .pending else { return }
                        withAnimation(.spring(response: 0.4)) {
                            activeDoseRecord = record
                        }
                    }
                }
            }
        }
    }

    // MARK: - Toast

    private var toastView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.dsSuccess)
            Text("\(confirmMedName) recorded · caregiver notified")
                .font(.system(size: 15, weight: .medium))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(Color.dsInk)
        .foregroundStyle(.white)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 6)
        .padding(.bottom, 110)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Notification denied banner

    private var notificationBanner: some View {
        HStack {
            Image(systemName: "bell.slash.fill").foregroundStyle(Color.dsWarning)
            VStack(alignment: .leading, spacing: 1) {
                Text("Notifications disabled")
                    .font(.system(size: 15 * dsScale, weight: .semibold))
                    .foregroundStyle(Color.dsInk)
                Text("Tap to enable in Settings")
                    .font(.system(size: 13 * dsScale))
                    .foregroundStyle(Color.dsInk3)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.dsWarning.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.dsWarning.opacity(0.3), lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
        .accessibilityLabel("Notifications disabled. Tap to open Settings.")
    }

    // MARK: - Helpers

    private func refresh() {
        viewModel.generateDoseRecordsForToday(medications: medications)
        viewModel.reconcileMissedDoses(records: todayRecords)
        NotificationManager.shared.resetBadge()
        NotificationManager.shared.checkAuthorizationStatus { status in
            notificationsDenied = status == .denied
        }
    }

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default:       return "Good evening"
        }
    }

    private var dayName: String {
        let f = DateFormatter(); f.dateFormat = "EEEE"
        return f.string(from: Date())
    }

    private var dateSubtitle: String {
        let f = DateFormatter(); f.dateFormat = "MMMM d"
        let d = f.string(from: Date())
        guard totalCount > 0 else { return d }
        return "\(d) · \(takenCount) of \(totalCount) meds so far"
    }

    private func medIndex(for record: DoseRecord) -> Int {
        guard let med = record.medication else { return 0 }
        return medications.firstIndex(where: { $0.id == med.id }) ?? 0
    }

    private func pillColorFor(_ record: DoseRecord) -> Color {
        Color.pillPalette[medIndex(for: record) % Color.pillPalette.count]
    }

    private func pillShapeFor(_ record: DoseRecord) -> PillShapeType {
        PillShapeType.forIndex(medIndex(for: record))
    }
}
