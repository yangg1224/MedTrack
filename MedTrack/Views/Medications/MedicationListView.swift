import SwiftUI
import SwiftData

struct MedicationListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Medication.name) private var medications: [Medication]

    @State private var showingForm = false
    @State private var selectedMedication: Medication?

    var body: some View {
        Group {
            if medications.isEmpty {
                ContentUnavailableView(
                    "No Medications",
                    systemImage: "pills",
                    description: Text("Tap + to add your first medication.")
                )
            } else {
                List {
                    ForEach(medications) { med in
                        Button {
                            selectedMedication = med
                        } label: {
                            MedicationRowView(medication: med)
                        }
                        .foregroundStyle(.primary)
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("My Medications")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    selectedMedication = nil
                    showingForm = true
                } label: {
                    Image(systemName: "plus")
                        .accessibilityLabel("Add medication")
                }
            }
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingForm) {
            MedicationFormView(medication: nil)
        }
        .sheet(item: $selectedMedication) { med in
            MedicationFormView(medication: med)
        }
    }

    private func delete(at offsets: IndexSet) {
        let store = MedicationStore(context: context)
        for index in offsets {
            store.delete(medications[index])
        }
    }
}
