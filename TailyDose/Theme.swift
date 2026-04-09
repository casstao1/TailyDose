import SwiftUI

enum PetTheme {
    static let ink = Color(red: 0.17, green: 0.20, blue: 0.28)
    static let muted = Color(red: 0.46, green: 0.52, blue: 0.61)
    static let accent = Color(red: 0.50, green: 0.74, blue: 0.94)
    static let accentDeep = Color(red: 0.32, green: 0.55, blue: 0.83)
    static let petPink = Color(red: 0.98, green: 0.87, blue: 0.91)
    static let petBlue = Color(red: 0.89, green: 0.95, blue: 1.00)
    static let petLavender = Color(red: 0.95, green: 0.93, blue: 1.00)
    static let petMint = Color(red: 0.90, green: 0.98, blue: 0.95)
    static let cream = Color(red: 1.00, green: 1.00, blue: 1.00)
    static let background = LinearGradient(
        colors: [
            Color(red: 1.00, green: 0.99, blue: 1.00),
            Color(red: 0.96, green: 0.98, blue: 1.00),
            Color(red: 1.00, green: 0.98, blue: 0.99)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension PetMoodStyle {
    var tint: Color {
        switch self {
        case .blush: Color(red: 0.93, green: 0.67, blue: 0.76)
        case .mint: Color(red: 0.52, green: 0.77, blue: 0.69)
        case .sky: Color(red: 0.49, green: 0.70, blue: 0.92)
        case .peach: Color(red: 0.95, green: 0.73, blue: 0.59)
        }
    }
}

extension DoseStatus {
    var tint: Color {
        switch self {
        case .taken: Color(red: 0.16, green: 0.67, blue: 0.58)
        case .skipped: Color(red: 0.97, green: 0.67, blue: 0.24)
        case .missed: Color(red: 0.92, green: 0.36, blue: 0.40)
        }
    }
}

struct PetBackgroundView: View {
    var body: some View {
        ZStack {
            PetTheme.background.ignoresSafeArea()

            Circle()
                .fill(Color.white.opacity(0.45))
                .frame(width: 280, height: 280)
                .blur(radius: 12)
                .offset(x: 130, y: -310)

            Circle()
                .fill(PetTheme.petBlue.opacity(0.72))
                .frame(width: 320, height: 320)
                .offset(x: -140, y: 360)

            RoundedRectangle(cornerRadius: 56, style: .continuous)
                .fill(PetTheme.petPink.opacity(0.34))
                .frame(width: 220, height: 220)
                .rotationEffect(.degrees(24))
                .offset(x: 170, y: 320)

            Circle()
                .fill(PetTheme.petMint.opacity(0.62))
                .frame(width: 180, height: 180)
                .offset(x: 150, y: -180)

            Image(systemName: "pawprint.fill")
                .font(.system(size: 64))
                .foregroundStyle(PetTheme.accent.opacity(0.08))
                .offset(x: -150, y: -210)

            Image(systemName: "pawprint.fill")
                .font(.system(size: 42))
                .foregroundStyle(PetTheme.petPink.opacity(0.22))
                .offset(x: -90, y: -150)

            Image(systemName: "heart.fill")
                .font(.system(size: 44))
                .foregroundStyle(PetTheme.petPink.opacity(0.18))
                .offset(x: 145, y: 210)
        }
        .allowsHitTesting(false)
    }
}

struct PlushCard<Content: View>: View {
    private let tint: Color?
    private let compact: Bool
    private let content: Content

    init(tint: Color? = nil, compact: Bool = false, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.compact = compact
        self.content = content()
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: compact ? 22 : 28, style: .continuous)
                .fill(PetTheme.cream.opacity(0.985))

            if let tint {
                RoundedRectangle(cornerRadius: compact ? 22 : 28, style: .continuous)
                    .fill(tint.opacity(compact ? 0.12 : 0.18))
            }

            content.padding(compact ? 14 : 20)
        }
        .overlay {
            RoundedRectangle(cornerRadius: compact ? 22 : 28, style: .continuous)
                .stroke(Color.white.opacity(0.92), lineWidth: 1)
        }
        .shadow(color: Color(red: 0.62, green: 0.68, blue: 0.78).opacity(compact ? 0.10 : 0.16), radius: compact ? 12 : 20, x: 0, y: compact ? 8 : 12)
        .contentShape(RoundedRectangle(cornerRadius: compact ? 22 : 28, style: .continuous))
    }
}

struct PetAvatarChip: View {
    let pet: PetProfile
    var compact = false

    private var size: CGFloat { compact ? 38 : 50 }

    var body: some View {
        ZStack {
            Circle()
                .fill(pet.moodStyle.tint.opacity(0.22))

            Image(systemName: pet.kind.symbol)
                .font(.system(size: compact ? 16 : 20, weight: .semibold))
                .foregroundStyle(pet.moodStyle.tint)
        }
        .frame(width: size, height: size)
        .overlay {
            Circle()
                .stroke(Color.white.opacity(0.95), lineWidth: 1)
        }
    }
}

struct PillBadge: View {
    let title: String
    let tint: Color
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(tint)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

struct PrimaryPillButtonStyle: ButtonStyle {
    var tint: Color = PetTheme.accent
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font((compact ? Font.footnote : .subheadline).weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 14 : 16)
            .padding(.vertical, compact ? 10 : 12)
            .frame(maxWidth: compact ? nil : .infinity)
            .background(
                tint.opacity(configuration.isPressed ? 0.86 : 1),
                in: RoundedRectangle(cornerRadius: compact ? 16 : 18, style: .continuous)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct SecondaryPillButtonStyle: ButtonStyle {
    var tint: Color = PetTheme.accentDeep
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font((compact ? Font.footnote : .subheadline).weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, compact ? 14 : 16)
            .padding(.vertical, compact ? 10 : 12)
            .frame(maxWidth: compact ? nil : .infinity)
            .background(
                tint.opacity(configuration.isPressed ? 0.18 : 0.12),
                in: RoundedRectangle(cornerRadius: compact ? 16 : 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: compact ? 16 : 18, style: .continuous)
                    .stroke(tint.opacity(0.12), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
        }
}

struct TinyMetric: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(PetTheme.accent)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(PetTheme.ink)
            Text(label)
                .font(.footnote)
                .foregroundStyle(PetTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(PetTheme.cream.opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct SectionHeading: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .tracking(1.4)
                .foregroundStyle(PetTheme.muted)
            Text(title)
                .font(.title3.bold())
                .foregroundStyle(PetTheme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BotanicalHeroCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.98, green: 0.77, blue: 0.84),
                            Color(red: 0.74, green: 0.88, blue: 1.00)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 180, height: 180)
                .offset(x: 40, y: -40)

            Image(systemName: "pawprint.fill")
                .font(.system(size: 54))
                .foregroundStyle(Color.white.opacity(0.22))
                .offset(x: -18, y: 22)

            content
                .padding(22)
        }
        .shadow(color: PetTheme.accent.opacity(0.18), radius: 20, x: 0, y: 12)
    }
}
