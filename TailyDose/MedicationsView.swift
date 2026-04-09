import SwiftData
import SwiftUI

struct MedicationsView: View {
    @Query(sort: \PetProfile.name) private var pets: [PetProfile]

    var body: some View {
        NavigationStack {
            ZStack {
                PetBackgroundView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PlushCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeading(eyebrow: "Medication Desk", title: "Multiple pets, multiple meds")
                                Text("Every medication stores dosage, directions, start date, and one or more reminder times locally.")
                                    .font(.subheadline)
                                    .foregroundStyle(PetTheme.muted)
                            }
                        }

                        if pets.isEmpty {
                            PlushCard {
                                Text("Add a pet on the Home tab first.")
                                    .foregroundStyle(PetTheme.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        } else {
                            ForEach(pets) { pet in
                                PlushCard(tint: pet.moodStyle.tint) {
                                    VStack(alignment: .leading, spacing: 14) {
                                        Label(pet.name, systemImage: pet.kind.symbol)
                                            .font(.title3.bold())
                                            .foregroundStyle(PetTheme.ink)

                                        if pet.medications.isEmpty {
                                            Text("No medications added yet.")
                                                .font(.footnote)
                                                .foregroundStyle(PetTheme.muted)
                                        } else {
                                            ForEach(pet.activeMedications) { medication in
                                                VStack(alignment: .leading, spacing: 8) {
                                                    Text("\(medication.dosage) \(medication.name)")
                                                        .font(.headline)
                                                        .foregroundStyle(PetTheme.ink)
                                                    Text(medication.directions)
                                                        .font(.footnote)
                                                        .foregroundStyle(PetTheme.muted)
                                                    if let refillLine = refillLine(for: medication) {
                                                        Text(refillLine)
                                                            .font(.caption)
                                                            .foregroundStyle(PetTheme.accentDeep)
                                                    }
                                                    if let courseLine = courseLine(for: medication) {
                                                        Text(courseLine)
                                                            .font(.caption)
                                                            .foregroundStyle(PetTheme.muted)
                                                    }
                                                    Text(medication.reminderTimes.map(\.label).joined(separator: ", "))
                                                        .font(.caption)
                                                        .foregroundStyle(PetTheme.accent)
                                                }
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .padding(14)
                                                .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Medications")
        }
    }

    private func refillLine(for medication: MedicationSchedule) -> String? {
        guard let remaining = medication.remainingDoses else { return nil }
        if let days = medication.estimatedDaysRemaining {
            return "\(remaining) doses left • about \(days) day\(days == 1 ? "" : "s") remaining"
        }
        return "\(remaining) doses left"
    }

    private func courseLine(for medication: MedicationSchedule) -> String? {
        guard let courseEndDate = medication.courseEndDate else { return nil }
        return "Course ends \(courseEndDate.formatted(date: .abbreviated, time: .omitted))"
    }
}

struct MedicationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let pet: PetProfile
    let medication: MedicationSchedule?

    @State private var name: String
    @State private var dosage: String
    @State private var directions: String
    @State private var startDate: Date
    @State private var hasCourseEndDate: Bool
    @State private var courseEndDate: Date
    @State private var remainingDosesText: String
    @State private var reminderEnabled: Bool
    @State private var reminderDates: [Date]

    init(pet: PetProfile, medication: MedicationSchedule? = nil) {
        self.pet = pet
        self.medication = medication
        _name = State(initialValue: medication?.name ?? "")
        _dosage = State(initialValue: medication?.dosage ?? "")
        _directions = State(initialValue: medication?.directions ?? "")
        _startDate = State(initialValue: medication?.startDate ?? .now)
        _hasCourseEndDate = State(initialValue: medication?.courseEndDate != nil)
        _courseEndDate = State(initialValue: medication?.courseEndDate ?? .now)
        _remainingDosesText = State(initialValue: medication?.remainingDoses.map(String.init) ?? "")
        _reminderEnabled = State(initialValue: medication?.reminderEnabled ?? true)
        _reminderDates = State(initialValue: {
            if let medication {
                return medication.reminderTimes.map {
                    Calendar.current.date(bySettingHour: $0.hour, minute: $0.minute, second: 0, of: .now) ?? .now
                }
            }
            return [
                Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now
            ]
        }())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Medication name", text: $name)
                    TextField("Dosage", text: $dosage)
                    TextField("Doses remaining", text: $remainingDosesText)
                        .keyboardType(.numberPad)
                    TextField("Directions", text: $directions, axis: .vertical)
                        .lineLimit(3...5)
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                    Toggle("Set course end date", isOn: $hasCourseEndDate)
                    if hasCourseEndDate {
                        DatePicker("Course End", selection: $courseEndDate, in: startDate..., displayedComponents: .date)
                    }
                }

                Section("Reminders") {
                    Toggle("Enable alerts", isOn: $reminderEnabled)

                    ForEach(reminderDates.indices, id: \.self) { index in
                        DatePicker(
                            "Time \(index + 1)",
                            selection: binding(for: index),
                            displayedComponents: .hourAndMinute
                        )
                    }

                    Button {
                        reminderDates.append(Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now) ?? .now)
                    } label: {
                        Label("Add Reminder Time", systemImage: "plus.circle.fill")
                    }

                    if reminderDates.count > 1 {
                        Button("Remove Last Time", role: .destructive) {
                            _ = reminderDates.popLast()
                        }
                    }
                }
            }
            .navigationTitle(medication == nil ? "New Medication" : "Edit Medication")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func binding(for index: Int) -> Binding<Date> {
        Binding {
            reminderDates[index]
        } set: { newValue in
            reminderDates[index] = newValue
        }
    }

    private func save() {
        let target = medication ?? MedicationSchedule(
            name: name,
            dosage: dosage,
            directions: directions,
            startDate: startDate
        )
        target.name = name
        target.dosage = dosage
        target.directions = directions
        target.startDate = startDate
        target.courseEndDate = hasCourseEndDate ? courseEndDate : nil
        target.remainingDoses = Int(remainingDosesText.trimmingCharacters(in: .whitespacesAndNewlines))
        target.reminderEnabled = reminderEnabled
        target.reminderTimes = reminderDates.map {
            let components = Calendar.current.dateComponents([.hour, .minute], from: $0)
            return ReminderTime(hour: components.hour ?? 8, minute: components.minute ?? 0)
        }

        if medication == nil {
            target.pet = pet
            pet.medications.append(target)
            modelContext.insert(target)
        }

        try? modelContext.save()
        dismiss()
    }
}
