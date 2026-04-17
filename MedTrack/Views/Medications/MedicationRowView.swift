import SwiftUI

struct MedicationRowView: View {
    let medication: Medication

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(medication.name)
                .font(A11y.labelFont)
                .foregroundStyle(.primary)

            Text("\(medication.dosage) \(medication.unit)")
                .font(A11y.bodyFont)
                .foregroundStyle(.secondary)

            if !medication.scheduledTimes.isEmpty {
                Text(timesLabel)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .frame(minHeight: A11y.minRowHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(medication.name), \(medication.dosage) \(medication.unit), scheduled at \(timesLabel)")
    }

    private var timesLabel: String {
        medication.scheduledTimes
            .sorted()
            .map { DateHelpers.timeFormatter.string(from: $0) }
            .joined(separator: ", ")
    }
}
