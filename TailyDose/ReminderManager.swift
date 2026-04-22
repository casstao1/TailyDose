import Foundation
import UserNotifications
import UIKit

@MainActor
final class ReminderManager: ObservableObject {
    static let shared = ReminderManager()

    @Published private(set) var status: UNAuthorizationStatus = .notDetermined

    private init() {}

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        status = settings.authorizationStatus
    }

    func requestAuthorization() async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            print("Notification request failed: \(error)")
        }
        await refreshStatus()
    }

    func syncNotifications(pets: [PetProfile]) async {
        await refreshStatus()

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        // Prune cached notification attachments for pets that no longer exist.
        pruneNotificationAttachments(keeping: Set(pets.map(\.id)))

        guard [.authorized, .provisional, .ephemeral].contains(status) else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        for pet in pets {
            for medication in pet.medications where medication.reminderEnabled {
                // Don't start daily repeating reminders before the course
                // actually begins, or users can get alerts a day early.
                if calendar.startOfDay(for: medication.startDate) > today {
                    continue
                }

                // Skip meds whose course has already ended — otherwise we keep
                // firing daily repeating reminders for finished prescriptions.
                if let endDate = medication.courseEndDate,
                   calendar.startOfDay(for: endDate) < today {
                    continue
                }

                for time in medication.reminderTimes {
                    var components = DateComponents()
                    components.hour = time.hour
                    components.minute = time.minute

                    let content = UNMutableNotificationContent()
                    content.title = "\(pet.name) needs \(medication.name)"
                    // Only join non-empty pieces so an empty dosage or
                    // directions field doesn't leave a stray " • ".
                    content.body = [medication.dosage, medication.directions]
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                        .joined(separator: " • ")
                    content.sound = .default
                    if let attachment = notificationAttachment(for: pet) {
                        content.attachments = [attachment]
                    }

                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                    let identifier = "\(pet.id.uuidString)-\(medication.id.uuidString)-\(time.id.uuidString)"
                    let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

                    do {
                        try await center.add(request)
                    } catch {
                        print("Failed to schedule reminder: \(error)")
                    }
                }
            }
        }
    }

    func clearNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        pruneNotificationAttachments(keeping: [])
    }

    private func pruneNotificationAttachments(keeping validPetIDs: Set<UUID>) {
        let folderURL = FileManager.default.temporaryDirectory.appendingPathComponent("TailyDoseNotificationAttachments", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil) else { return }
        for file in files {
            let name = file.deletingPathExtension().lastPathComponent
            if let id = UUID(uuidString: name), validPetIDs.contains(id) { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }

    private func notificationAttachment(for pet: PetProfile) -> UNNotificationAttachment? {
        guard let imageData = pet.imageData,
              let image = UIImage(data: imageData),
              let jpegData = image.jpegData(compressionQuality: 0.85) else {
            return nil
        }

        let folderURL = FileManager.default.temporaryDirectory.appendingPathComponent("TailyDoseNotificationAttachments", isDirectory: true)
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let fileURL = folderURL.appendingPathComponent("\(pet.id.uuidString).jpg")
        do {
            try jpegData.write(to: fileURL, options: .atomic)
            return try UNNotificationAttachment(identifier: pet.id.uuidString, url: fileURL)
        } catch {
            print("Failed to build notification attachment: \(error)")
            return nil
        }
    }
}
