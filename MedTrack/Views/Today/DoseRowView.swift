import SwiftUI

struct DoseRowView: View {
    let record: DoseRecord
    let onMarkTaken: () -> Void

    private var medName: String { record.medication?.name ?? "Unknown" }
    private var doseLabel: String {
        guard let med = record.medication else { return "" }
        return "\(med.dosage) \(med.unit)"
    }
    private var timeLabel: String {
        DateHelpers.timeFormatter.string(from: record.scheduledTime)
    }

    var body: some View {
        HStack(spacing: 16) {
            // Status icon
            Image(systemName: statusIcon)
                .font(.title)
                .foregroundStyle(statusColor)
                .frame(width: 36)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(medName)
                    .font(A11y.labelFont)
                    .foregroundStyle(.primary)
                Text("\(doseLabel) · \(timeLabel)")
                    .font(A11y.bodyFont)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if record.status == .pending {
                Button(action: onMarkTaken) {
                    Text("Taken")
                        .font(A11y.actionFont)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.green, in: RoundedRectangle(cornerRadius: 12))
                }
                .accessibilityLabel("Mark \(medName) as taken")
                .accessibilityHint("Records that you took this dose at \(timeLabel)")
            }
        }
        .padding(.vertical, 8)
        .frame(minHeight: A11y.minRowHeight)
        .accessibilityElement(children: .combine)
    }

    private var statusIcon: String {
        switch record.status {
        case .pending: return "circle"
        case .taken:   return "checkmark.circle.fill"
        case .missed:  return "xmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch record.status {
        case .pending: return .gray
        case .taken:   return .green
        case .missed:  return .red
        }
    }
}
