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
}
