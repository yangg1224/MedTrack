import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query private var allRecords: [DoseRecord]
    @StateObject private var viewModel = HistoryViewModel()

    var body: some View {
        Group {
            if viewModel.summaries.isEmpty {
                ContentUnavailableView(
                    "No History Yet",
                    systemImage: "calendar",
                    description: Text("Your adherence record will appear here after your first day.")
                )
            } else {
                List(viewModel.summaries) { summary in
                    DayAdherenceRow(summary: summary)
                }
            }
        }
        .navigationTitle("History")
        .onAppear { viewModel.load(from: allRecords) }
        .onChange(of: allRecords.count) { _, _ in viewModel.load(from: allRecords) }
    }
}
