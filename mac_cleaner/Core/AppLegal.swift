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

    static var supportMailtoURL: URL {
        URL(string: "mailto:\(supportEmail)")!
    }

    /// Dummy URL — replace with your live Google Sites privacy page before App Store submit.
    static let hostedPrivacyPolicyURL = URL(string: "https://sites.google.com/view/maccleaner-plus/privacy")!

    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
