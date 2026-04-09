import Foundation

enum ExportService {
    static func vetSummary(for pets: [PetProfile]) -> String {
        var lines: [String] = []
        lines.append("TailyDose Vet Summary")
        lines.append("Generated: \(Date.now.formatted(date: .abbreviated, time: .shortened))")
        lines.append("")

        if pets.isEmpty {
            lines.append("No pets or medication records found.")
            return lines.joined(separator: "\n")
        }

        for pet in pets.sorted(by: { $0.name < $1.name }) {
            lines.append("Pet: \(pet.name)")
            lines.append("Type: \(pet.kind.title)")
            if !pet.breed.isEmpty { lines.append("Breed: \(pet.breed)") }
            if !pet.weight.isEmpty { lines.append("Weight: \(pet.weight)") }
            if !pet.vetName.isEmpty || !pet.vetContact.isEmpty {
                lines.append("Vet: \([pet.vetName, pet.vetContact].filter { !$0.isEmpty }.joined(separator: " • "))")
            }
            if !pet.notes.isEmpty { lines.append("Notes: \(pet.notes)") }
            lines.append("Medications:")

            if pet.medications.isEmpty {
                lines.append("- None recorded")
            } else {
                for med in pet.activeMedications {
                    let times = med.reminderTimes.map(\.label).joined(separator: ", ")
                    lines.append("- \(med.dosage) \(med.name) | \(med.directions)")
                    if !times.isEmpty {
                        lines.append("  Reminder times: \(times)")
                    }
                    if let remaining = med.remainingDoses {
                        if let days = med.estimatedDaysRemaining {
                            lines.append("  Refill tracking: \(remaining) doses left (~\(days) day\(days == 1 ? "" : "s"))")
                        } else {
                            lines.append("  Refill tracking: \(remaining) doses left")
                        }
                    }
                    if let courseEndDate = med.courseEndDate {
                        lines.append("  Course end: \(courseEndDate.formatted(date: .abbreviated, time: .omitted))")
                    }

                    let recentLogs = med.logs.sorted(by: { $0.loggedAt > $1.loggedAt }).prefix(5)
                    if recentLogs.isEmpty {
                        lines.append("  Recent history: no logged doses yet")
                    } else {
                        for log in recentLogs {
                            lines.append("  \(log.loggedAt.formatted(date: .abbreviated, time: .shortened)) - \(log.status.title)\(log.note.isEmpty ? "" : " (\(log.note))")")
                        }
                    }
                }
            }

            if pet.vetRecords.isEmpty {
                lines.append("Vet records: none")
            } else {
                lines.append("Vet records:")
                for record in pet.vetRecords.sorted(by: { $0.recordDate > $1.recordDate }) {
                    lines.append("- \(record.recordDate.formatted(date: .abbreviated, time: .omitted)) | \(record.category) | \(record.title)")
                    if !record.summary.isEmpty {
                        lines.append("  \(record.summary)")
                    }
                }
            }

            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}
