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
            "TailyDose Pro lets you manage more than one pet from the same account."
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

    static let monthlyProductID = "com.castao.tailydose.pro.monthly"
    static let yearlyProductID = "com.castao.tailydose.pro.yearly"

    static let monthlyDisplayPrice = "$3.99/month"
    static let yearlyDisplayPrice = "$29.99/year"
    static let yearlyTrialLabel = "7-day free trial"

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

    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyProductID }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == Self.yearlyProductID }
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
            let storeProducts = try await Product.products(for: [Self.monthlyProductID, Self.yearlyProductID])
            products = storeProducts.sorted { lhs, rhs in
                order(for: lhs.id) < order(for: rhs.id)
            }
        } catch {
            purchaseErrorMessage = "Unable to load subscription options right now."
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

        var isSubscribed = false

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard [Self.monthlyProductID, Self.yearlyProductID].contains(transaction.productID) else { continue }

            if transaction.revocationDate == nil,
               (transaction.expirationDate == nil || (transaction.expirationDate ?? .distantFuture) > .now) {
                isSubscribed = true
                break
            }
        }

        hasActiveSubscription = isSubscribed
    }

    func purchaseYearly() async -> Bool {
        #if DEBUG
        if debugForceProUnlocked {
            hasActiveSubscription = true
            purchaseErrorMessage = nil
            return true
        }
        #endif
        return await purchase(productID: Self.yearlyProductID)
    }

    func purchaseMonthly() async -> Bool {
        #if DEBUG
        if debugForceProUnlocked {
            hasActiveSubscription = true
            purchaseErrorMessage = nil
            return true
        }
        #endif
        return await purchase(productID: Self.monthlyProductID)
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
            purchaseErrorMessage = "Subscription option unavailable. Check App Store Connect product setup."
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

    private func order(for productID: String) -> Int {
        switch productID {
        case Self.yearlyProductID: 0
        case Self.monthlyProductID: 1
        default: 99
        }
    }
}

struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var subscriptionManager: SubscriptionManager

    let context: PremiumGateContext
    @State private var selectedPlan: Plan = .yearly

    private enum Plan {
        case yearly
        case monthly
    }

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
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Choose a plan")
                                .font(.headline)
                                .foregroundStyle(PetTheme.ink)

                            planCard(
                                title: "Annual",
                                subtitle: SubscriptionManager.yearlyDisplayPrice,
                                badge: SubscriptionManager.yearlyTrialLabel,
                                isSelected: selectedPlan == .yearly
                            ) {
                                selectedPlan = .yearly
                            }

                            planCard(
                                title: "Monthly",
                                subtitle: SubscriptionManager.monthlyDisplayPrice,
                                badge: nil,
                                isSelected: selectedPlan == .monthly
                            ) {
                                selectedPlan = .monthly
                            }
                        }

                        PlushCard(compact: true) {
                            VStack(alignment: .leading, spacing: 10) {
                                Button {
                                    Task {
                                        let succeeded = switch selectedPlan {
                                        case .yearly:
                                            await subscriptionManager.purchaseYearly()
                                        case .monthly:
                                            await subscriptionManager.purchaseMonthly()
                                        }

                                        if succeeded {
                                            dismiss()
                                        }
                                    }
                                } label: {
                                    Label(primaryCTA, systemImage: "sparkles")
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

                                Text("Payment is charged to your Apple Account at confirmation. Subscription renews automatically unless canceled at least 24 hours before the end of the current period. Manage or cancel in your App Store account settings.")
                                    .font(.caption)
                                    .foregroundStyle(PetTheme.muted)

                                Text("The annual plan includes a 7-day free trial when available.")
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

    private var primaryCTA: String {
        switch selectedPlan {
        case .yearly:
            "Start 7-Day Free Trial"
        case .monthly:
            "Subscribe Monthly"
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
    private func planCard(
        title: String,
        subtitle: String,
        badge: String?,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            PlushCard(compact: true) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(PetTheme.ink)

                            if let badge {
                                Text(badge)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(PetTheme.accentDeep)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(PetTheme.petMint.opacity(0.8), in: Capsule())
                            }
                        }

                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(PetTheme.muted)
                    }

                    Spacer()

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isSelected ? PetTheme.accentDeep : PetTheme.muted.opacity(0.7))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? PetTheme.accentDeep.opacity(0.5) : .clear, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
    }
}

private enum AppStoreLinks {
    static let privacyPolicy = URL(string: "https://casstao1.github.io/TailyDose/privacy-policy.html")!
    static let termsOfUse = URL(string: "https://casstao1.github.io/TailyDose/terms-of-use.html")!
    static let support = URL(string: "https://casstao1.github.io/TailyDose/support.html")!
}
