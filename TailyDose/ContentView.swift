import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Query(sort: \PetProfile.name) private var pets: [PetProfile]

    @AppStorage("tailyDoseRemovedSampleData") private var removedSampleData = false
    @AppStorage("tailyDoseSplashActive") private var splashActive = true
    @StateObject private var reminderManager = ReminderManager.shared
    @State private var hasBootstrapped = false
    @State private var selectedDate = Date.now
    @State private var showingDatePicker = false
    @State private var timelineEntries: [DoseTimelineEntry] = []
    @State private var shouldRevealContent = false
    @State private var detailPet: PetProfile?
    @State private var editingMedicationTarget: HomeMedicationEditingTarget?
    @State private var pendingTimelineSaveTask: Task<Void, Never>?

    private var selectedDayEntries: [DoseTimelineEntry] {
        timelineEntries
    }

    private var headerTitle: String {
        Calendar.current.isDateInToday(selectedDate)
            ? "Today"
            : selectedDate.formatted(.dateTime.weekday(.wide))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PetBackgroundView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 34, style: .continuous)
                                .fill(Color(red: 0.18, green: 0.33, blue: 0.48))

                            Circle()
                                .fill(.white.opacity(0.08))
                                .frame(width: 150, height: 150)
                                .offset(x: 104, y: -60)

                            Circle()
                                .fill(.white.opacity(0.05))
                                .frame(width: 120, height: 120)
                                .offset(x: -110, y: 44)

                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .center, spacing: 12) {
                                Button {
                                    showingDatePicker = true
                                } label: {
                                    Label(
                                        selectedDate.formatted(.dateTime.month(.abbreviated).day()),
                                        systemImage: "calendar"
                                    )
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.94))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(.white.opacity(0.18), lineWidth: 1)
                                    }
                                }

                                    Spacer(minLength: 0)

                                    Menu {
                                        NavigationLink {
                                            HomeView(reminderManager: reminderManager)
                                        } label: {
                                            Label("Manage Pets & Medications", systemImage: "slider.horizontal.3")
                                        }

                                        NavigationLink {
                                            CalendarHistoryView()
                                        } label: {
                                            Label("History", systemImage: "calendar")
                                        }

                                        NavigationLink {
                                            ShareVetView()
                                        } label: {
                                            Label("Share With Vet", systemImage: "square.and.arrow.up.fill")
                                        }
                                    } label: {
                                        Image(systemName: "line.3.horizontal.decrease")
                                            .font(.title3.weight(.semibold))
                                            .foregroundStyle(.white.opacity(0.94))
                                            .frame(width: 42, height: 42)
                                            .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                    .stroke(.white.opacity(0.18), lineWidth: 1)
                                            }
                                    }
                                    .accessibilityLabel("More options")
                                    .accessibilityHint("Opens the menu for history, export, and other actions")
                                }

                                Text(headerTitle)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                        .opacity(shouldRevealContent ? 1 : 0)
                        .offset(y: shouldRevealContent ? 0 : 34)
                        .scaleEffect(shouldRevealContent ? 1 : 0.94)
                        .animation(.spring(duration: 0.78, bounce: 0.22).delay(0.02), value: shouldRevealContent)

                        if !hasBootstrapped {
                            PlushCard {
                                Text("Loading tasks…")
                                    .foregroundStyle(PetTheme.muted)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .opacity(shouldRevealContent ? 1 : 0)
                            .offset(y: shouldRevealContent ? 0 : 34)
                            .scaleEffect(shouldRevealContent ? 1 : 0.94)
                            .animation(.spring(duration: 0.78, bounce: 0.22).delay(0.08), value: shouldRevealContent)
                        } else if selectedDayEntries.isEmpty {
                            PlushCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("No medication tasks scheduled for this day.")
                                        .font(.headline)
                                        .foregroundStyle(PetTheme.muted)
                                    Text("Use the menu in the top right to add pets, medications, or view history.")
                                        .font(.subheadline)
                                        .foregroundStyle(PetTheme.muted.opacity(0.9))
                                }
                            }
                            .opacity(shouldRevealContent ? 1 : 0)
                            .offset(y: shouldRevealContent ? 0 : 34)
                            .scaleEffect(shouldRevealContent ? 1 : 0.94)
                            .animation(.spring(duration: 0.78, bounce: 0.22).delay(0.08), value: shouldRevealContent)
                        } else {
                            ForEach(Array(selectedDayEntries.enumerated()), id: \.element.id) { index, entry in
                                TimelineRow(
                                    entry: entry,
                                    onToggleTaken: { toggleTaken(entry: entry) },
                                    onOpenPet: {
                                        detailPet = entry.pet
                                    },
                                    onOpenMedication: {
                                        editingMedicationTarget = HomeMedicationEditingTarget(
                                            pet: entry.pet,
                                            medication: entry.medication
                                        )
                                    },
                                    isRevealed: shouldRevealContent,
                                    revealDelay: Double(index) * 0.07 + 0.1
                                )
                            }
                        }
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .padding(.bottom, 0)
                .ignoresSafeArea(edges: .bottom)
            }
            .toolbar(.hidden, for: .navigationBar)
            .tint(PetTheme.accent)
            .fontDesign(.rounded)
            .onAppear {
                shouldRevealContent = !splashActive
            }
            .onReceive(NotificationCenter.default.publisher(for: .tailyDoseHideHomeContent)) { _ in
                shouldRevealContent = false
            }
            .onReceive(NotificationCenter.default.publisher(for: .tailyDoseRevealHomeContent)) { _ in
                shouldRevealContent = true
            }
            .sheet(isPresented: $showingDatePicker) {
                NavigationStack {
                    VStack {
                        DatePicker(
                            "Task Date",
                            selection: $selectedDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding()

                        Spacer()
                    }
                    .navigationTitle("Choose Date")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showingDatePicker = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .task { await bootstrapIfNeeded() }
            .task(id: timelineSignature) { rebuildTimeline() }
            .task(id: notificationTaskSignature) {
                guard hasBootstrapped else { return }
                try? await Task.sleep(for: .milliseconds(700))
                guard subscriptionManager.hasActiveSubscription else {
                    reminderManager.clearNotifications()
                    return
                }
                await reminderManager.syncNotifications(pets: pets)
            }
            .sheet(item: $detailPet) { pet in
                NavigationStack {
                    PetDetailView(pet: pet)
                }
            }
            .sheet(item: $editingMedicationTarget) { target in
                MedicationEditorView(pet: target.pet, medication: target.medication)
            }
        }
    }

    private var timelineSignature: String {
        let dayKey = Calendar.current.startOfDay(for: selectedDate).timeIntervalSince1970
        var hasher = Hasher()
        hasher.combine(dayKey)
        for pet in pets {
            hasher.combine(pet.id)
            for medication in pet.medications {
                hasher.combine(medication.id)
                hasher.combine(medication.startDate)
                hasher.combine(medication.courseEndDate)
                for time in medication.reminderTimes {
                    hasher.combine(time.hour)
                    hasher.combine(time.minute)
                }
                for log in medication.logs {
                    hasher.combine(log.scheduledAt)
                    hasher.combine(log.statusRawValue)
                }
            }
        }
        return "\(hasher.finalize())"
    }

    private var notificationSignature: String {
        var hasher = Hasher()
        for pet in pets {
            hasher.combine(pet.id)
            for med in pet.medications {
                hasher.combine(med.id)
                hasher.combine(med.reminderEnabled)
                // Include course dates so editing a med's start/end triggers
                // a re-sync — otherwise finished courses keep firing alerts.
                hasher.combine(med.startDate)
                hasher.combine(med.courseEndDate)
                for time in med.reminderTimes {
                    hasher.combine(time.hour)
                    hasher.combine(time.minute)
                }
            }
        }
        return "\(hasher.finalize())"
    }

    private var notificationTaskSignature: String {
        "\(subscriptionManager.hasActiveSubscription)|\(notificationSignature)"
    }

    private func bootstrapIfNeeded() async {
        guard !hasBootstrapped else { return }

        if !AppStoreScreenshotMode.isActive,
           !AppStoreScreenshotMode.usesSimulatorScreenshotSeed,
           !removedSampleData {
            try? SampleDataSeeder.removeSeededDemoData(in: modelContext)
            removedSampleData = true
        }

        hasBootstrapped = true
        await reminderManager.refreshStatus()
    }

    private func rebuildTimeline() {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)

        timelineEntries = pets
            .flatMap { pet in
                pet.medications.compactMap { medication -> [DoseTimelineEntry]? in
                    // Filter medications by course start/end so inactive meds don't appear.
                    let startDay = calendar.startOfDay(for: medication.startDate)
                    guard startDay <= dayStart else { return nil }
                    if let endDate = medication.courseEndDate,
                       calendar.startOfDay(for: endDate) < dayStart {
                        return nil
                    }

                    return medication.reminderTimes.map { time in
                        let scheduledAt = calendar.date(
                            bySettingHour: time.hour,
                            minute: time.minute,
                            second: 0,
                            of: selectedDate
                        ) ?? selectedDate

                        let matchingLog = medication.logs.first {
                            calendar.isDate($0.scheduledAt, equalTo: scheduledAt, toGranularity: .minute)
                        }

                        return DoseTimelineEntry(
                            pet: pet,
                            medication: medication,
                            scheduledAt: scheduledAt,
                            log: matchingLog
                        )
                    }
                }
                .flatMap { $0 }
            }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    private func toggleTaken(entry: DoseTimelineEntry) {
        if let existing = entry.log {
            if existing.status == .taken {
                entry.medication.logs.removeAll { $0.id == existing.id }
                if let remaining = entry.medication.remainingDoses {
                    entry.medication.remainingDoses = remaining + 1
                }
                modelContext.delete(existing)
            } else {
                existing.status = .taken
                existing.loggedAt = .now
                if let remaining = entry.medication.remainingDoses, remaining > 0 {
                    entry.medication.remainingDoses = remaining - 1
                }
            }
            rebuildTimeline()
            scheduleTimelineSave()
            return
        }

        let log = DoseLog(
            scheduledAt: entry.scheduledAt,
            loggedAt: .now,
            status: .taken
        )
        log.medication = entry.medication
        entry.medication.logs.append(log)
        if let remaining = entry.medication.remainingDoses, remaining > 0 {
            entry.medication.remainingDoses = remaining - 1
        }
        modelContext.insert(log)
        rebuildTimeline()
        scheduleTimelineSave()
    }

    private func scheduleTimelineSave() {
        pendingTimelineSaveTask?.cancel()
        pendingTimelineSaveTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(40))
            guard !Task.isCancelled else { return }
            try? modelContext.save()
            pendingTimelineSaveTask = nil
        }
    }
}

private struct DoseTimelineEntry: Identifiable {
    let pet: PetProfile
    let medication: MedicationSchedule
    let scheduledAt: Date
    let log: DoseLog?

    var id: String {
        "\(pet.id.uuidString)|\(medication.id.uuidString)|\(scheduledAt.ISO8601Format())"
    }
}

private struct HomeMedicationEditingTarget: Identifiable {
    let pet: PetProfile
    let medication: MedicationSchedule

    var id: PersistentIdentifier {
        medication.persistentModelID
    }
}

private struct TimelineRow: View {
    let entry: DoseTimelineEntry
    let onToggleTaken: () -> Void
    let onOpenPet: () -> Void
    let onOpenMedication: () -> Void
    let isRevealed: Bool
    let revealDelay: Double

    private var statusText: String {
        if let log = entry.log {
            return log.status.title
        }

        if Calendar.current.isDateInToday(entry.scheduledAt), entry.scheduledAt < .now {
            return "Due Now"
        }

        return "Upcoming"
    }

    private var statusTint: Color {
        if let log = entry.log {
            return log.status.tint
        }

        return entry.scheduledAt < .now
            ? Color(red: 0.96, green: 0.56, blue: 0.38)
            : PetTheme.accentDeep
    }

    private var isCompleted: Bool {
        entry.log?.status == .taken
    }

    var body: some View {
        PlushCard(tint: isCompleted ? Color.gray.opacity(0.18) : entry.pet.moodStyle.tint, compact: true) {
            VStack(alignment: .leading, spacing: contentSpacing) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 5) {
                        PetAvatarChip(pet: entry.pet, compact: true)

                        Text(entry.pet.name)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(PetTheme.muted)
                            .multilineTextAlignment(.center)
                            .frame(width: 44)
                    }
                    .frame(minHeight: 60, alignment: .center)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onOpenPet()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Open \(entry.pet.name)'s profile")

                    VStack(alignment: .leading, spacing: contentSpacing) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(entry.scheduledAt.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(isCompleted ? PetTheme.muted : PetTheme.ink)

                            Text(medicationLine)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(isCompleted ? PetTheme.muted : PetTheme.ink)
                        }
                        .padding(.trailing, headlineTrailingInset)
                        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)

                        if let completionTimestamp {
                            Text(completionTimestamp)
                                .font(.footnote)
                                .foregroundStyle(DoseStatus.taken.tint)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if showsDetailBox {
                            VStack(alignment: .leading, spacing: 4) {
                                if let detail = doseDetail {
                                    Text(detail)
                                        .font(.footnote)
                                        .foregroundStyle(PetTheme.muted)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                Color.white.opacity(isCompleted ? 0.4 : 0.58),
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                        }

                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onOpenMedication()
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Opens medication details")
                }
            }
            .overlay(alignment: .topTrailing) {
                Button(action: onToggleTaken) {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(isCompleted ? DoseStatus.taken.tint : PetTheme.accentDeep.opacity(0.85))
                        .frame(width: 116, height: 96, alignment: .topTrailing)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .frame(width: 116, height: 96, alignment: .topTrailing)
                .accessibilityLabel(isCompleted
                    ? "Mark \(medicationLine) for \(entry.pet.name) as not given"
                    : "Mark \(medicationLine) for \(entry.pet.name) as given")
                .accessibilityAddTraits(isCompleted ? .isSelected : [])
            }
        }
        .opacity(isRevealed ? (isCompleted ? 0.72 : 1) : 0)
        .offset(y: isRevealed ? 0 : 42)
        .scaleEffect(isRevealed ? 1 : 0.92)
        .animation(.spring(duration: 0.86, bounce: 0.24).delay(revealDelay), value: isRevealed)
    }

    // Shown beneath the med name. Prefers the log's per-dose note if present
    // (user-entered context for this specific dose); otherwise falls back to
    // the medication's standing directions. Returns nil when there's nothing
    // to show so the row stays compact.
    private var doseDetail: String? {
        if let log = entry.log {
            let trimmedNote = log.note.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedNote.isEmpty { return trimmedNote }
        }
        let trimmedDirections = entry.medication.directions.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedDirections.isEmpty ? nil : trimmedDirections
    }

    private var showsExtraArea: Bool {
        doseDetail != nil || completionTimestamp != nil
    }

    private var showsDetailBox: Bool {
        doseDetail != nil
    }

    private var inlineCompletionTimestamp: String? {
        guard doseDetail == nil else { return nil }
        return completionTimestamp
    }

    private var contentSpacing: CGFloat {
        if showsDetailBox {
            return completionTimestamp == nil ? 12 : 6
        }

        if completionTimestamp != nil {
            return 4
        }

        return 0
    }

    private var headlineTrailingInset: CGFloat {
        40
    }

    private var medicationLine: String {
        let trimmedDosage = entry.medication.dosage.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = entry.medication.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return [trimmedDosage, trimmedName].filter { !$0.isEmpty }.joined(separator: " ")
    }

    private var completionTimestamp: String? {
        guard let log = entry.log, log.status == .taken else { return nil }
        return "Completed \(log.loggedAt.formatted(date: .omitted, time: .shortened))"
    }
}
