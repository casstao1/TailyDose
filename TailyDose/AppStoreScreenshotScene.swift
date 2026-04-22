import SwiftData
import SwiftUI

enum AppStoreScreenshotMode: String, CaseIterable {
    case home
    case manage
    case share
    case notification

    static let environmentKey = "TAILYDOSE_SCREENSHOT_MODE"
    static let launchArgumentPrefix = "TAILYDOSE_SCREENSHOT_MODE="

    static var current: Self? {
        let processInfo = ProcessInfo.processInfo

        if let value = processInfo.environment[environmentKey],
           let mode = Self(rawValue: value) {
            return mode
        }

        if let defaultsValue = UserDefaults.standard.string(forKey: environmentKey),
           let mode = Self(rawValue: defaultsValue) {
            return mode
        }

        let rawArgument = processInfo.arguments.first(where: { $0.hasPrefix(launchArgumentPrefix) })
        return rawArgument
            .map { $0.replacingOccurrences(of: launchArgumentPrefix, with: "") }
            .flatMap(Self.init(rawValue:))
    }

    static var isActive: Bool {
        current != nil
    }

    static var usesSimulatorScreenshotSeed: Bool {
        let deviceName = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? ""
        return deviceName.contains("TailyDose Screenshot")
    }

    var badge: String {
        switch self {
        case .home: "SEE TODAY CLEARLY"
        case .manage: "STAY ORGANIZED"
        case .share: "SHARE WITH CONFIDENCE"
        case .notification: "NEVER MISS A DOSE"
        }
    }

    var headline: String {
        switch self {
        case .home: "Every pet's medication plan, all in one calm glance"
        case .manage: "Keep three pets, refills, and schedules perfectly in sync"
        case .share: "Send a clean medication summary before every vet visit"
        case .notification: "Local reminder alerts help you stay ahead of the next dose"
        }
    }

    var accent: Color {
        switch self {
        case .home: Color(red: 0.83, green: 0.66, blue: 0.97)
        case .manage: Color(red: 0.76, green: 0.84, blue: 0.47)
        case .share: Color(red: 0.49, green: 0.84, blue: 0.92)
        case .notification: Color(red: 0.98, green: 0.65, blue: 0.77)
        }
    }
}

struct AppStoreScreenshotScene: View {
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Query(sort: \PetProfile.name) private var pets: [PetProfile]
    @StateObject private var reminderManager = ReminderManager.shared

    let mode: AppStoreScreenshotMode

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.13),
                    Color(red: 0.10, green: 0.08, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(mode.accent.opacity(0.13))
                .frame(width: 320, height: 320)
                .blur(radius: 30)
                .offset(x: 150, y: -220)

            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 280, height: 280)
                .blur(radius: 24)
                .offset(x: -150, y: 240)

            VStack(spacing: 0) {
                Spacer(minLength: 86)

                Text(mode.badge)
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.88))
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(mode.accent.opacity(0.18), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(mode.accent.opacity(0.34), lineWidth: 1)
                    }
                    .shadow(color: mode.accent.opacity(0.35), radius: 22)

                Text(mode.headline)
                    .font(.system(size: 62, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.96))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 980)
                    .padding(.top, 36)

                Spacer(minLength: 34)

                screenshotLayout
                    .padding(.horizontal, 72)

                Spacer(minLength: 84)
            }
        }
    }

    @ViewBuilder
    private var screenshotLayout: some View {
        switch mode {
        case .home:
            ScreenshotPhoneFrame {
                ContentView()
                    .environmentObject(subscriptionManager)
            }
        case .manage:
            ScreenshotPhoneFrame {
                NavigationStack {
                    HomeView(reminderManager: reminderManager)
                }
                .environmentObject(subscriptionManager)
            }
        case .share:
            ScreenshotPhoneFrame {
                ShareVetView()
                    .environmentObject(subscriptionManager)
            }
        case .notification:
            ScreenshotPhoneFrame {
                ZStack(alignment: .top) {
                    ContentView()
                        .environmentObject(subscriptionManager)

                    ScreenshotNotificationBanner(
                        petName: pets.first?.name ?? "Olive",
                        medicationName: pets.first?.medications.first?.name ?? "Carprofen",
                        timeText: "6:30 PM"
                    )
                    .padding(.top, 24)
                    .padding(.horizontal, 18)
                }
            }
        }
    }
}

private struct ScreenshotPhoneFrame<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 84, style: .continuous)
                .fill(Color.black)
                .frame(width: 760, height: 1500)
                .overlay {
                    RoundedRectangle(cornerRadius: 84, style: .continuous)
                        .stroke(Color.white.opacity(0.62), lineWidth: 6)
                }
                .shadow(color: .black.opacity(0.55), radius: 34, y: 24)

            content
                .frame(width: 700, height: 1440)
                .clipShape(RoundedRectangle(cornerRadius: 68, style: .continuous))

            Capsule()
                .fill(Color.black.opacity(0.92))
                .frame(width: 210, height: 44)
                .overlay {
                    Capsule()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
                .offset(y: -690)
        }
    }
}

private struct ScreenshotNotificationBanner: View {
    let petName: String
    let medicationName: String
    let timeText: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(width: 54, height: 54)
                .background(Color.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("Medication Reminder")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("\(petName) • \(medicationName) at \(timeText)")
                    .font(.system(size: 19, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.70, green: 0.39, blue: 0.61),
                    Color(red: 0.40, green: 0.23, blue: 0.50)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: Color(red: 0.63, green: 0.32, blue: 0.58).opacity(0.45), radius: 20, y: 12)
    }
}
