import SwiftUI
import SwiftData
import AVFoundation

struct MedicationFormView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Pass nil to create a new medication; pass an existing one to edit.
    let medication: Medication?

    @State private var name: String = ""
    @State private var dosage: String = ""
    @State private var unit: String = "mg"
    @State private var scheduledTimes: [Date] = []

    @State private var showingScanner = false
    @State private var isLookingUp = false
    @State private var lookupError: String?

    private let unitOptions = ["mg", "ml", "tablet", "capsule", "drop", "patch"]

    private var isEditing: Bool { medication != nil }
    private var title: String { isEditing ? "Edit Medication" : "Add Medication" }
    private var store: MedicationStore { MedicationStore(context: context) }
    private var cameraAvailable: Bool {
        AVCaptureDevice.default(for: .video) != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                // Scan button — only shown when creating a new medication
                if !isEditing {
                    Section {
                        Button {
                            lookupError = nil
                            showingScanner = true
                        } label: {
                            HStack {
                                if isLookingUp {
                                    ProgressView()
                                        .padding(.trailing, 4)
                                    Text("Looking up drug…")
                                        .font(A11y.actionFont)
                                } else {
                                    Label("Scan Medicine Barcode", systemImage: "barcode.viewfinder")
                                        .font(A11y.actionFont)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: A11y.minRowHeight)
                        }
                        .disabled(isLookingUp)
                        .accessibilityLabel("Scan medicine package barcode to auto-fill details")

                        if let error = lookupError {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text(error)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Button {
                                    lookupError = nil
                                } label: {
                                    Image(systemName: "xmark")
                                        .foregroundStyle(.secondary)
                                }
                                .accessibilityLabel("Dismiss error")
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                Section("Medication Details") {
                    LabeledContent("Name") {
                        TextField("e.g. Metformin", text: $name)
                            .multilineTextAlignment(.trailing)
                            .font(A11y.bodyFont)
                    }
                    .frame(minHeight: A11y.minRowHeight)

                    LabeledContent("Dosage") {
                        TextField("e.g. 500", text: $dosage)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(A11y.bodyFont)
                    }
                    .frame(minHeight: A11y.minRowHeight)

                    Picker("Unit", selection: $unit) {
                        ForEach(unitOptions, id: \.self) { Text($0) }
                    }
                    .font(A11y.bodyFont)
                    .frame(minHeight: A11y.minRowHeight)
                }

                Section("Daily Schedule") {
                    ForEach(scheduledTimes.indices, id: \.self) { index in
                        HStack {
                            DatePicker(
                                "Time \(index + 1)",
                                selection: $scheduledTimes[index],
                                displayedComponents: .hourAndMinute
                            )
                            .font(A11y.bodyFont)
                            .frame(minHeight: A11y.minRowHeight)

                            Button(role: .destructive) {
                                scheduledTimes.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .accessibilityLabel("Remove time \(index + 1)")
                        }
                    }

                    Button {
                        scheduledTimes.append(defaultNewTime())
                    } label: {
                        Label("Add Time", systemImage: "plus.circle.fill")
                            .font(A11y.actionFont)
                            .frame(minHeight: A11y.minRowHeight)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(A11y.bodyFont)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .font(A11y.bodyFont)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isLookingUp)
                }
            }
            .onAppear { loadExistingValues() }
            .sheet(isPresented: $showingScanner) {
                BarcodeScannerView { barcode in
                    showingScanner = false
                    Task { await lookupDrug(barcode: barcode) }
                }
            }
        }
    }

    // MARK: - Barcode lookup

    private func lookupDrug(barcode: String) async {
        isLookingUp = true
        lookupError = nil
        do {
            let info = try await DrugLookupService.lookup(barcode: barcode)
            name = info.name
            dosage = info.dosage
            unit = unitOptions.contains(info.unit) ? info.unit : "mg"
        } catch let error as DrugLookupError {
            lookupError = error.errorDescription
        } catch {
            lookupError = "Something went wrong. Please fill in manually."
        }
        isLookingUp = false
    }

    // MARK: - Helpers

    private func loadExistingValues() {
        guard let med = medication else { return }
        name = med.name
        dosage = med.dosage
        unit = med.unit
        scheduledTimes = med.scheduledTimes
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let med = medication {
            store.update(med, name: trimmedName, dosage: dosage, unit: unit, scheduledTimes: scheduledTimes)
        } else {
            store.add(name: trimmedName, dosage: dosage, unit: unit, scheduledTimes: scheduledTimes)
        }
        dismiss()
    }

    /// Returns 8:00 AM today as a sensible default for a new time slot.
    private func defaultNewTime() -> Date {
        DateHelpers.calendar.date(
            bySettingHour: 8, minute: 0, second: 0, of: Date()
        ) ?? Date()
    }
}
