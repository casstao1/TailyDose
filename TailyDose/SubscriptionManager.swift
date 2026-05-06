import Foundation
import StoreKit
import SwiftUI

enum PremiumGateContext {
    case multiPet
    case reminders
    case export

    var title: String {
        switch self {
        case .multiPet:
            "Unlock Multiple Pets"
        case .reminders:
            "Unlock Push Alerts"
        case .export:
            "Unlock Vet Export"
        }
    }

    var message: String {
        switch self {
        case .multiPet:
            "TailyDose Pro unlocks full multi-pet care management with a single lifetime purchase."
        case .reminders:
            "TailyDose Pro unlocks push medication alerts while keeping basic reminder scheduling free."
        case .export:
            "TailyDose Pro unlocks clean vet-ready export and sharing."
        }
    }
}

@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    static let lifetimeProductID = "com.castao.tailydose.pro.lifetime"
    static let lifetimeFallbackDisplayPrice = "$9.99 one-time"

    @Published private(set) var products: [Product] = []
    @Published private(set) var hasActiveSubscription = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var isPurchasing = false
    @Published var purchaseErrorMessage: String?

    private var transactionUpdatesTask: Task<Void, Never>?
    #if DEBUG
    // Auto-unlock Pro in local debug builds so every feature is usable without
    // a sandbox StoreKit configuration. Release builds never compile this flag.
    private let debugForceProUnlocked = true
    #endif

    private init() {
        #if DEBUG
        hasActiveSubscription = debugForceProUnlocked
        #endif

        transactionUpdatesTask = observeTransactionUpdates()

        Task {
            await refreshProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    var lifetimeProduct: Product? {
        products.first { $0.id == Self.lifetimeProductID }
    }

    var lifetimeDisplayPrice: String {
        if let lifetimeProduct {
            return "\(lifetimeProduct.displayPrice) one-time"
        }
        return Self.lifetimeFallbackDisplayPrice
    }

    func refreshProducts() async {
        #if DEBUG
        if debugForceProUnlocked {
            isLoadingProducts = false
            return
        }
        #endif

        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            products = try await Product.products(for: [Self.lifetimeProductID])
        } catch {
            purchaseErrorMessage = "Unable to load purchase options right now."
        }
    }

    func refreshEntitlements() async {
        #if DEBUG
        if debugForceProUnlocked {
            hasActiveSubscription = true
            purchaseErrorMessage = nil
            return
        }
        #endif

        var hasUnlock = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.lifetimeProductID else { continue }
            guard transaction.revocationDate == nil else { continue }
            hasUnlock = true
            break
        }

        hasActiveSubscription = hasUnlock
    }

    func purchaseLifetime() async -> Bool {
        #if DEBUG
        if debugForceProUnlocked {
            hasActiveSubscription = true
            purchaseErrorMessage = nil
            return true
        }
        #endif
        return await purchase(productID: Self.lifetimeProductID)
    }

    func restorePurchases() async {
        #if DEBUG
        if debugForceProUnlocked {
            hasActiveSubscription = true
            purchaseErrorMessage = nil
            return
        }
        #endif

        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseErrorMessage = "Unable to restore purchases right now."
        }
    }

    private func purchase(productID: String) async -> Bool {
        #if DEBUG
        if debugForceProUnlocked {
            hasActiveSubscription = true
            purchaseErrorMessage = nil
            return true
        }
        #endif

        if products.isEmpty {
            await refreshProducts()
        }

        guard let product = products.first(where: { $0.id == productID }) else {
            purchaseErrorMessage = "Purchase option unavailable. Check App Store Connect product setup."
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseErrorMessage = "Purchase could not be verified."
                    return false
                }

                await transaction.finish()
                await refreshEntitlements()
                return hasActiveSubscription

            case .userCancelled, .pending:
                return false

            @unknown default:
                purchaseErrorMessage = "Purchase did not complete."
                return false
            }
        } catch {
            purchaseErrorMessage = error.localizedDescription
            return false
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task {
            #if DEBUG
            if debugForceProUnlocked {
                return
            }
            #endif

            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                }
                await refreshEntitlements()
            }
        }
    }
}

struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    let context: PremiumGateContext

    var body: some View {
        NavigationStack {
            ZStack {
                PetBackgroundView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        PlushCard(tint: PetTheme.petBlue) {
                            VStack(alignment: .leading, spacing: 14) {
                                SectionHeading(eyebrow: "TailyDose Pro", title: context.title)

                                Text(context.message)
                                    .font(.subheadline)
                                    .foregroundStyle(PetTheme.muted)

                                VStack(alignment: .leading, spacing: 8) {
                                    benefitRow("Push medication alerts")
                                    benefitRow("Multiple pets in one account")
                                    benefitRow("Vet-ready share and export")
                                    benefitRow("One purchase, no recurring subscription")
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Unlock once")
                                .font(.headline)
                                .foregroundStyle(PetTheme.ink)

                            unlockCard(
                                title: "Lifetime Unlock",
                                subtitle: subscriptionManager.lifetimeDisplayPrice
                            )
                        }

                        PlushCard(compact: true) {
                            VStack(alignment: .leading, spacing: 10) {
                                Button {
                                    Task {
                                        let succeeded = await subscriptionManager.purchaseLifetime()
                                        if succeeded {
                                            dismiss()
                                        }
                                    }
                                } label: {
                                    Label("Unlock TailyDose Pro", systemImage: "sparkles")
                                }
                                .buttonStyle(PrimaryPillButtonStyle())
                                .disabled(subscriptionManager.isPurchasing)

                                Button("Restore Purchases") {
                                    Task {
                                        await subscriptionManager.restorePurchases()
                                        if subscriptionManager.hasActiveSubscription {
                                            dismiss()
                                        }
                                    }
                                }
                                .buttonStyle(SecondaryPillButtonStyle())
                                .disabled(subscriptionManager.isPurchasing)

                                Text("Payment is charged to your Apple Account at confirmation. This is a one-time purchase that unlocks Pro features permanently for your account.")
                                    .font(.caption)
                                    .foregroundStyle(PetTheme.muted)

                                HStack(spacing: 16) {
                                    Link("Privacy Policy", destination: AppStoreLinks.privacyPolicy)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PetTheme.accentDeep)

                                    Link("Terms of Use", destination: AppStoreLinks.termsOfUse)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(PetTheme.accentDeep)
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task {
            await subscriptionManager.refreshProducts()
            await subscriptionManager.refreshEntitlements()
        }
        .alert("Purchase Issue", isPresented: purchaseErrorBinding) {
            Button("OK", role: .cancel) {
                subscriptionManager.purchaseErrorMessage = nil
            }
        } message: {
            Text(subscriptionManager.purchaseErrorMessage ?? "")
        }
    }

    private var purchaseErrorBinding: Binding<Bool> {
        Binding(
            get: { subscriptionManager.purchaseErrorMessage != nil },
            set: { newValue in
                if !newValue {
                    subscriptionManager.purchaseErrorMessage = nil
                }
            }
        )
    }

    @ViewBuilder
    private func benefitRow(_ title: String) -> some View {
        Label(title, systemImage: "checkmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(PetTheme.ink)
    }

    @ViewBuilder
    private func unlockCard(title: String, subtitle: String) -> some View {
        PlushCard(compact: true) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(PetTheme.ink)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(PetTheme.muted)
                }

                Spacer()

                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundStyle(PetTheme.accentDeep)
            }
        }
    }
}

private enum AppStoreLinks {
    static let privacyPolicy = URL(string: "https://casstao1.github.io/TailyDose/privacy-policy.html")!
    static let termsOfUse = URL(string: "https://casstao1.github.io/TailyDose/terms-of-use.html")!
    static let support = URL(string: "https://casstao1.github.io/TailyDose/support.html")!
}
