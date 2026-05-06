import SwiftData
import SwiftUI
import PhotosUI
import UIKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Query(sort: \PetProfile.name) private var pets: [PetProfile]

    @ObservedObject var reminderManager: ReminderManager
    @State private var showingPetEditor = false
    @State private var editingPet: PetProfile?
    @State private var medicationPet: PetProfile?
    @State private var detailPet: PetProfile?
    @State private var showingPaywall = false
    @State private var paywallContext: PremiumGateContext = .multiPet
    @State private var pendingPetDeletion: PetProfile?

    private var allMeds: [MedicationSchedule] {
        pets.flatMap(\.medications)
    }

    private var activeMeds: [MedicationSchedule] {
        pets.flatMap { $0.activeMedications(on: .now) }
    }

    private var notificationCTA: (title: String, systemImage: String) {
        if reminderManager.status == .denied {
            return ("Open Notification Settings", "gearshape.fill")
        }
        return ("Enable Medication Alerts", "bell.fill")
    }

    var body: some View {
        ZStack {
            PetBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PlushCard {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeading(eyebrow: "Care Setup", title: "Pets & medications")

                            Text("Keep profiles tidy, reminders current, and medication details easy to update.")
                                .font(.subheadline)
                                .foregroundStyle(PetTheme.muted)

                            HStack(spacing: 12) {
                                TinyMetric(value: "\(pets.count)", label: "Pets", systemImage: "pawprint.fill")
                                TinyMetric(value: "\(activeMeds.count)", label: "Active Medications", systemImage: "pills.fill")
                            }
                        }
                    }

                    if subscriptionManager.hasActiveSubscription,
                       reminderManager.status != .authorized && reminderManager.status != .provisional && reminderManager.status != .ephemeral {
                        PlushCard {
                            Button {
                                handleNotificationAccessTapped()
                            } label: {
                                Label(notificationCTA.title, systemImage: notificationCTA.systemImage)
                                    .font(.headline)
                                    .foregroundStyle(PetTheme.accent)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    } else if !subscriptionManager.hasActiveSubscription {
                        PlushCard(tint: PetTheme.petMint) {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Reminder alerts are part of TailyDose Pro", systemImage: "bell.badge.fill")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(PetTheme.accentDeep)

                                Text("Upgrade to unlock push alerts, multiple pets, and clean vet export.")
                                    .font(.subheadline)
                                    .foregroundStyle(PetTheme.ink.opacity(0.82))

                                Button {
                                    openPaywall(.reminders)
                                } label: {
                                    Label("Unlock Pro", systemImage: "bell.badge.fill")
                                }
                                .buttonStyle(PrimaryPillButtonStyle())
                            }
                        }
                    }

                    SectionHeading(eyebrow: "Pets", title: "Your companions")

                    if pets.isEmpty {
                        PlushCard {
                            Button {
                                handleAddPetTapped()
                            } label: {
                                Label("Add Your First Pet", systemImage: "plus.circle.fill")
                            }
                            .buttonStyle(PrimaryPillButtonStyle())
                        }
                    } else {
                        ForEach(pets) { pet in
                            PlushCard(tint: pet.moodStyle.tint) {
                                HStack(alignment: .top, spacing: 14) {
                                    PetAvatarChip(pet: pet)

                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Text(pet.name)
                                                .font(.headline)
                                                .foregroundStyle(PetTheme.ink)

                                            Spacer()

                                            Menu {
                                                Button("Add Medication", systemImage: "pills.fill") {
                                                    medicationPet = pet
                                                }
                                                Button("Edit Pet", systemImage: "pencil") {
                                                    editingPet = pet
                                                }
                                                Button("Delete Pet", systemImage: "trash", role: .destructive) {
                                                    pendingPetDeletion = pet
                                                }
                                            } label: {
                                                Image(systemName: "ellipsis.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(pet.moodStyle.tint)
                                            }
                                            .accessibilityLabel("Actions for \(pet.name)")
                                            .accessibilityHint("Add medication, edit, or delete this pet")
                                        }

                                        Text([pet.kind.title, pet.breed].filter { !$0.isEmpty }.joined(separator: " • "))
                                            .font(.subheadline)
                                            .foregroundStyle(PetTheme.muted)

                                        Text("\(pet.medications.flatMap(\.logs).filter { Calendar.current.isDateInToday($0.loggedAt) && $0.status == .taken }.count) doses given today")
                                            .font(.footnote)
                                            .foregroundStyle(PetTheme.muted)
                                    }
                                }
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                            .onTapGesture {
                                detailPet = pet
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Care Setup")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    handleAddPetTapped()
                } label: {
                    Label("Add Pet", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingPetEditor) {
            PetEditorView()
        }
        .sheet(item: $editingPet) { pet in
            PetEditorView(pet: pet)
        }
        .sheet(item: $detailPet) { pet in
            NavigationStack {
                PetDetailView(pet: pet)
            }
        }
        .sheet(item: $medicationPet) { pet in
            MedicationEditorView(pet: pet)
        }
        .sheet(isPresented: $showingPaywall) {
            ProPaywallView(context: paywallContext)
        }
        .alert(
            pendingPetDeletion.map { "Delete \($0.name)?" } ?? "Delete pet?",
            isPresented: Binding(
                get: { pendingPetDeletion != nil },
                set: { if !$0 { pendingPetDeletion = nil } }
            ),
            presenting: pendingPetDeletion
        ) { pet in
            Button("Delete Pet and All Records", role: .destructive) {
                modelContext.delete(pet)
                try? modelContext.save()
                pendingPetDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                pendingPetDeletion = nil
            }
        } message: { pet in
            Text("This removes \(pet.name)'s medications, logs, and vet records permanently.")
        }
    }

    private func handleAddPetTapped() {
        guard subscriptionManager.hasActiveSubscription || pets.isEmpty else {
            openPaywall(.multiPet)
            return
        }

        showingPetEditor = true
    }

    private func openPaywall(_ context: PremiumGateContext) {
        paywallContext = context
        showingPaywall = true
    }

    private func handleNotificationAccessTapped() {
        if reminderManager.status == .denied {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
            return
        }

        Task {
            await reminderManager.requestAuthorization()
        }
    }
}

struct PetDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingMedicationEditor = false
    @State private var editingMedication: MedicationSchedule?
    @State private var showingPetEditor = false
    @State private var showingRecordEditor = false
    @State private var editingRecord: VetRecord?
    @State private var detailRecord: VetRecord?
    @State private var pendingMedicationDeletion: MedicationSchedule?
    @State private var pendingRecordDeletion: VetRecord?
    @State private var pendingPetDeletion = false

    let pet: PetProfile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PlushCard(tint: pet.moodStyle.tint) {
                    HStack(alignment: .center, spacing: 16) {
                        PetAvatarChip(pet: pet)
                            .scaleEffect(1.2)
                            .frame(width: 64, height: 64)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(pet.name)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(PetTheme.ink)

                            Text([pet.kind.title, pet.breed, pet.weight].filter { !$0.isEmpty }.joined(separator: " • "))
                                .font(.subheadline)
                                .foregroundStyle(PetTheme.muted)

                            if !pet.vetName.isEmpty || !pet.vetContact.isEmpty {
                                Text("Vet: \([pet.vetName, pet.vetContact].filter { !$0.isEmpty }.joined(separator: " • "))")
                                    .font(.footnote)
                                    .foregroundStyle(PetTheme.ink.opacity(0.8))
                            }

                            if !pet.notes.isEmpty {
                                Text(pet.notes)
                                    .font(.footnote)
                                    .foregroundStyle(PetTheme.muted)
                                    .lineLimit(2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    SectionHeading(eyebrow: "Medications", title: "Medication schedules")
                    Spacer()
                    Button {
                        showingMedicationEditor = true
                    } label: {
                        Label("Add Medication", systemImage: "plus.circle.fill")
                            .font(.subheadline.bold())
                    }
                }

                if pet.medications.isEmpty {
                    PlushCard {
                        Text("No medications yet.")
                            .foregroundStyle(PetTheme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ForEach(pet.sortedMedications) { medication in
                        PlushCard(tint: pet.moodStyle.tint) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(medication.name)
                                            .font(.headline)
                                            .foregroundStyle(PetTheme.ink)
                                        Text([medication.dosage, medication.directions]
                                            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                                            .filter { !$0.isEmpty }
                                            .joined(separator: " • "))
                                            .font(.footnote)
                                            .foregroundStyle(PetTheme.muted)
                                    }
                                    Spacer()
                                    Menu {
                                        Button("Edit", systemImage: "pencil") {
                                            editingMedication = medication
                                        }
                                        Button("Delete Medication", systemImage: "trash", role: .destructive) {
                                            pendingMedicationDeletion = medication
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(pet.moodStyle.tint)
                                    }
                                    .accessibilityLabel("Actions for \(medication.name)")
                                    .accessibilityHint("Edit or delete this medication")
                                }

                                HStack(spacing: 10) {
                                    ForEach(medication.reminderTimes, id: \.id) { time in
                                        PillBadge(title: time.label, tint: PetTheme.accent, systemImage: "clock.fill")
                                    }
                                }

                                if let refillLine = refillLine(for: medication) {
                                    Text(refillLine)
                                        .font(.footnote)
                                        .foregroundStyle(PetTheme.accentDeep)
                                }

                                if let courseLine = courseLine(for: medication) {
                                    Text(courseLine)
                                        .font(.footnote)
                                        .foregroundStyle(PetTheme.muted)
                                }
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .onTapGesture {
                            editingMedication = medication
                        }
                    }
                }

                HStack {
                    SectionHeading(eyebrow: "Records", title: "Pet records")
                    Spacer()
                    Button {
                        showingRecordEditor = true
                    } label: {
                        Label("Add Record", systemImage: "plus.circle.fill")
                            .font(.subheadline.bold())
                    }
                }

                if pet.vetRecords.isEmpty {
                    PlushCard {
                        Text("No vet records yet.")
                            .foregroundStyle(PetTheme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ForEach(pet.vetRecords.sorted(by: { $0.recordDate > $1.recordDate })) { record in
                        PlushCard(compact: true) {
                            HStack(alignment: .top, spacing: 12) {
                                if let imageData = record.imageData, let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 52, height: 52)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                } else {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(PetTheme.petBlue.opacity(0.6))
                                        .frame(width: 52, height: 52)
                                        .overlay {
                                            Image(systemName: "cross.case.fill")
                                                .foregroundStyle(PetTheme.accentDeep)
                                                .accessibilityHidden(true)
                                        }
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(alignment: .top, spacing: 12) {
                                        Text(record.title)
                                            .font(.headline)
                                            .foregroundStyle(PetTheme.ink)
                                        Spacer()
                                        Menu {
                                            Button("Edit Record", systemImage: "pencil") {
                                                editingRecord = record
                                            }
                                            Button("Delete Record", systemImage: "trash", role: .destructive) {
                                                pendingRecordDeletion = record
                                            }
                                        } label: {
                                            Image(systemName: "ellipsis.circle.fill")
                                                .font(.title3)
                                                .foregroundStyle(PetTheme.accentDeep)
                                        }
                                        .accessibilityLabel("Actions for \(record.title)")
                                        .accessibilityHint("Edit or delete this record")
                                    }

                                    Text(record.recordDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PetTheme.accentDeep)

                                    if !record.summary.isEmpty {
                                        Text(record.summary)
                                            .font(.footnote)
                                            .foregroundStyle(PetTheme.muted)
                                            .lineLimit(2)
                                    } else {
                                        Text("Tap to view details.")
                                            .font(.footnote)
                                            .foregroundStyle(PetTheme.muted)
                                    }
                                }
                            }
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .onTapGesture {
                            detailRecord = record
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(PetBackgroundView())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit Pet", systemImage: "pencil") {
                        showingPetEditor = true
                    }
                    Button("Delete Pet", systemImage: "trash", role: .destructive) {
                        pendingPetDeletion = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingMedicationEditor) {
            MedicationEditorView(pet: pet)
        }
        .sheet(item: $editingMedication) { medication in
            MedicationEditorView(pet: pet, medication: medication)
        }
        .sheet(isPresented: $showingPetEditor) {
            PetEditorView(pet: pet)
        }
        .sheet(isPresented: $showingRecordEditor) {
            VetRecordEditorView(pet: pet)
        }
        .sheet(item: $editingRecord) { record in
            VetRecordEditorView(pet: pet, record: record)
        }
        .sheet(item: $detailRecord) { record in
            NavigationStack {
                VetRecordDetailView(pet: pet, record: record)
            }
        }
        .alert(
            "Delete \(pet.name)?",
            isPresented: $pendingPetDeletion
        ) {
            Button("Delete Pet and All Records", role: .destructive) {
                modelContext.delete(pet)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes \(pet.name)'s medications, logs, and records permanently.")
        }
        .alert(
            pendingMedicationDeletion.map { "Delete \($0.name)?" } ?? "Delete medication?",
            isPresented: Binding(
                get: { pendingMedicationDeletion != nil },
                set: { if !$0 { pendingMedicationDeletion = nil } }
            ),
            presenting: pendingMedicationDeletion
        ) { medication in
            Button("Delete Medication", role: .destructive) {
                modelContext.delete(medication)
                try? modelContext.save()
                pendingMedicationDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                pendingMedicationDeletion = nil
            }
        } message: { _ in
            Text("This removes the schedule and all its dose logs permanently.")
        }
        .alert(
            pendingRecordDeletion.map { "Delete \($0.title)?" } ?? "Delete record?",
            isPresented: Binding(
                get: { pendingRecordDeletion != nil },
                set: { if !$0 { pendingRecordDeletion = nil } }
            ),
            presenting: pendingRecordDeletion
        ) { record in
            Button("Delete Record", role: .destructive) {
                modelContext.delete(record)
                try? modelContext.save()
                pendingRecordDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                pendingRecordDeletion = nil
            }
        } message: { _ in
            Text("This vet record will be removed permanently.")
        }
    }

    private func refillLine(for medication: MedicationSchedule) -> String? {
        guard let remaining = medication.remainingDoses else { return nil }
        if let days = medication.estimatedDaysRemaining {
            return "\(remaining) doses left • about \(days) day\(days == 1 ? "" : "s")"
        }
        return "\(remaining) doses left"
    }

    private func courseLine(for medication: MedicationSchedule) -> String? {
        guard let courseEndDate = medication.courseEndDate else { return nil }
        return "Course ends \(courseEndDate.formatted(date: .abbreviated, time: .omitted))"
    }
}

struct PetEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Query(sort: \PetProfile.name) private var pets: [PetProfile]

    let pet: PetProfile?

    @State private var name: String
    @State private var kind: PetKind
    @State private var breed: String
    @State private var weightAmount: String
    @State private var weightUnit: PetWeightUnit
    @State private var vetName: String
    @State private var vetContact: String
    @State private var notes: String
    @State private var moodStyle: PetMoodStyle
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var showingCamera = false
    @State private var showingPaywall = false

    init(pet: PetProfile? = nil) {
        self.pet = pet
        let parsedWeight = Self.parseWeight(pet?.weight ?? "")
        _name = State(initialValue: pet?.name ?? "")
        _kind = State(initialValue: pet?.kind ?? .dog)
        _breed = State(initialValue: pet?.breed ?? "")
        _weightAmount = State(initialValue: parsedWeight.amount)
        _weightUnit = State(initialValue: parsedWeight.unit)
        _vetName = State(initialValue: pet?.vetName ?? "")
        _vetContact = State(initialValue: pet?.vetContact ?? "")
        _notes = State(initialValue: pet?.notes ?? "")
        _moodStyle = State(initialValue: pet?.moodStyle ?? .blush)
        _imageData = State(initialValue: pet?.imageData)
    }

    var body: some View {
        NavigationStack {
            Form {
                if pet == nil && !subscriptionManager.hasActiveSubscription && pets.count >= 1 {
                    Section {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Multiple pets are part of TailyDose Pro.")
                                .font(.headline)
                                .foregroundStyle(PetTheme.ink)

                            Button("Upgrade to Pro") {
                                showingPaywall = true
                            }
                            .buttonStyle(PrimaryPillButtonStyle(compact: true))
                        }
                    }
                }

                Section("Pet") {
                    VStack(spacing: 18) {
                        Group {
                            if let imageData, let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 112, height: 112)
                                    .clipShape(Circle())
                                    .overlay {
                                        Circle().stroke(Color.white.opacity(0.95), lineWidth: 2)
                                    }
                            } else {
                                ZStack {
                                    Circle()
                                        .fill(moodStyle.tint.opacity(0.22))

                                    Image(systemName: kind.symbol)
                                        .font(.system(size: 42, weight: .semibold))
                                        .foregroundStyle(moodStyle.tint)
                                }
                                .frame(width: 112, height: 112)
                                .overlay {
                                    Circle().stroke(Color.white.opacity(0.95), lineWidth: 2)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)

                        HStack(spacing: 12) {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                Button {
                                    showingCamera = true
                                } label: {
                                    Label("Take Photo", systemImage: "camera.fill")
                                }
                                .buttonStyle(PrimaryPillButtonStyle(compact: true))
                            }

                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("Choose Photo", systemImage: "photo.fill")
                            }
                            .buttonStyle(SecondaryPillButtonStyle(compact: true))
                        }
                        .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 22, trailing: 16))

                    TextField("Name", text: $name)
                    Picker("Type", selection: $kind) {
                        ForEach(PetKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    TextField("Breed", text: $breed)
                    HStack {
                        TextField("Weight", text: $weightAmount)
                            .keyboardType(.decimalPad)

                        Picker("Unit", selection: $weightUnit) {
                            ForEach(PetWeightUnit.allCases) { unit in
                                Text(unit.label).tag(unit)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Vet") {
                    TextField("Vet Clinic", text: $vetName)
                    TextField("Contact", text: $vetContact)
                }

                Section("Notes") {
                    TextField("Care notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Style") {
                    Picker("Theme", selection: $moodStyle) {
                        ForEach(PetMoodStyle.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                }
            }
            .navigationTitle(pet == nil ? "New Pet" : "Edit Pet")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showingPaywall) {
            ProPaywallView(context: .multiPet)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPicker { capturedImage in
                imageData = capturedImage.jpegData(compressionQuality: 0.9)
            }
            .ignoresSafeArea()
        }
        .task(id: selectedPhoto) {
            if let selectedPhoto {
                imageData = try? await selectedPhoto.loadTransferable(type: Data.self)
            }
        }
    }

    private func save() {
        guard pet != nil || subscriptionManager.hasActiveSubscription || pets.isEmpty else {
            showingPaywall = true
            return
        }

        let target = pet ?? PetProfile(name: name)
        target.name = name
        target.kind = kind
        target.breed = breed
        target.weight = Self.formatWeight(amount: weightAmount, unit: weightUnit)
        target.imageData = imageData
        target.vetName = vetName
        target.vetContact = vetContact
        target.notes = notes
        target.moodStyle = moodStyle

        if pet == nil {
            modelContext.insert(target)
        }

        try? modelContext.save()
        dismiss()
    }

    private static func parseWeight(_ raw: String) -> (amount: String, unit: PetWeightUnit) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmed.split(separator: " ")
        let amount = components.first.map(String.init) ?? ""
        let unit = components.dropFirst().first.flatMap { PetWeightUnit(label: String($0)) } ?? .lb
        return (amount, unit)
    }

    private static func formatWeight(amount: String, unit: PetWeightUnit) -> String {
        let trimmedAmount = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAmount.isEmpty else { return "" }
        return "\(trimmedAmount) \(unit.label)"
    }
}

enum PetWeightUnit: String, CaseIterable, Identifiable {
    case lb
    case kg
    case oz
    case g

    var id: String { rawValue }

    var label: String { rawValue }

    init?(label: String) {
        self.init(rawValue: label)
    }
}

struct VetRecordEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let pet: PetProfile
    let record: VetRecord?

    @State private var title: String
    @State private var summary: String
    @State private var recordDate: Date
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?

    init(pet: PetProfile, record: VetRecord? = nil) {
        self.pet = pet
        self.record = record
        _title = State(initialValue: record?.title ?? "")
        _summary = State(initialValue: record?.summary ?? "")
        _recordDate = State(initialValue: record?.recordDate ?? .now)
        _imageData = State(initialValue: record?.imageData)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PetBackgroundView()

                Form {
                    Section("Record") {
                        TextField("Title", text: $title)
                        DatePicker("Record Date", selection: $recordDate, displayedComponents: .date)
                        TextField("Summary", text: $summary, axis: .vertical)
                            .lineLimit(3...6)
                    }

                    Section("Image") {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("Choose Image", systemImage: "photo")
                        }

                        if let imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 180)

                            Button("Remove Image", role: .destructive) {
                                self.imageData = nil
                                selectedPhoto = nil
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(record == nil ? "New Record" : "Edit Record")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task(id: selectedPhoto) {
                guard let selectedPhoto else { return }
                imageData = try? await selectedPhoto.loadTransferable(type: Data.self)
            }
        }
        .preferredColorScheme(.light)
    }

    private func save() {
        let preservedCategory = record?.category ?? "Record"
        let target = record ?? VetRecord(title: title, category: preservedCategory)
        target.title = title
        target.category = preservedCategory
        target.summary = summary
        target.recordDate = recordDate
        target.imageData = imageData

        if record == nil {
            target.pet = pet
            pet.vetRecords.append(target)
            modelContext.insert(target)
        }

        try? modelContext.save()
        dismiss()
    }
}

struct VetRecordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let pet: PetProfile
    let record: VetRecord

    @State private var showingEditor = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let imageData = record.imageData, let uiImage = UIImage(data: imageData) {
                    PlushCard(compact: true) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }

                PlushCard {
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeading(eyebrow: "Record", title: record.title)

                        Label(pet.name, systemImage: pet.kind.symbol)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(PetTheme.accentDeep)

                        Text(record.recordDate.formatted(date: .complete, time: .omitted))
                            .font(.subheadline)
                            .foregroundStyle(PetTheme.muted)

                        if record.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("No details added yet.")
                                .font(.body)
                                .foregroundStyle(PetTheme.muted)
                        } else {
                            Text(record.summary)
                                .font(.body)
                                .foregroundStyle(PetTheme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                Button {
                    showingEditor = true
                } label: {
                    Label("Edit Record", systemImage: "pencil")
                }
                .buttonStyle(PrimaryPillButtonStyle())
            }
            .padding(20)
        }
        .background(PetBackgroundView())
        .navigationTitle("Record Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showingEditor = true
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            VetRecordEditorView(pet: pet, record: record)
        }
        .alert(
            "Delete \(record.title)?",
            isPresented: $showingDeleteConfirmation
        ) {
            Button("Delete Record", role: .destructive) {
                modelContext.delete(record)
                try? modelContext.save()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This record will be removed permanently.")
        }
    }
}

private struct CameraPicker: UIViewControllerRepresentable {
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        picker.modalPresentationStyle = .fullScreen
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImagePicked: (UIImage) -> Void
        private let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let edited = info[.editedImage] as? UIImage {
                onImagePicked(edited)
            } else if let original = info[.originalImage] as? UIImage {
                onImagePicked(original)
            }
            dismiss()
        }
    }
}
