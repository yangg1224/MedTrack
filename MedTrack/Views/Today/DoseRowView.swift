import SwiftUI

struct MedRowView: View {
    let record: DoseRecord
    let isUpNext: Bool
    let pillColor: Color
    let pillShape: PillShapeType
    let onTap: () -> Void

    private var med: Medication? { record.medication }
    private var isTaken: Bool  { record.status == .taken }
    private var isMissed: Bool { record.status == .missed }
    private var timeLabel: String {
        DateHelpers.timeFormatter.string(from: record.scheduledTime)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Pill shape icon
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(pillColor.opacity(0.16))
                        .frame(width: 56, height: 56)
                    PillShapeView(color: pillColor, shape: pillShape)
                }

                // Text block
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(med?.name ?? "Medication")
                            .font(.system(size: 18 * dsScale, weight: .semibold))
                            .foregroundStyle(Color.dsInk)
                        Text(doseLabel)
                            .font(.system(size: 13 * dsScale))
                            .foregroundStyle(Color.dsInk3)
                    }
                    Text(instructionText)
                        .font(.system(size: 14 * dsScale))
                        .foregroundStyle(Color.dsInk3)
                }

                Spacer(minLength: 4)

                // Time + status
                VStack(alignment: .trailing, spacing: 2) {
                    Text(timeLabel)
                        .font(.system(size: 17 * dsScale, weight: .semibold).monospacedDigit())
                        .foregroundStyle(isMissed ? Color.dsDanger : Color.dsInk)

                    statusChip
                }
            }
            .padding(18)
        }
        .buttonStyle(.plain)
        .background(Color.dsCard)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(
                    isUpNext ? Color.dsAccent : Color.dsLine,
                    lineWidth: isUpNext ? 2 : 1
                )
        )
        .shadow(
            color: isUpNext ? Color.dsAccent.opacity(0.14) : .black.opacity(0.04),
            radius: isUpNext ? 8 : 4,
            x: 0, y: 2
        )
        .opacity(isTaken ? 0.7 : 1)
        .frame(minHeight: 60)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var statusChip: some View {
        switch record.status {
        case .taken:
            HStack(spacing: 3) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                Text("Taken")
                    .font(.system(size: 12 * dsScale, weight: .semibold))
            }
            .foregroundStyle(Color.dsSuccess)
        case .missed:
            Text("Missed")
                .font(.system(size: 12 * dsScale, weight: .semibold))
                .foregroundStyle(Color.dsDanger)
        case .pending:
            Text(isUpNext ? "Up next" : "Scheduled")
                .font(.system(size: 12 * dsScale, weight: isUpNext ? .semibold : .medium))
                .foregroundStyle(isUpNext ? Color.dsAccent : Color.dsInk3)
        }
    }

    private var doseLabel: String {
        guard let m = med else { return "" }
        return "\(m.dosage) \(m.unit)"
    }

    // Friendly one-liner derived from medication name
    private var instructionText: String {
        let name = med?.name.lowercased() ?? ""
        if name.contains("lisinopril")   { return "Blood pressure · with water" }
        if name.contains("metformin")    { return "Diabetes · with breakfast" }
        if name.contains("atorvastatin") { return "Cholesterol · with water" }
        if name.contains("aspirin")      { return "Heart health · with food" }
        if name.contains("donepezil")    { return "Memory · evening only" }
        if name.contains("vitamin d")    { return "With breakfast" }
        if name.contains("vitamin")      { return "With a meal" }
        if name.contains("calcium")      { return "With dinner" }
        if name.contains("omega")        { return "With a meal" }
        return "Take as directed"
    }

    private var accessibilityLabel: String {
        "\(med?.name ?? "Medication"), \(doseLabel), scheduled at \(timeLabel), \(record.status.rawValue)"
    }
}
