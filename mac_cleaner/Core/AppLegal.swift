//
//  AppLegal.swift
//  mac_cleaner
//
//  Privacy Policy is the hosted Google Sites page (Guideline 5.1.1 / 3.1.2).
//  Paywall and Settings open this URL. Paste the same URL in App Store Connect.
//

import Foundation

enum AppLegal {
    static let supportEmail = "support.devshan@gmail.com"

    /// Dock, menu bar extra, and Finder icon label.
    static let shortName = "Mac Cleaner"

    /// In-app product name.
    static let displayName = "Mac Cleaner: Clean Up Storage"

    static var supportMailtoURL: URL {
        URL(string: "mailto:\(supportEmail)")!
    }

    /// Public https pages for App Store Connect and in-app Privacy Policy / Terms links.
    static let hostedPrivacyPolicyURL = URL(string: "https://sites.google.com/view/mac--cleaner/privacy-policy")!

    static let termsOfUseURL = URL(string: "https://sites.google.com/view/mac--cleaner/terms-of-use")!

    static let appStoreID = "6805994086"

    /// Opens the Mac App Store write-review page.
    static let rateUsURL = URL(string: "https://apps.apple.com/app/id\(appStoreID)?action=write-review")!
}
