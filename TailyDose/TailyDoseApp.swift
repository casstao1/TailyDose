import SwiftData
import SwiftUI
import UIKit
import UserNotifications

extension Notification.Name {
    static let tailyDoseHideHomeContent = Notification.Name("tailyDoseHideHomeContent")
    static let tailyDoseRevealHomeContent = Notification.Name("tailyDoseRevealHomeContent")
}

private enum SplashTiming {
    static let initialPause = 0.0
    static let bottleAppear = 0.85
    static let preCapPause = 0.35
    static let capOpen = 0.8
    static let capToPillGap = 0.0
    static let pillEmerge = 1.0
    static let pillHoldBeforeZoom = 0.35
    static let zoom = 1.35
    static let revealLeadBeforeZoomEnds = 0.32
    static let dismissAfterZoom = 0.22
}

final class TailyDoseNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound, .badge]
    }
}

final class TailyDoseAppDelegate: NSObject, UIApplicationDelegate {
    private let notificationDelegate = TailyDoseNotificationDelegate()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        return true
    }
}

@main
struct TailyDoseApp: App {
    @UIApplicationDelegateAdaptor(TailyDoseAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("tailyDoseLastInactiveAt") private var lastInactiveAt = 0.0
    @AppStorage("tailyDoseSplashActive") private var splashActive = false

    @StateObject private var subscriptionManager = SubscriptionManager.shared
    private let screenshotMode = AppStoreScreenshotMode.current
    @State private var sharedModelContainer: ModelContainer?
    @State private var didAttemptContainerLoad = false
    @State private var isShowingSplash = false
    @State private var isExitingSplash = false
    @State private var splashAnimationToken = UUID()
    @State private var hasCompletedInitialSplash = false
    @State private var splashZoomTriggered = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                PetBackgroundView()
                    .ignoresSafeArea()

                if let sharedModelContainer {
                    if let screenshotMode {
                        AppStoreScreenshotScene(mode: screenshotMode)
                            .modelContainer(sharedModelContainer)
                    } else {
                        ContentView()
                            .modelContainer(sharedModelContainer)
                    }
                } else if didAttemptContainerLoad {
                    LaunchFallbackView()
                }

                if isShowingSplash, screenshotMode == nil {
                    IconSplashView(
                        animationToken: splashAnimationToken,
                        isExiting: isExitingSplash,
                        onPillSettled: triggerSplashZoom
                    )
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .task {
                await loadModelContainerIfNeeded()
                if screenshotMode != nil {
                    splashActive = false
                    hasCompletedInitialSplash = true
                    return
                }
                guard !hasCompletedInitialSplash, !isShowingSplash else { return }
                runSplashAnimation()
            }
            .onChange(of: scenePhase) { _, newPhase in
                handleScenePhaseChange(newPhase)
            }
            .environmentObject(subscriptionManager)
        }
    }

    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard screenshotMode == nil else { return }
        switch newPhase {
        case .active:
            guard hasCompletedInitialSplash, shouldShowRefreshSplash else { return }
            runSplashAnimation()
        case .inactive, .background:
            lastInactiveAt = Date.now.timeIntervalSince1970
        @unknown default:
            break
        }
    }

    private var shouldShowRefreshSplash: Bool {
        guard lastInactiveAt > 0 else { return false }
        return Date.now.timeIntervalSince1970 - lastInactiveAt > 30 * 60
    }

    private func runSplashAnimation() {
        splashAnimationToken = UUID()
        isShowingSplash = true
        isExitingSplash = false
        splashZoomTriggered = false
        splashActive = true
        NotificationCenter.default.post(name: .tailyDoseHideHomeContent, object: nil)
    }

    @MainActor
    private func triggerSplashZoom() {
        guard !splashZoomTriggered else { return }
        splashZoomTriggered = true

        withAnimation(.easeInOut(duration: SplashTiming.zoom)) {
            isExitingSplash = true
        }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(max(0, SplashTiming.zoom - SplashTiming.revealLeadBeforeZoomEnds)))
            withAnimation(.easeInOut(duration: SplashTiming.dismissAfterZoom)) {
                isShowingSplash = false
            }
            splashActive = false
            NotificationCenter.default.post(name: .tailyDoseRevealHomeContent, object: nil)
            hasCompletedInitialSplash = true
        }
    }

    private func loadModelContainerIfNeeded() async {
        guard sharedModelContainer == nil, !didAttemptContainerLoad else { return }

        let container = await Task.detached(priority: .userInitiated) {
            ModelContainerFactory.make()
        }.value

        await MainActor.run {
            if let container, screenshotMode != nil || AppStoreScreenshotMode.usesSimulatorScreenshotSeed {
                try? SampleDataSeeder.replaceWithScreenshotData(in: container.mainContext)
            }
            sharedModelContainer = container
            didAttemptContainerLoad = true
        }
    }
}

private enum ModelContainerFactory {
    static func make() -> ModelContainer? {
        let schema = Schema([
            PetProfile.self,
            MedicationSchedule.self,
            DoseLog.self,
            VetRecord.self
        ])

        do {
            let configuration = makePrimaryConfiguration(schema: schema)
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            print("Failed to create primary model container: \(error)")

            do {
                let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try ModelContainer(for: schema, configurations: fallback)
            } catch {
                print("Failed to create fallback in-memory model container: \(error)")
                return nil
            }
        }
    }

    private static func makePrimaryConfiguration(schema: Schema) -> ModelConfiguration {
        return ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    }
}

private struct LaunchFallbackView: View {
    var body: some View {
        ZStack {
            PetBackgroundView()

            VStack(spacing: 14) {
                Image(systemName: "pawprint.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(PetTheme.accent)

                Text("TailyDose couldn’t load its local data store.")
                    .font(.title3.bold())
                    .foregroundStyle(PetTheme.ink)
                    .multilineTextAlignment(.center)

                Text("Close the app and relaunch. If it still happens, delete the app from the simulator/device and run it again.")
                    .font(.subheadline)
                    .foregroundStyle(PetTheme.muted)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
        }
    }
}

private struct IconSplashView: View {
    let animationToken: UUID
    let isExiting: Bool
    let onPillSettled: @MainActor () -> Void

    @State private var iconScale: CGFloat = 0.96
    @State private var capOffset: CGFloat = 0
    @State private var capRotation: Double = 0
    @State private var pillOffset: CGFloat = 2
    @State private var pillOpacity = 0.92
    @State private var pillScale: CGFloat = 0.9

    var body: some View {
        ZStack {
            PetBackgroundView()

            Color.white
                .opacity(isExiting ? 1 : 0)
                .ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.78))
                .frame(width: 280, height: 280)
                .blur(radius: 10)
                .offset(x: 110, y: -250)

            VStack {
                AnimatedBottleIcon(
                    capOffset: isExiting ? -36 : capOffset,
                    capRotation: isExiting ? -70 : capRotation,
                    pillOffset: isExiting ? -52 : pillOffset,
                    pillOpacity: isExiting ? 1 : pillOpacity,
                    pillScale: isExiting ? 14 : pillScale,
                    bottleOpacity: isExiting ? 0.18 : 1
                )
                    .frame(width: 214, height: 214)
                    .shadow(color: PetTheme.accent.opacity(0.2), radius: 24, x: 0, y: 14)
                    .scaleEffect(iconScale)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .opacity(isExiting ? 0 : 1)
        .animation(.easeInOut(duration: SplashTiming.zoom), value: isExiting)
        .ignoresSafeArea()
        .task(id: animationToken) {
            await playAnimation()
        }
    }

    private func playAnimation() async {
        iconScale = 0.96
        capOffset = 0
        capRotation = 0
        pillOffset = 2
        pillOpacity = 0.92
        pillScale = 0.9

        try? await Task.sleep(for: .seconds(SplashTiming.initialPause))

        withAnimation(.spring(duration: SplashTiming.bottleAppear, bounce: 0.12)) {
            iconScale = 1
        }

        try? await Task.sleep(for: .seconds(SplashTiming.bottleAppear))

        try? await Task.sleep(for: .seconds(SplashTiming.preCapPause))

        withAnimation(.spring(duration: SplashTiming.capOpen, bounce: 0.08)) {
            capOffset = -2
            capRotation = -70
        }

        withAnimation(.spring(duration: SplashTiming.pillEmerge, bounce: 0.06)) {
            pillOffset = -102
            pillScale = 0.72
        }
        
        try? await Task.sleep(for: .seconds(max(SplashTiming.capOpen, SplashTiming.pillEmerge)))
        try? await Task.sleep(for: .seconds(SplashTiming.pillHoldBeforeZoom))
        onPillSettled()
    }
}

private struct AnimatedBottleIcon: View {
    let capOffset: CGFloat
    let capRotation: Double
    let pillOffset: CGFloat
    let pillOpacity: Double
    let pillScale: CGFloat
    let bottleOpacity: Double

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let pillWidth = size * 0.18
            let pillHeight = size * 0.28

            ZStack {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 1.0, blue: 1.0),
                                Color(red: 0.985, green: 0.989, blue: 0.994),
                                Color(red: 0.965, green: 0.973, blue: 0.984)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: pillWidth, height: pillHeight)
                    .shadow(color: Color.black.opacity(0.055), radius: size * 0.018, x: 0, y: size * 0.01)
                    .overlay {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.5),
                                        Color.white.opacity(0.12),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .padding(size * 0.016)
                    }
                    .overlay {
                        Capsule()
                            .stroke(Color(red: 0.9, green: 0.93, blue: 0.97), lineWidth: 1)
                    }
                    .scaleEffect(pillScale)
                    .opacity(pillOpacity)
                    .offset(y: pillOffset)

                bottleBody(size: size)
                    .opacity(bottleOpacity)

                bottleCap(size: size)
                    .opacity(bottleOpacity)
                    .offset(y: capOffset)
                    .rotationEffect(.degrees(capRotation), anchor: .bottomLeading)
            }
            .frame(width: size, height: size)
        }
    }

    private func bottleBody(size: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.17, style: .continuous)
                .fill(Color(red: 0.73, green: 0.87, blue: 0.94).opacity(0.92))
                .frame(width: size * 0.54, height: size * 0.74)
                .offset(y: size * 0.07)
                .shadow(color: Color.black.opacity(0.12), radius: size * 0.05, x: 0, y: size * 0.04)

            Image("LaunchBottle")
                .resizable()
                .interpolation(.high)
                .scaledToFill()
                .frame(width: size * 1.42, height: size * 1.42)
                .offset(y: size * 0.03)
                .mask(
                    RoundedRectangle(cornerRadius: size * 0.17, style: .continuous)
                        .frame(width: size * 0.50, height: size * 0.66)
                        .offset(y: size * 0.09)
                )

            RoundedRectangle(cornerRadius: size * 0.17, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
                .frame(width: size * 0.54, height: size * 0.74)
                .offset(y: size * 0.07)

            RoundedRectangle(cornerRadius: size * 0.06, style: .continuous)
                .fill(.white.opacity(0.12))
                .frame(width: size * 0.08, height: size * 0.42)
                .offset(x: -(size * 0.12), y: size * 0.01)
        }
    }

    private func bottleCap(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
            .fill(Color(red: 0.86, green: 0.92, blue: 0.96))
            .frame(width: size * 0.62, height: size * 0.15)
            .shadow(color: Color.black.opacity(0.14), radius: size * 0.04, x: 0, y: size * 0.02)
            .overlay {
                HStack(spacing: size * 0.03) {
                    Capsule()
                        .fill(Color(red: 0.78, green: 0.84, blue: 0.89))
                        .frame(width: size * 0.018, height: size * 0.06)
                    Capsule()
                        .fill(Color(red: 0.78, green: 0.84, blue: 0.89))
                        .frame(width: size * 0.018, height: size * 0.06)
                    Capsule()
                        .fill(Color(red: 0.78, green: 0.84, blue: 0.89))
                        .frame(width: size * 0.018, height: size * 0.06)
                }
                .offset(x: size * 0.1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.08, style: .continuous)
                    .stroke(.white.opacity(0.38), lineWidth: 1)
            }
            .offset(y: -(size * 0.275))
    }
}
