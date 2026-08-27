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
            if activeProductID == Self.lifetimeProductID {
                return "Pro · Lifetime"
            }
            if let expirationDate {
                return "Pro · renews \(expirationDate.formatted(date: .abbreviated, time: .omitted))"
            }
            return "Pro active"
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
                await transaction.finish()
                await updateEntitlements()
                return isPro
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
    private func updateEntitlements() async {
        var entitled = false
        var expiry: Date?
        var productID: String?

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard Self.productIDs.contains(transaction.productID) else { continue }
            if transaction.revocationDate != nil { continue }
            entitled = true
            productID = transaction.productID
            expiry = transaction.expirationDate
            if transaction.productID == Self.lifetimeProductID {
                expiry = nil
            }
        }

        isPro = entitled
        expirationDate = expiry
        activeProductID = productID
    }

    @MainActor
    private func updateIntroEligibility() async {
        // Prefer monthly (primary trial plan); fall back to yearly.
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
