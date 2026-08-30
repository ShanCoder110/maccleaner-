//
//  AppLegal.swift
//  mac_cleaner
//
//  In-app privacy policy is the functional Guideline 5.1.1 / 3.1.2 link.
//  Host docs/privacy.html and set hostedPrivacyPolicyURL before App Store Connect.
//

import Foundation

enum AppLegal {
    static let supportEmail = "raffayshahzad8015@gmail.com"

    static var supportMailtoURL: URL {
        URL(string: "mailto:\(supportEmail)")!
    }

    /// Public https page for App Store Connect metadata. Nil until you host `docs/privacy.html`.
    /// Do not use example.com — a 404 or placeholder fails review.
    static let hostedPrivacyPolicyURL: URL? = nil

    static let termsOfUseURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    static let privacyPolicyTitle = "Privacy Policy"

    static let privacyPolicyText = """
    Last updated: 30 August 2026

    MacCleaner+ is a sandboxed Mac App Store storage manager. This policy describes what the app accesses on your Mac and what it does not collect.

    Contact
    \(supportEmail)

    Data we do not collect
    MacCleaner+ does not include analytics, advertising, crash reporters, or other telemetry. It does not create an account, does not sign you in, and does not upload your files, folder listings, or scan results.

    What the app accesses on your Mac
    • Folders you explicitly grant through the macOS folder picker. Those grants are stored on this Mac as app-scoped security-scoped bookmarks.
    • Your Downloads folder when you use that location (declared entitlement).
    • Applications you choose to uninstall, plus leftover files only inside folders you have authorized.
    • Trash, only to move items you confirm. The app uses FileManager.trashItem — it does not permanently delete files.

    The app never requires Full Disk Access. It does not scan locations you have not authorized.

    Purchases
    Monthly, yearly, and lifetime Pro purchases are processed by Apple through StoreKit. We do not receive your payment card number or Apple ID password. Manage or cancel subscriptions in System Settings → Apple ID → Subscriptions.

    Data stored on this Mac
    Bookmarks, appearance, leftover-matching sensitivity, onboarding completion, and the local activity log stay on your Mac. They are not sent to us.

    Sharing
    We do not sell personal data. The app has no third-party advertising or analytics SDKs.

    Children’s privacy
    MacCleaner+ is a general utility and is not directed at children.

    Changes
    If this policy changes, the updated text ships in the app.

    Contact
    Questions about privacy: \(supportEmail)
    """
}
