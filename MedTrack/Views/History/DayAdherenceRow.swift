import SwiftUI

struct DayAdherenceRow: View {
    let summary: DaySummary

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(DateHelpers.dayFormatter.string(from: summary.date))
                    .font(A11y.labelFont)
                    .foregroundStyle(.primary)

                Text("\(summary.taken) of \(summary.total) doses taken")
                    .font(A11y.bodyFont)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Color-coded adherence indicator
            Text(percentLabel)
                .font(A11y.actionFont)
                .foregroundStyle(indicatorColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(indicatorColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(.vertical, 8)
        .frame(minHeight: A11y.minRowHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(DateHelpers.dayFormatter.string(from: summary.date)), \(summary.taken) of \(summary.total) doses taken, \(percentLabel)"
        )
    }

    private var percentLabel: String {
        "\(Int(summary.adherenceRatio * 100))%"
    }

    private var indicatorColor: Color {
        switch summary.adherenceColor {
        case .good: return .green
        case .fair: return .orange
        case .poor: return .red
        }
    }
}
