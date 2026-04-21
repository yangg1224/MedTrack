import SwiftUI

struct ReminderBannerView: View {
    let record: DoseRecord
    let pillColor: Color
    let pillShape: PillShapeType
    let onDispense: () -> Void
    let onSnooze: () -> Void

    @State private var pulsing = false

    private var med: Medication? { record.medication }
    private var timeLabel: String {
        DateHelpers.timeFormatter.string(from: record.scheduledTime)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header row
            HStack(spacing: 12) {
                // Pill icon with pulse ring
                ZStack {
                    Circle()
                        .stroke(Color.dsAccent, lineWidth: 2)
                        .frame(width: 48, height: 48)
                        .scaleEffect(pulsing ? 1.45 : 1.0)
                        .opacity(pulsing ? 0 : 0.55)
                        .animation(
                            .easeOut(duration: 1.5).repeatForever(autoreverses: false),
                            value: pulsing
                        )

                    Circle()
                        .fill(pillColor.opacity(0.18))
                        .frame(width: 48, height: 48)

                    PillShapeView(color: pillColor, shape: pillShape)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Time for your medication")
                        .font(.system(size: 12 * dsScale, weight: .bold))
                        .foregroundStyle(Color.dsAccent)
                        .textCase(.uppercase)
                        .tracking(1)

                    Text(med?.name ?? "Medication")
                        .font(.system(size: 22 * dsScale, weight: .medium, design: .serif))
                        .foregroundStyle(Color.dsInk)

                    Text("\(med?.dosage ?? "") \(med?.unit ?? "") · \(timeLabel)")
                        .font(.system(size: 13 * dsScale))
                        .foregroundStyle(Color.dsInk3)
                }
            }

            // Buttons
            HStack(spacing: 8) {
                Button(action: onSnooze) {
                    Text("Snooze 15m")
                        .font(.system(size: 15 * dsScale, weight: .semibold))
                        .foregroundStyle(Color.dsInk2)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .overlay(Capsule().stroke(Color.dsLine, lineWidth: 1.5))
                }
                .buttonStyle(.plain)

                Button(action: onDispense) {
                    Text("Dispense now")
                        .font(.system(size: 16 * dsScale, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.dsAccent)
                        .clipShape(Capsule())
                        .shadow(color: Color.dsAccent.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.dsCard)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.dsAccent, lineWidth: 2))
        .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 12)
        .onAppear { pulsing = true }
    }
}
