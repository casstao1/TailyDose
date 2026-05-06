import SwiftData
import SwiftUI
import UIKit

struct MedicationsView: View {
    @Query(sort: \PetProfile.name) private var pets: [PetProfile]
    @State private var editingMedicationTarget: MedicationEditingTarget?

    var body: some View {
        NavigationStack {
            ZStack {
                PetBackgroundView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PlushCard {
                            VStack(alignment: .leading, spacing: 12) {
                                SectionHeading(eyebrow: "Medication Desk", title: "Multiple pets, multiple medications")
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
                                            ForEach(pet.sortedMedications) { medication in
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
                                                .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                                .onTapGesture {
                                                    editingMedicationTarget = MedicationEditingTarget(pet: pet, medication: medication)
                                                }
                                                .accessibilityElement(children: .combine)
                                                .accessibilityAddTraits(.isButton)
                                                .accessibilityHint("Opens the editor for this medication")
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
        .sheet(item: $editingMedicationTarget) { target in
            MedicationEditorView(pet: target.pet, medication: target.medication)
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

private struct IdentifiableDate: Identifiable {
    var id = UUID()
    var date: Date
}

private struct MedicationEditingTarget: Identifiable {
    let pet: PetProfile
    let medication: MedicationSchedule

    var id: PersistentIdentifier {
        medication.persistentModelID
    }
}

struct MedicationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Query(sort: \PetProfile.name) private var allPets: [PetProfile]

    let pet: PetProfile
    let medication: MedicationSchedule?

    @StateObject private var reminderManager = ReminderManager.shared
    @State private var name: String
    @State private var dosage: String
    @State private var directions: String
    @State private var startDate: Date
    @State private var hasCourseEndDate: Bool
    @State private var courseEndDate: Date
    @State private var remainingDosesText: String
    @State private var reminderEnabled: Bool
    @State private var reminderDates: [IdentifiableDate]
    @State private var showingPaywall = false
    @State private var showingNotificationSettingsAlert = false

    init(pet: PetProfile, medication: MedicationSchedule? = nil) {
        self.pet = pet
        self.medication = medication
        _name = State(initialValue: medication?.name ?? "")
        _dosage = State(initialValue: medication?.dosage ?? "")
        _directions = State(initialValue: medication?.directions ?? "")
        _startDate = State(initialValue: medication?.startDate ?? .now)
        _hasCourseEndDate = State(initialValue: medication?.courseEndDate != nil)
        let defaultStartDate = medication?.startDate ?? .now
        _courseEndDate = State(initialValue: medication?.courseEndDate ?? Calendar.current.date(byAdding: .day, value: 30, to: defaultStartDate) ?? .now)
        _remainingDosesText = State(initialValue: medication?.remainingDoses.map(String.init) ?? "")
        _reminderEnabled = State(initialValue: medication?.reminderEnabled ?? false)
        _reminderDates = State(initialValue: {
            if let medication {
                return medication.reminderTimes.map {
                    IdentifiableDate(date: Calendar.current.date(bySettingHour: $0.hour, minute: $0.minute, second: 0, of: .now) ?? .now)
                }
            }
            return [
                IdentifiableDate(date: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now)
            ]
        }())
    }

    /// Validates the "Doses remaining" input. Returns `nil` if the value is
    /// acceptable (empty, or a non-negative integer), or an error message to
    /// show the user when it isn't.
    private var remainingDosesError: String? {
        let trimmed = remainingDosesText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        guard let parsed = Int(trimmed) else {
            return "Enter a whole number, or leave blank."
        }
        if parsed < 0 {
            return "Doses remaining can't be negative."
        }
        return nil
    }

    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !dosage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && remainingDosesError == nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PetBackgroundView()

                Form {
                    Section("Medication") {
                        TextField("Medication name", text: $name)
                        TextField("Dosage", text: $dosage)
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Doses remaining", text: $remainingDosesText)
                                .keyboardType(.numberPad)
                                .onChange(of: remainingDosesText) { _, newValue in
                                    // Strip anything that isn't a digit so paste/autofill
                                    // can't slip letters past the number-pad keyboard.
                                    let filtered = newValue.filter(\.isNumber)
                                    if filtered != newValue {
                                        remainingDosesText = filtered
                                    }
                                }
                            if let message = remainingDosesError {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                    .accessibilityLabel("Doses remaining error: \(message)")
                            }
                        }
                        TextField("Directions", text: $directions, axis: .vertical)
                            .lineLimit(3...5)
                        DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        Toggle("Set course end date", isOn: $hasCourseEndDate)
                        if hasCourseEndDate {
                            DatePicker("Course End", selection: $courseEndDate, in: startDate..., displayedComponents: .date)
                        }
                    }

                    Section("Reminders") {
                        if subscriptionManager.hasActiveSubscription {
                            Toggle("Enable push alerts", isOn: $reminderEnabled)
                        } else {
                            PlushCard(tint: PetTheme.petMint, compact: true) {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("Push reminder alerts are part of TailyDose Pro", systemImage: "bell.badge.fill")
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(PetTheme.accentDeep)

                                    Text("Your medication times will still appear on the dashboard, but push alerts require Pro.")
                                        .font(.footnote)
                                        .foregroundStyle(PetTheme.ink.opacity(0.82))

                                    Button {
                                        showingPaywall = true
                                    } label: {
                                        Label("Unlock Push Alerts", systemImage: "bell.badge.fill")
                                    }
                                    .buttonStyle(PrimaryPillButtonStyle(compact: true))
                                }
                            }
                        }

                        ForEach(Array(reminderDates.enumerated()), id: \.element.id) { index, entry in
                            ReminderTimeRow(
                                title: "Time \(index + 1)",
                                selection: $reminderDates[index].date,
                                onDelete: {
                                    reminderDates.removeAll { $0.id == entry.id }
                                }
                            )
                        }

                        Button {
                            reminderDates.append(IdentifiableDate(date: Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now) ?? .now))
                        } label: {
                            Label("Add Reminder Time", systemImage: "plus.circle.fill")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(medication == nil ? "New Medication" : "Edit Medication")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isFormValid)
                }
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showingPaywall) {
            ProPaywallView(context: .reminders)
        }
        .task {
            await reminderManager.refreshStatus()
        }
        .onChange(of: reminderEnabled) { _, isEnabled in
            guard subscriptionManager.hasActiveSubscription, isEnabled else { return }
            handleReminderToggleEnabled()
        }
        .alert("Allow Notifications", isPresented: $showingNotificationSettingsAlert) {
            Button("Open Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                openURL(url)
            }
            Button("Not Now", role: .cancel) {
                reminderEnabled = false
            }
        } message: {
            Text("Enable notifications in Settings so TailyDose can send push medication alerts.")
        }
    }

    private func handleReminderToggleEnabled() {
        Task { @MainActor in
            await reminderManager.refreshStatus()

            switch reminderManager.status {
            case .notDetermined:
                await reminderManager.requestAuthorization()
                if ![.authorized, .provisional, .ephemeral].contains(reminderManager.status) {
                    reminderEnabled = false
                }
            case .denied:
                reminderEnabled = false
                showingNotificationSettingsAlert = true
            case .authorized, .provisional, .ephemeral:
                break
            @unknown default:
                reminderEnabled = false
            }
        }
    }

    private func save() {
        Task { @MainActor in
            let canEnablePushAlerts = await ensurePushAlertsReadyForSave()
            persistMedication(allowPushAlerts: canEnablePushAlerts)
        }
    }

    private func ensurePushAlertsReadyForSave() async -> Bool {
        guard subscriptionManager.hasActiveSubscription, reminderEnabled else { return false }

        await reminderManager.refreshStatus()

        switch reminderManager.status {
        case .notDetermined:
            await reminderManager.requestAuthorization()
            await reminderManager.refreshStatus()
            if ![.authorized, .provisional, .ephemeral].contains(reminderManager.status) {
                reminderEnabled = false
                return false
            }
            return true
        case .denied:
            reminderEnabled = false
            showingNotificationSettingsAlert = true
            return false
        case .authorized, .provisional, .ephemeral:
            return true
        @unknown default:
            reminderEnabled = false
            return false
        }
    }

    private func persistMedication(allowPushAlerts: Bool) {
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
        let trimmedRemaining = remainingDosesText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedRemaining.isEmpty {
            // User intentionally cleared the field.
            target.remainingDoses = nil
        } else if let parsed = Int(trimmedRemaining), parsed >= 0 {
            target.remainingDoses = parsed
        }
        // Validation in `isFormValid` prevents reaching this with a non-empty,
        // unparseable, or negative value, so no fallback branch is needed.
        target.reminderEnabled = allowPushAlerts
        target.reminderTimes = reminderDates.map {
            let components = Calendar.current.dateComponents([.hour, .minute], from: $0.date)
            return ReminderTime(hour: components.hour ?? 8, minute: components.minute ?? 0)
        }

        if medication == nil {
            target.pet = pet
            pet.medications.append(target)
            modelContext.insert(target)
        }

        try? modelContext.save()
        let petsToSync = allPets.contains(where: { $0.id == pet.id }) ? allPets : allPets + [pet]
        Task { @MainActor in
            if subscriptionManager.hasActiveSubscription {
                await reminderManager.syncNotifications(pets: petsToSync)
            } else {
                reminderManager.clearNotifications()
            }
        }
        dismiss()
    }
}

private struct ReminderTimeRow: View {
    let title: String
    let selection: Binding<Date>
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .foregroundStyle(Color.primary)

            Spacer()

            DatePicker(
                "",
                selection: selection,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .tint(PetTheme.ink)
        }
        .contentShape(Rectangle())
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .tint(.red)
            .accessibilityLabel("Delete reminder time")
        }
    }
}
