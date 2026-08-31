//
//  SubscriptionStore.swift
//  mac_cleaner
//

import Foundation
import StoreKit
import Combine

final class SubscriptionStore: ObservableObject {
    static let monthlyProductID = "shan.maccleaner.plus.pro.monthly"
    static let yearlyProductID = "shan.maccleaner.plus.pro.yearly"
    static let lifetimeProductID = "shan.maccleaner.plus.pro.lifetime"
    static let productIDs: Set<String> = [monthlyProductID, yearlyProductID, lifetimeProductID]

    @Published private(set) var products: [Product] = []
    @Published private(set) var isPro = false
    @Published private(set) var isLoading = false
    @Published private(set) var purchaseError: String?
    @Published private(set) var expirationDate: Date?
    @Published private(set) var activeProductID: String?
    @Published private(set) var isEligibleForIntroOffer = false

    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = listenForTransactions()
        Task { @MainActor in
            await self.refresh()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var monthlyProduct: Product? {
        products.first { $0.id == Self.monthlyProductID }
    }

    var yearlyProduct: Product? {
        products.first { $0.id == Self.yearlyProductID }
    }

    var lifetimeProduct: Product? {
        products.first { $0.id == Self.lifetimeProductID }
    }

    var statusLabel: String {
        if isPro {
            switch activeProductID {
            case Self.lifetimeProductID:
                return "Pro · Lifetime"
            case Self.yearlyProductID:
                if let expirationDate {
                    return "Pro · Annual · renews \(expirationDate.formatted(date: .abbreviated, time: .omitted))"
                }
                return "Pro · Annual"
            case Self.monthlyProductID:
                if let expirationDate {
                    return "Pro · Monthly · renews \(expirationDate.formatted(date: .abbreviated, time: .omitted))"
                }
                return "Pro · Monthly"
            default:
                if let expirationDate {
                    return "Pro · renews \(expirationDate.formatted(date: .abbreviated, time: .omitted))"
                }
                return "Pro active"
            }
        }
        if isEligibleForIntroOffer {
            return "Free · 3-day trial available"
        }
        return "Free plan"
    }

    @MainActor
    func refresh() async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            purchaseError = error.localizedDescription
        }

        await updateEntitlements()
        await updateIntroEligibility()
    }

    @MainActor
    func purchase(_ product: Product) async -> Bool {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                apply(transaction)
                await transaction.finish()
                await updateEntitlements(fallback: transaction)
                await updateIntroEligibility()
                return true
            case .userCancelled:
                return false
            case .pending:
                purchaseError = "Purchase is pending approval."
                return false
            @unknown default:
                return false
            }
        } catch {
            purchaseError = error.localizedDescription
            return false
        }
    }

    @MainActor
    func restore() async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updateEntitlements()
            await updateIntroEligibility()
            if !isPro {
                purchaseError = "No active subscription found."
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    #if DEBUG
    @MainActor
    func unlockProForDebug() {
        isPro = true
        activeProductID = Self.lifetimeProductID
        expirationDate = nil
    }
    #endif

    @MainActor
    private func apply(_ transaction: Transaction) {
        isPro = true
        activeProductID = transaction.productID
        if transaction.productID == Self.lifetimeProductID {
            expirationDate = nil
        } else {
            expirationDate = transaction.expirationDate
        }
    }

    @MainActor
    private func updateEntitlements(fallback: Transaction? = nil) async {
        var bestTransaction: Transaction?
        var bestRank = -1

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard Self.productIDs.contains(transaction.productID) else { continue }
            if transaction.revocationDate != nil { continue }

            let rank = Self.rank(for: transaction.productID)
            if rank >= bestRank {
                bestRank = rank
                bestTransaction = transaction
            }
        }

        if let bestTransaction {
            apply(bestTransaction)
        } else if let fallback {
            // Entitlements can lag right after purchase; keep the verified transaction.
            apply(fallback)
        } else {
            isPro = false
            activeProductID = nil
            expirationDate = nil
        }
    }

    private static func rank(for productID: String) -> Int {
        switch productID {
        case lifetimeProductID: return 3
        case yearlyProductID: return 2
        case monthlyProductID: return 1
        default: return 0
        }
    }

    @MainActor
    private func updateIntroEligibility() async {
        if let monthly = monthlyProduct, let sub = monthly.subscription {
            isEligibleForIntroOffer = await sub.isEligibleForIntroOffer
            return
        }
        if let yearly = yearlyProduct, let sub = yearly.subscription {
            isEligibleForIntroOffer = await sub.isEligibleForIntroOffer
            return
        }
        isEligibleForIntroOffer = true
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await MainActor.run {
                        self.apply(transaction)
                    }
                    await self.updateEntitlements()
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }
}
