//
//  PaywallPricing.swift
//  mac_cleaner
//
//  Prices come only from StoreKit Product.displayPrice.
//  Never fall back to hardcoded currency amounts.
//

import StoreKit

enum PaywallPricing {
    static let unavailableLabel = "Unavailable"

    static func label(for product: Product?) -> String {
        product?.displayPrice ?? unavailableLabel
    }

    enum AutoRenewPeriod {
        case month
        case year

        var productTitle: String {
            switch self {
            case .month: return "Pro Monthly"
            case .year: return "Pro Yearly"
            }
        }

        var length: String {
            switch self {
            case .month: return "1 month"
            case .year: return "1 year"
            }
        }

        var unit: String {
            switch self {
            case .month: return "month"
            case .year: return "year"
            }
        }
    }

    /// Guideline 3.1.2 auto-renew disclosure. `displayPrice` must be StoreKit `Product.displayPrice`.
    static func autoRenewLegalText(displayPrice: String, period: AutoRenewPeriod) -> String {
        let renewalPrice = pricePerUnit(displayPrice, unit: period.unit)
        return """
        \(period.productTitle). Length: \(period.length). Price: \(renewalPrice). \
        A 3-day free trial is available to eligible new subscribers. Any unused portion of a free trial is forfeited if you purchase a subscription. \
        Payment will be charged to your Apple ID account at confirmation of purchase, or at the end of the trial if you do not cancel. \
        Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period. \
        Your account will be charged for renewal within 24 hours prior to the end of the current period at \(renewalPrice). \
        You can manage and cancel your subscription in Account Settings after purchase.
        """
    }

    static func lifetimeLegalText(displayPrice: String) -> String {
        let price = displayPrice == unavailableLabel ? "the price shown above" : displayPrice
        return """
        Pro Lifetime is a one-time purchase of \(price), charged to your Apple ID account at confirmation of purchase. \
        It does not auto-renew. Restore purchases on any Mac signed in with the same Apple ID.
        """
    }

    private static func pricePerUnit(_ displayPrice: String, unit: String) -> String {
        if displayPrice == unavailableLabel {
            return "the price shown above per \(unit)"
        }
        return "\(displayPrice) per \(unit)"
    }
}
