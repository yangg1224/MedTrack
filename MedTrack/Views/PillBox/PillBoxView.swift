import SwiftUI

struct PillBoxView: View {
    @Environment(PillBoxState.self) private var pillBox
    @State private var scanning = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.dsBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        illustrationCard
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                            .padding(.bottom, 20)

                        statsGrid
                            .padding(.horizontal, 20)
                            .padding(.bottom, 22)

                        deviceSection
                            .padding(.horizontal, 20)

                        if !pillBox.connected {
                            reconnectButton
                                .padding(.horizontal, 20)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("PillBox")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Illustration card

    private var illustrationCard: some View {
        ZStack {
            LinearGradient(
                colors: [Color.dsAccentSoft, Color.dsBackground],
                startPoint: .top, endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.dsLine, lineWidth: 1))

            VStack(spacing: 18) {
                PillBoxIllustrationView(connected: pillBox.connected)

                VStack(spacing: 4) {
                    Text("PillBox Home")
                        .font(.system(size: 26 * dsScale, weight: .regular, design: .serif))
                        .foregroundStyle(Color.dsInk)

                    Text("Serial · PB-4471-A")
                        .font(.system(size: 14 * dsScale))
                        .foregroundStyle(Color.dsInk3)
                }

                // Connection badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(pillBox.connected ? Color.dsSuccess : Color.dsWarning)
                        .frame(width: 8, height: 8)
                        .shadow(color: pillBox.connected ? Color.dsSuccess.opacity(0.4) : .clear,
                                radius: 3)

                    Text(scanning ? "Searching…" : (pillBox.connected ? "Connected" : "Disconnected"))
                        .font(.system(size: 13 * dsScale, weight: .semibold))
                        .foregroundStyle(pillBox.connected ? Color.dsSuccess : Color.dsInk2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(pillBox.connected ? Color(hex: "#DDEFDC") : Color(hex: "#F5E6DD"))
                .clipShape(Capsule())
            }
            .padding(.vertical, 32)
        }
    }

    // MARK: - Stats 2×2 grid

    private var statsGrid: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                StatCardView(label: "Battery",         value: "\(pillBox.battery)%")
                StatCardView(label: "Pills remaining", value: "\(pillBox.daysRemaining) days")
            }
            HStack(spacing: 10) {
                StatCardView(label: "Last dispensed", value: lastDispensedText)
                StatCardView(label: "Signal",         value: pillBox.signal)
            }
        }
    }

    // MARK: - Device controls

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Device")
                .font(.system(size: 13 * dsScale, weight: .semibold))
                .foregroundStyle(Color.dsInk3)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                DeviceRowView(label: "Test dispense",   detail: "Release one pill now")
                Divider().padding(.leading, 18)
                DeviceRowView(label: "Find my PillBox", detail: "Beep & light up")
                Divider().padding(.leading, 18)
                DeviceRowView(label: "Refill schedule", detail: "Every 14 days", isLast: true)
            }
            .background(Color.dsCard)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.dsLine, lineWidth: 1))
        }
        .padding(.bottom, 20)
    }

    // MARK: - Reconnect button

    private var reconnectButton: some View {
        Button {
            reconnect()
        } label: {
            Text(scanning ? "Searching…" : "Reconnect PillBox")
                .font(.system(size: 19 * dsScale, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
        }
        .background(Color.dsAccent)
        .clipShape(Capsule())
        .shadow(color: Color.dsAccent.opacity(0.4), radius: 10, x: 0, y: 5)
        .disabled(scanning)
    }

    // MARK: - Helpers

    private var lastDispensedText: String {
        guard let d = pillBox.lastDispensedAt else { return "—" }
        let f = DateFormatter()
        f.dateFormat = Calendar.current.isDateInToday(d) ? "'Today' h:mm a" : "MMM d h:mm a"
        return f.string(from: d)
    }

    private func reconnect() {
        scanning = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            pillBox.connected = true
            pillBox.lastDispensedAt = Date()
            scanning = false
        }
    }
}

// MARK: - Stat card

struct StatCardView: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12 * dsScale, weight: .semibold))
                .foregroundStyle(Color.dsInk3)
                .textCase(.uppercase)
                .tracking(0.3)

            Text(value)
                .font(.system(size: 19 * dsScale, weight: .semibold))
                .foregroundStyle(Color.dsInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.dsCard)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.dsLine, lineWidth: 1))
    }
}

// MARK: - Device setting row

struct DeviceRowView: View {
    let label: String
    let detail: String
    var isLast: Bool = false

    var body: some View {
        Button {
            // Placeholder action
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 16 * dsScale, weight: .medium))
                        .foregroundStyle(Color.dsInk)
                    Text(detail)
                        .font(.system(size: 13 * dsScale))
                        .foregroundStyle(Color.dsInk3)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.dsInk3)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(minHeight: 60)
        }
        .buttonStyle(.plain)
    }
}
