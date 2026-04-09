import Foundation
import UserNotifications

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

        guard [.authorized, .provisional, .ephemeral].contains(status) else { return }

        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        for pet in pets {
            for medication in pet.medications where medication.reminderEnabled {
                for time in medication.reminderTimes {
                    var components = DateComponents()
                    components.hour = time.hour
                    components.minute = time.minute

                    let content = UNMutableNotificationContent()
                    content.title = "\(pet.name) needs \(medication.name)"
                    content.body = "\(medication.dosage) • \(medication.directions)"
                    content.sound = .default

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
}
