import Foundation
import SwiftData

enum PetMoodStyle: String, CaseIterable, Identifiable, Codable {
    case blush
    case mint
    case sky
    case peach

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

enum PetKind: String, CaseIterable, Identifiable, Codable {
    case dog
    case cat
    case rabbit
    case bird
    case other

    var id: String { rawValue }

    var title: String { rawValue.capitalized }

    var symbol: String {
        switch self {
        case .dog: "dog.fill"
        case .cat: "cat.fill"
        case .rabbit: "hare.fill"
        case .bird: "bird.fill"
        case .other: "pawprint.fill"
        }
    }
}

enum DoseStatus: String, CaseIterable, Identifiable, Codable {
    case taken
    case skipped
    case missed

    var id: String { rawValue }

    var title: String { rawValue.capitalized }
}

struct ReminderTime: Codable, Hashable, Identifiable {
    var id: UUID
    var hour: Int
    var minute: Int

    init(id: UUID = UUID(), hour: Int, minute: Int) {
        self.id = id
        self.hour = hour
        self.minute = minute
    }

    var label: String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

@Model
final class PetProfile {
    var id: UUID
    var name: String
    var kindRawValue: String
    var breed: String
    var weight: String
    var vetName: String
    var vetContact: String
    var notes: String
    var moodStyleRawValue: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \MedicationSchedule.pet)
    var medications: [MedicationSchedule]

    @Relationship(deleteRule: .cascade, inverse: \VetRecord.pet)
    var vetRecords: [VetRecord]

    init(
        id: UUID = UUID(),
        name: String,
        kind: PetKind = .dog,
        breed: String = "",
        weight: String = "",
        vetName: String = "",
        vetContact: String = "",
        notes: String = "",
        moodStyle: PetMoodStyle = .blush,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.kindRawValue = kind.rawValue
        self.breed = breed
        self.weight = weight
        self.vetName = vetName
        self.vetContact = vetContact
        self.notes = notes
        self.moodStyleRawValue = moodStyle.rawValue
        self.createdAt = createdAt
        self.medications = []
        self.vetRecords = []
    }

    var kind: PetKind {
        get { PetKind(rawValue: kindRawValue) ?? .dog }
        set { kindRawValue = newValue.rawValue }
    }

    var moodStyle: PetMoodStyle {
        get { PetMoodStyle(rawValue: moodStyleRawValue) ?? .blush }
        set { moodStyleRawValue = newValue.rawValue }
    }

    var activeMedications: [MedicationSchedule] {
        medications.sorted { $0.name < $1.name }
    }
}

@Model
final class MedicationSchedule {
    var id: UUID
    var name: String
    var dosage: String
    var directions: String
    var startDate: Date
    var courseEndDate: Date?
    var remainingDoses: Int?
    var reminderEnabled: Bool
    var reminderTimesData: Data
    var createdAt: Date

    var pet: PetProfile?

    @Relationship(deleteRule: .cascade, inverse: \DoseLog.medication)
    var logs: [DoseLog]

    init(
        id: UUID = UUID(),
        name: String,
        dosage: String,
        directions: String,
        startDate: Date,
        courseEndDate: Date? = nil,
        remainingDoses: Int? = nil,
        reminderEnabled: Bool = true,
        reminderTimes: [ReminderTime] = [],
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.dosage = dosage
        self.directions = directions
        self.startDate = startDate
        self.courseEndDate = courseEndDate
        self.remainingDoses = remainingDoses
        self.reminderEnabled = reminderEnabled
        self.createdAt = createdAt
        self.logs = []

        let encoded = try? JSONEncoder().encode(reminderTimes)
        self.reminderTimesData = encoded ?? Data()
    }

    var reminderTimes: [ReminderTime] {
        get {
            (try? JSONDecoder().decode([ReminderTime].self, from: reminderTimesData))?
                .sorted { lhs, rhs in
                    if lhs.hour == rhs.hour { return lhs.minute < rhs.minute }
                    return lhs.hour < rhs.hour
                } ?? []
        }
        set {
            reminderTimesData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    var latestLogDate: Date? {
        logs.map(\.loggedAt).max()
    }

    var dosesPerDay: Int {
        max(reminderTimes.count, 1)
    }

    var estimatedDaysRemaining: Int? {
        guard let remainingDoses else { return nil }
        return Int(ceil(Double(remainingDoses) / Double(dosesPerDay)))
    }
}

@Model
final class DoseLog {
    var id: UUID
    var scheduledAt: Date
    var loggedAt: Date
    var statusRawValue: String
    var note: String

    var medication: MedicationSchedule?

    init(
        id: UUID = UUID(),
        scheduledAt: Date,
        loggedAt: Date = .now,
        status: DoseStatus = .taken,
        note: String = ""
    ) {
        self.id = id
        self.scheduledAt = scheduledAt
        self.loggedAt = loggedAt
        self.statusRawValue = status.rawValue
        self.note = note
    }

    var status: DoseStatus {
        get { DoseStatus(rawValue: statusRawValue) ?? .taken }
        set { statusRawValue = newValue.rawValue }
    }
}

@Model
final class VetRecord {
    var id: UUID
    var title: String
    var category: String
    var summary: String
    var recordDate: Date
    var imageData: Data?
    var createdAt: Date

    var pet: PetProfile?

    init(
        id: UUID = UUID(),
        title: String,
        category: String,
        summary: String = "",
        recordDate: Date = .now,
        imageData: Data? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.summary = summary
        self.recordDate = recordDate
        self.imageData = imageData
        self.createdAt = createdAt
    }
}

enum SampleDataSeeder {
    static let currentVersion = 5

    static func seedIfNeeded(in context: ModelContext) throws {
        let existingPets = try context.fetch(FetchDescriptor<PetProfile>())
        guard existingPets.isEmpty else { return }
        try insertSampleData(into: context)
    }

    static func ensureDemoData(in context: ModelContext) throws {
        let pets = try context.fetch(FetchDescriptor<PetProfile>())
        let samplePets = buildSamplePets()
        let existingNames = Set(pets.map(\.name))

        if pets.isEmpty {
            try insertSampleData(into: context)
            return
        }

        let missingPets = samplePets.filter { !existingNames.contains($0.name) }
        let missingMedications = missingPets.flatMap(\.medications)
        let missingLogs = missingMedications.flatMap(\.logs)
        let mutablePets = pets + missingPets

        missingPets.forEach(context.insert)
        missingMedications.forEach(context.insert)
        missingLogs.forEach(context.insert)
        try mergeMissingSampleDetails(into: mutablePets, from: samplePets, context: context)
        try context.save()
    }

    private static func mergeMissingSampleDetails(into pets: [PetProfile], from samplePets: [PetProfile], context: ModelContext) throws {
        let sampleByName = Dictionary(uniqueKeysWithValues: samplePets.map { ($0.name, $0) })

        for pet in pets {
            guard let samplePet = sampleByName[pet.name] else { continue }

            let sampleMedicationByName = Dictionary(uniqueKeysWithValues: samplePet.medications.map { ($0.name, $0) })
            for medication in pet.medications {
                guard let sampleMedication = sampleMedicationByName[medication.name] else { continue }
                if medication.courseEndDate == nil {
                    medication.courseEndDate = sampleMedication.courseEndDate
                }
                if medication.remainingDoses == nil {
                    medication.remainingDoses = sampleMedication.remainingDoses
                }
            }

            let existingRecordTitles = Set(pet.vetRecords.map(\.title))
            let missingRecords = samplePet.vetRecords.filter { !existingRecordTitles.contains($0.title) }
            for record in missingRecords {
                let copy = VetRecord(
                    title: record.title,
                    category: record.category,
                    summary: record.summary,
                    recordDate: record.recordDate,
                    imageData: record.imageData
                )
                copy.pet = pet
                pet.vetRecords.append(copy)
                context.insert(copy)
            }
        }

        try context.save()
    }

    private static func insertSampleData(into context: ModelContext) throws {
        let samplePets = buildSamplePets()
        let sampleMedications = samplePets.flatMap(\.medications)
        let sampleLogs = sampleMedications.flatMap(\.logs)

        samplePets.forEach(context.insert)
        sampleMedications.forEach(context.insert)
        sampleLogs.forEach(context.insert)
        try context.save()
    }

    private static func buildSamplePets() -> [PetProfile] {
        let mochi = PetProfile(
            name: "Mochi",
            kind: .cat,
            breed: "Ragdoll",
            weight: "11 lb",
            vetName: "Sunset Pet Clinic",
            vetContact: "(555) 202-8181",
            notes: "Sensitive stomach. Hide tablets in soft treats.",
            moodStyle: .mint
        )

        let biscuit = PetProfile(
            name: "Biscuit",
            kind: .dog,
            breed: "Corgi",
            weight: "24 lb",
            vetName: "Harbor Animal Care",
            vetContact: "(555) 909-1134",
            notes: "Very food motivated. Give meds after a short walk.",
            moodStyle: .sky
        )

        let luna = PetProfile(
            name: "Luna",
            kind: .rabbit,
            breed: "Mini Lop",
            weight: "5 lb",
            vetName: "Willow Exotics",
            vetContact: "(555) 443-2288",
            notes: "Prefers meds with banana mash.",
            moodStyle: .blush
        )

        let kiwi = PetProfile(
            name: "Kiwi",
            kind: .bird,
            breed: "Parakeet",
            weight: "0.08 lb",
            vetName: "Willow Exotics",
            vetContact: "(555) 443-2288",
            notes: "Best with tiny towel wrap for drops.",
            moodStyle: .peach
        )

        let probiotic = MedicationSchedule(
            name: "Probiotic Powder",
            dosage: "1 scoop",
            directions: "Mix into breakfast food.",
            startDate: Calendar.current.date(byAdding: .day, value: -12, to: .now) ?? .now,
            courseEndDate: Calendar.current.date(byAdding: .day, value: 18, to: .now),
            remainingDoses: 20,
            reminderEnabled: true,
            reminderTimes: [ReminderTime(hour: 8, minute: 0)]
        )
        probiotic.pet = mochi

        let allergy = MedicationSchedule(
            name: "Allergy Chew",
            dosage: "1 chew",
            directions: "Give after dinner.",
            startDate: Calendar.current.date(byAdding: .day, value: -4, to: .now) ?? .now,
            courseEndDate: Calendar.current.date(byAdding: .day, value: 24, to: .now),
            remainingDoses: 34,
            reminderEnabled: true,
            reminderTimes: [
                ReminderTime(hour: 8, minute: 0),
                ReminderTime(hour: 19, minute: 30)
            ]
        )
        allergy.pet = mochi

        let eyeDrops = MedicationSchedule(
            name: "Eye Drops",
            dosage: "2 drops",
            directions: "Apply to each eye after lunch.",
            startDate: Calendar.current.date(byAdding: .day, value: -8, to: .now) ?? .now,
            courseEndDate: Calendar.current.date(byAdding: .day, value: 7, to: .now),
            remainingDoses: 16,
            reminderEnabled: true,
            reminderTimes: [ReminderTime(hour: 12, minute: 30)]
        )
        eyeDrops.pet = biscuit

        let jointSupplement = MedicationSchedule(
            name: "Joint Supplement",
            dosage: "1 chew",
            directions: "Give in the evening with dinner.",
            startDate: Calendar.current.date(byAdding: .day, value: -20, to: .now) ?? .now,
            courseEndDate: nil,
            remainingDoses: 45,
            reminderEnabled: true,
            reminderTimes: [ReminderTime(hour: 18, minute: 30)]
        )
        jointSupplement.pet = biscuit

        let gutSupport = MedicationSchedule(
            name: "Gut Support Syringe",
            dosage: "0.5 mL",
            directions: "Give gently before bedtime.",
            startDate: Calendar.current.date(byAdding: .day, value: -6, to: .now) ?? .now,
            courseEndDate: Calendar.current.date(byAdding: .day, value: 10, to: .now),
            remainingDoses: 11,
            reminderEnabled: true,
            reminderTimes: [ReminderTime(hour: 21, minute: 0)]
        )
        gutSupport.pet = luna

        let painRelief = MedicationSchedule(
            name: "Pain Relief Drops",
            dosage: "0.25 mL",
            directions: "Give after breakfast and before bed.",
            startDate: Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now,
            courseEndDate: Calendar.current.date(byAdding: .day, value: 5, to: .now),
            remainingDoses: 10,
            reminderEnabled: true,
            reminderTimes: [
                ReminderTime(hour: 9, minute: 0),
                ReminderTime(hour: 21, minute: 15)
            ]
        )
        painRelief.pet = luna

        let beakCare = MedicationSchedule(
            name: "Beak Care Drops",
            dosage: "1 drop",
            directions: "Place on a small millet treat after breakfast.",
            startDate: Calendar.current.date(byAdding: .day, value: -10, to: .now) ?? .now,
            courseEndDate: Calendar.current.date(byAdding: .day, value: 14, to: .now),
            remainingDoses: 13,
            reminderEnabled: true,
            reminderTimes: [ReminderTime(hour: 9, minute: 15)]
        )
        beakCare.pet = kiwi

        let vitaminMix = MedicationSchedule(
            name: "Vitamin Mix",
            dosage: "2 drops",
            directions: "Add to water bowl in the afternoon.",
            startDate: Calendar.current.date(byAdding: .day, value: -15, to: .now) ?? .now,
            courseEndDate: nil,
            remainingDoses: 40,
            reminderEnabled: true,
            reminderTimes: [ReminderTime(hour: 15, minute: 45)]
        )
        vitaminMix.pet = kiwi

        let dentalGel = MedicationSchedule(
            name: "Dental Gel",
            dosage: "1 pea-size dab",
            directions: "Apply along gumline after breakfast.",
            startDate: Calendar.current.date(byAdding: .day, value: -9, to: .now) ?? .now,
            courseEndDate: Calendar.current.date(byAdding: .day, value: 12, to: .now),
            remainingDoses: 14,
            reminderEnabled: true,
            reminderTimes: [ReminderTime(hour: 7, minute: 45)]
        )
        dentalGel.pet = biscuit

        let calmingDrops = MedicationSchedule(
            name: "Calming Drops",
            dosage: "3 drops",
            directions: "Use before evening wind-down.",
            startDate: Calendar.current.date(byAdding: .day, value: -5, to: .now) ?? .now,
            courseEndDate: Calendar.current.date(byAdding: .day, value: 9, to: .now),
            remainingDoses: 9,
            reminderEnabled: true,
            reminderTimes: [ReminderTime(hour: 20, minute: 15)]
        )
        calmingDrops.pet = mochi

        let biscuitMorning = calendarDate(daysOffset: 0, hour: 7, minute: 45)
        let morningScheduled = calendarDate(daysOffset: 0, hour: 8, minute: 0)
        let eveningScheduled = calendarDate(daysOffset: -1, hour: 19, minute: 30)
        let mochiEvening = calendarDate(daysOffset: 0, hour: 20, minute: 15)
        let biscuitNoon = calendarDate(daysOffset: 0, hour: 12, minute: 30)
        let biscuitEvening = calendarDate(daysOffset: -1, hour: 18, minute: 30)
        let lunaNight = calendarDate(daysOffset: -2, hour: 21, minute: 0)
        let lunaMorning = calendarDate(daysOffset: 0, hour: 9, minute: 0)
        let lunaBedtime = calendarDate(daysOffset: -1, hour: 21, minute: 15)
        let kiwiMorning = calendarDate(daysOffset: 0, hour: 9, minute: 15)
        let kiwiAfternoon = calendarDate(daysOffset: -1, hour: 15, minute: 45)

        let log1 = DoseLog(
            scheduledAt: morningScheduled,
            loggedAt: calendarDate(daysOffset: 0, hour: 8, minute: 12),
            status: .taken,
            note: "Ate it with salmon puree."
        )
        log1.medication = probiotic

        let log2 = DoseLog(
            scheduledAt: eveningScheduled,
            loggedAt: calendarDate(daysOffset: -1, hour: 20, minute: 5),
            status: .taken,
            note: "No fuss."
        )
        log2.medication = allergy

        let log3 = DoseLog(
            scheduledAt: biscuitNoon,
            loggedAt: calendarDate(daysOffset: 0, hour: 12, minute: 42),
            status: .skipped,
            note: "Too wiggly after park visit. Try again later."
        )
        log3.medication = eyeDrops

        let log4 = DoseLog(
            scheduledAt: biscuitEvening,
            loggedAt: calendarDate(daysOffset: -1, hour: 18, minute: 45),
            status: .taken,
            note: "Took it inside a peanut butter treat."
        )
        log4.medication = jointSupplement

        let log5 = DoseLog(
            scheduledAt: lunaNight,
            loggedAt: lunaNight,
            status: .missed,
            note: "Missed bedtime window."
        )
        log5.medication = gutSupport

        let log6 = DoseLog(
            scheduledAt: lunaMorning,
            loggedAt: calendarDate(daysOffset: 0, hour: 9, minute: 6),
            status: .taken,
            note: "Much easier with banana mash."
        )
        log6.medication = painRelief

        let log7 = DoseLog(
            scheduledAt: lunaBedtime,
            loggedAt: calendarDate(daysOffset: -1, hour: 21, minute: 25),
            status: .skipped,
            note: "Rabbit was resting. Retried later."
        )
        log7.medication = painRelief

        let log8 = DoseLog(
            scheduledAt: kiwiMorning,
            loggedAt: calendarDate(daysOffset: 0, hour: 9, minute: 20),
            status: .taken,
            note: "Took it with millet."
        )
        log8.medication = beakCare

        let log9 = DoseLog(
            scheduledAt: kiwiAfternoon,
            loggedAt: calendarDate(daysOffset: -1, hour: 16, minute: 2),
            status: .taken,
            note: "Finished water bowl."
        )
        log9.medication = vitaminMix

        let log10 = DoseLog(
            scheduledAt: biscuitMorning,
            loggedAt: calendarDate(daysOffset: 0, hour: 7, minute: 53),
            status: .taken,
            note: "Handled well after breakfast."
        )
        log10.medication = dentalGel

        let log11 = DoseLog(
            scheduledAt: mochiEvening,
            loggedAt: calendarDate(daysOffset: 0, hour: 20, minute: 18),
            status: .taken,
            note: "Settled quickly before bed."
        )
        log11.medication = calmingDrops

        probiotic.logs.append(log1)
        allergy.logs.append(log2)
        eyeDrops.logs.append(log3)
        jointSupplement.logs.append(log4)
        gutSupport.logs.append(log5)
        painRelief.logs.append(log6)
        painRelief.logs.append(log7)
        beakCare.logs.append(log8)
        vitaminMix.logs.append(log9)
        dentalGel.logs.append(log10)
        calmingDrops.logs.append(log11)

        mochi.medications.append(probiotic)
        mochi.medications.append(allergy)
        mochi.medications.append(calmingDrops)
        biscuit.medications.append(eyeDrops)
        biscuit.medications.append(jointSupplement)
        biscuit.medications.append(dentalGel)
        luna.medications.append(gutSupport)
        luna.medications.append(painRelief)
        kiwi.medications.append(beakCare)
        kiwi.medications.append(vitaminMix)

        let mochiRecord = VetRecord(
            title: "GI Follow-Up",
            category: "Visit Summary",
            summary: "Recommended probiotic course for 30 days and soft-food mixing.",
            recordDate: Calendar.current.date(byAdding: .day, value: -11, to: .now) ?? .now
        )
        mochiRecord.pet = mochi

        let biscuitRecord = VetRecord(
            title: "Dental Care Plan",
            category: "Prescription",
            summary: "Daily dental gel for two weeks. Recheck gums if redness continues.",
            recordDate: Calendar.current.date(byAdding: .day, value: -8, to: .now) ?? .now
        )
        biscuitRecord.pet = biscuit

        let lunaRecord = VetRecord(
            title: "Recovery Notes",
            category: "Care Instructions",
            summary: "Bedtime gut support and pain drops. Keep appetite notes for the next appointment.",
            recordDate: Calendar.current.date(byAdding: .day, value: -4, to: .now) ?? .now
        )
        lunaRecord.pet = luna

        let kiwiRecord = VetRecord(
            title: "Beak Treatment",
            category: "Lab Result",
            summary: "Topical support prescribed. Monitor water intake and activity for one week.",
            recordDate: Calendar.current.date(byAdding: .day, value: -9, to: .now) ?? .now
        )
        kiwiRecord.pet = kiwi

        mochi.vetRecords.append(mochiRecord)
        biscuit.vetRecords.append(biscuitRecord)
        luna.vetRecords.append(lunaRecord)
        kiwi.vetRecords.append(kiwiRecord)

        return [mochi, biscuit, luna, kiwi]
    }

    private static func calendarDate(daysOffset: Int, hour: Int, minute: Int) -> Date {
        let base = Calendar.current.date(byAdding: .day, value: daysOffset, to: .now) ?? .now
        return Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: base
        ) ?? base
    }
}
