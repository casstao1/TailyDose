import SwiftData
import SwiftUI
import PhotosUI
import UIKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PetProfile.name) private var pets: [PetProfile]

    @ObservedObject var reminderManager: ReminderManager
    @State private var showingPetEditor = false
    @State private var editingPet: PetProfile?

    private var allMeds: [MedicationSchedule] {
        pets.flatMap(\.medications)
    }

    private var todayLogs: [DoseLog] {
        allMeds.flatMap(\.logs).filter { Calendar.current.isDateInToday($0.loggedAt) }
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
                                TinyMetric(value: "\(allMeds.count)", label: "Active Meds", systemImage: "pills.fill")
                            }
                        }
                    }

                    if reminderManager.status != .authorized && reminderManager.status != .provisional && reminderManager.status != .ephemeral {
                        PlushCard {
                            Button {
                                Task { await reminderManager.requestAuthorization() }
                            } label: {
                                Label("Enable Medication Alerts", systemImage: "bell.fill")
                                    .font(.headline)
                                    .foregroundStyle(PetTheme.accent)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }

                    SectionHeading(eyebrow: "Pets", title: "Your companions")

                    if pets.isEmpty {
                        PlushCard {
                            Button {
                                showingPetEditor = true
                            } label: {
                                Label("Add Your First Pet", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .foregroundStyle(PetTheme.accent)
                            }
                        }
                    } else {
                        ForEach(pets) { pet in
                            NavigationLink {
                                PetDetailView(pet: pet)
                            } label: {
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
                                                    Button("Edit Pet", systemImage: "pencil") {
                                                        editingPet = pet
                                                    }
                                                    Button("Delete Pet", systemImage: "trash", role: .destructive) {
                                                        modelContext.delete(pet)
                                                        try? modelContext.save()
                                                    }
                                                } label: {
                                                    Image(systemName: "ellipsis.circle.fill")
                                                        .font(.title3)
                                                        .foregroundStyle(pet.moodStyle.tint)
                                                }
                                            }

                                            Text([pet.kind.title, pet.breed].filter { !$0.isEmpty }.joined(separator: " • "))
                                                .font(.subheadline)
                                                .foregroundStyle(PetTheme.muted)

                                            Text("\(pet.medications.flatMap(\.logs).filter { Calendar.current.isDateInToday($0.loggedAt) }.count) logs today")
                                                .font(.footnote)
                                                .foregroundStyle(PetTheme.muted)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
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
                    showingPetEditor = true
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
    }
}

struct PetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showingMedicationEditor = false
    @State private var editingMedication: MedicationSchedule?
    @State private var showingPetEditor = false
    @State private var showingRecordEditor = false
    @State private var editingRecord: VetRecord?

    let pet: PetProfile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PlushCard(tint: pet.moodStyle.tint) {
                    HStack(alignment: .top, spacing: 14) {
                        PetAvatarChip(pet: pet)

                        VStack(alignment: .leading, spacing: 12) {
                            Text(pet.name)
                                .font(.system(size: 28, weight: .bold, design: .rounded))
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
                            }
                        }
                    }
                }

                HStack {
                    SectionHeading(eyebrow: "Meds", title: "Schedules")
                    Spacer()
                    Button {
                        showingMedicationEditor = true
                    } label: {
                        Label("Add Med", systemImage: "plus.circle.fill")
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
                    ForEach(pet.activeMedications) { medication in
                        PlushCard(tint: pet.moodStyle.tint) {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(medication.name)
                                            .font(.headline)
                                            .foregroundStyle(PetTheme.ink)
                                        Text("\(medication.dosage) • \(medication.directions)")
                                            .font(.footnote)
                                            .foregroundStyle(PetTheme.muted)
                                    }
                                    Spacer()
                                    Menu {
                                        Button("Edit", systemImage: "pencil") {
                                            editingMedication = medication
                                        }
                                        Button("Delete", systemImage: "trash", role: .destructive) {
                                            modelContext.delete(medication)
                                            try? modelContext.save()
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle.fill")
                                            .font(.title3)
                                            .foregroundStyle(pet.moodStyle.tint)
                                    }
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

                                HStack(spacing: 10) {
                                    Button("Log Taken") {
                                        logDose(for: medication, status: .taken)
                                    }
                                    .buttonStyle(PrimaryPillButtonStyle())

                                    Button("Skip") {
                                        logDose(for: medication, status: .skipped)
                                    }
                                    .buttonStyle(SecondaryPillButtonStyle())
                                }
                            }
                        }
                    }
                }

                HStack {
                    SectionHeading(eyebrow: "Vault", title: "Vet records")
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
                                        }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(record.title)
                                            .font(.headline)
                                            .foregroundStyle(PetTheme.ink)
                                        Spacer()
                                        Text(record.recordDate.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption)
                                            .foregroundStyle(PetTheme.muted)
                                    }

                                    Text(record.category)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PetTheme.accentDeep)

                                    if !record.summary.isEmpty {
                                        Text(record.summary)
                                            .font(.footnote)
                                            .foregroundStyle(PetTheme.muted)
                                    }
                                }
                            }
                        }
                        .contextMenu {
                            Button("Edit Record", systemImage: "pencil") {
                                editingRecord = record
                            }
                            Button("Delete Record", systemImage: "trash", role: .destructive) {
                                modelContext.delete(record)
                                try? modelContext.save()
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(PetBackgroundView())
        .navigationTitle(pet.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showingPetEditor = true
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
    }

    private func logDose(for medication: MedicationSchedule, status: DoseStatus) {
        let now = Date.now
        let log = DoseLog(scheduledAt: now, loggedAt: now, status: status)
        log.medication = medication
        medication.logs.append(log)
        if status == .taken, let remaining = medication.remainingDoses, remaining > 0 {
            medication.remainingDoses = remaining - 1
        }
        modelContext.insert(log)
        try? modelContext.save()
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

    let pet: PetProfile?

    @State private var name: String
    @State private var kind: PetKind
    @State private var breed: String
    @State private var weight: String
    @State private var vetName: String
    @State private var vetContact: String
    @State private var notes: String
    @State private var moodStyle: PetMoodStyle

    init(pet: PetProfile? = nil) {
        self.pet = pet
        _name = State(initialValue: pet?.name ?? "")
        _kind = State(initialValue: pet?.kind ?? .dog)
        _breed = State(initialValue: pet?.breed ?? "")
        _weight = State(initialValue: pet?.weight ?? "")
        _vetName = State(initialValue: pet?.vetName ?? "")
        _vetContact = State(initialValue: pet?.vetContact ?? "")
        _notes = State(initialValue: pet?.notes ?? "")
        _moodStyle = State(initialValue: pet?.moodStyle ?? .blush)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Pet") {
                    TextField("Name", text: $name)
                    Picker("Type", selection: $kind) {
                        ForEach(PetKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    TextField("Breed", text: $breed)
                    TextField("Weight", text: $weight)
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
    }

    private func save() {
        let target = pet ?? PetProfile(name: name)
        target.name = name
        target.kind = kind
        target.breed = breed
        target.weight = weight
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
}

struct VetRecordEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let pet: PetProfile
    let record: VetRecord?

    @State private var title: String
    @State private var category: String
    @State private var summary: String
    @State private var recordDate: Date
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?

    init(pet: PetProfile, record: VetRecord? = nil) {
        self.pet = pet
        self.record = record
        _title = State(initialValue: record?.title ?? "")
        _category = State(initialValue: record?.category ?? "Visit Summary")
        _summary = State(initialValue: record?.summary ?? "")
        _recordDate = State(initialValue: record?.recordDate ?? .now)
        _imageData = State(initialValue: record?.imageData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Record") {
                    TextField("Title", text: $title)
                    TextField("Category", text: $category)
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
    }

    private func save() {
        let target = record ?? VetRecord(title: title, category: category)
        target.title = title
        target.category = category
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
