import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PetProfile.name) private var pets: [PetProfile]

    @AppStorage("tailyDoseSampleDataVersion") private var sampleDataVersion = 0
    @AppStorage("tailyDoseSplashActive") private var splashActive = true
    @StateObject private var reminderManager = ReminderManager.shared
    @State private var hasBootstrapped = false
    @State private var selectedDate = Date.now
    @State private var showingDatePicker = false
    @State private var timelineEntries: [DoseTimelineEntry] = []
    @State private var shouldRevealContent = false

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
            .task(id: notificationSignature) {
                guard hasBootstrapped else { return }
                try? await Task.sleep(for: .milliseconds(700))
                await reminderManager.syncNotifications(pets: pets)
            }
        }
    }

    private var timelineSignature: String {
        let dayKey = Calendar.current.startOfDay(for: selectedDate).formatted(date: .numeric, time: .omitted)
        let petKey = pets
            .flatMap { pet in
                pet.medications.flatMap { medication in
                    let times = medication.reminderTimes.map { "\($0.hour):\($0.minute)" }.joined(separator: ",")
                    let logs = medication.logs.map { "\($0.scheduledAt.ISO8601Format())|\($0.statusRawValue)" }.joined(separator: ",")
                    return ["\(pet.id.uuidString)", "\(medication.id.uuidString)", times, logs]
                }
            }
            .joined(separator: "#")
        return "\(dayKey)|\(petKey)"
    }

    private var notificationSignature: String {
        pets
            .flatMap { pet in
                pet.medications.map { med in
                    let times = med.reminderTimes.map { "\($0.hour):\($0.minute)" }.joined(separator: ",")
                    return "\(pet.id.uuidString)|\(med.id.uuidString)|\(med.reminderEnabled)|\(times)"
                }
            }
            .joined(separator: "#")
    }

    private func bootstrapIfNeeded() async {
        guard !hasBootstrapped else { return }

        if sampleDataVersion == 0 {
            try? SampleDataSeeder.seedIfNeeded(in: modelContext)
            sampleDataVersion = 1
        }

        if sampleDataVersion < SampleDataSeeder.currentVersion {
            try? SampleDataSeeder.ensureDemoData(in: modelContext)
            sampleDataVersion = SampleDataSeeder.currentVersion
        }

        hasBootstrapped = true
        await reminderManager.refreshStatus()
    }

    private func rebuildTimeline() {
        let calendar = Calendar.current

        timelineEntries = pets
            .flatMap { pet in
                pet.medications.flatMap { medication in
                    medication.reminderTimes.map { time in
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
            }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    private func toggleTaken(entry: DoseTimelineEntry) {
        if let existing = entry.log {
            entry.medication.logs.removeAll { $0.id == existing.id }
            if let remaining = entry.medication.remainingDoses {
                entry.medication.remainingDoses = remaining + 1
            }
            modelContext.delete(existing)
            try? modelContext.save()
            rebuildTimeline()
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
        try? modelContext.save()
        rebuildTimeline()
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

private struct TimelineRow: View {
    let entry: DoseTimelineEntry
    let onToggleTaken: () -> Void
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
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 6) {
                        PetAvatarChip(pet: entry.pet, compact: true)

                        Text(entry.pet.name)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(PetTheme.muted)
                            .multilineTextAlignment(.center)
                            .frame(width: 44)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(entry.scheduledAt.formatted(date: .omitted, time: .shortened))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(isCompleted ? PetTheme.muted : PetTheme.ink)

                            Spacer()
                        }

                        Text("\(entry.medication.dosage) \(entry.medication.name)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isCompleted ? PetTheme.muted : PetTheme.ink)

                        if let note = detailNote, !note.isEmpty {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(PetTheme.muted)
                        }

                        if let completionTimestamp {
                            Text(completionTimestamp)
                                .font(.caption)
                                .foregroundStyle(DoseStatus.taken.tint)
                        }

                    }

                    Spacer(minLength: 0)

                    Button(action: onToggleTaken) {
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(isCompleted ? DoseStatus.taken.tint : PetTheme.accentDeep.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .opacity(isRevealed ? (isCompleted ? 0.72 : 1) : 0)
        .offset(y: isRevealed ? 0 : 42)
        .scaleEffect(isRevealed ? 1 : 0.92)
        .animation(.spring(duration: 0.86, bounce: 0.24).delay(revealDelay), value: isRevealed)
    }

    private var detailNote: String? {
        if let log = entry.log, !log.note.isEmpty {
            return log.note
        }

        return entry.medication.directions
    }

    private var completionTimestamp: String? {
        guard let log = entry.log, log.status == .taken else { return nil }
        return "Completed \(log.loggedAt.formatted(date: .omitted, time: .shortened))"
    }
}
