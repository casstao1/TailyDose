import SwiftData
import SwiftUI

struct CalendarHistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DoseLog.loggedAt, order: .reverse) private var logs: [DoseLog]
    @Query(sort: \PetProfile.name) private var pets: [PetProfile]

    @State private var selectedDate = Date.now

    private var selectedDayLogs: [DoseLog] {
        logs.filter { Calendar.current.isDate($0.loggedAt, inSameDayAs: selectedDate) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                PetBackgroundView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top, spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Dose History")
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .foregroundStyle(PetTheme.ink)

                                Text(selectedDate.formatted(.dateTime.month(.wide).day()))
                                    .font(.subheadline)
                                    .foregroundStyle(PetTheme.muted)
                            }

                            Spacer()

                            DatePicker(
                                "History Date",
                                selection: $selectedDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .tint(PetTheme.accent)
                        }

                        if selectedDayLogs.isEmpty {
                            PlushCard {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("No logs for \(selectedDate.formatted(date: .abbreviated, time: .omitted)).")
                                        .foregroundStyle(PetTheme.muted)
                                    Button("Auto-mark today's reminders as missed") {
                                        createMissedLogsForSelectedDate()
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        } else {
                            ForEach(selectedDayLogs) { log in
                                PlushCard(tint: log.medication?.pet?.moodStyle.tint) {
                                    HStack(alignment: .top, spacing: 14) {
                                        if let pet = log.medication?.pet {
                                            PetAvatarChip(pet: pet, compact: true)
                                        }

                                        VStack(alignment: .leading, spacing: 10) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(log.medication?.name ?? "Medication")
                                                        .font(.headline)
                                                        .foregroundStyle(PetTheme.ink)
                                                    Text(log.medication?.pet?.name ?? "Pet")
                                                        .font(.subheadline)
                                                        .foregroundStyle(PetTheme.muted)
                                                }
                                                Spacer()
                                                PillBadge(title: log.status.title, tint: log.status.tint, systemImage: "checkmark.circle.fill")
                                            }

                                            Text("Logged: \(log.loggedAt.formatted(date: .omitted, time: .shortened))")
                                                .font(.footnote)
                                                .foregroundStyle(PetTheme.muted)

                                            if !log.note.isEmpty {
                                                Text(log.note)
                                                    .font(.footnote)
                                                    .foregroundStyle(PetTheme.ink.opacity(0.84))
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
            .navigationTitle("History")
        }
    }

    private func createMissedLogsForSelectedDate() {
        let dayMeds = pets.flatMap(\.medications)
        for medication in dayMeds {
            for time in medication.reminderTimes {
                let scheduled = Calendar.current.date(
                    bySettingHour: time.hour,
                    minute: time.minute,
                    second: 0,
                    of: selectedDate
                ) ?? selectedDate

                let alreadyLogged = medication.logs.contains { Calendar.current.isDate($0.scheduledAt, equalTo: scheduled, toGranularity: .minute) }
                guard !alreadyLogged else { continue }

                let log = DoseLog(scheduledAt: scheduled, loggedAt: scheduled, status: .missed, note: "Auto-marked from calendar view.")
                log.medication = medication
                medication.logs.append(log)
                modelContext.insert(log)
            }
        }

        try? modelContext.save()
    }
}
