//
//  AppStoreReviewNotes.swift
//  mac_cleaner
//
//  Paste `fullReviewNotes` into App Store Connect → App Review Information → Notes
//  (limit is 4,000 characters). Paste `sandboxJustification` if Review asks about
//  Guideline 2.4.5(i) after removing the /.Trash temporary exception.
//

import Foundation

enum AppStoreReviewNotes {
    static let fullReviewNotes = """
    Mac Cleaner: Clean Up Storage (bundle ID shan.maccleaner.plus)

    WHAT IT IS
    A sandboxed macOS storage manager. It scans only folders the user grants with NSOpenPanel and persists those grants with app-scoped security-scoped bookmarks. All deletion asks Finder to move items to Trash via NSWorkspace.recycle — never FileManager.trashItem or FileManager.removeItem — so users can restore from Trash. It is not a speed booster, RAM cleaner, antivirus, or security tool.

    NO DEMO ACCOUNT
    There is no login. Review on a Mac with a Sandbox Apple ID if you test In-App Purchase.

    HOW TO REVIEW
    1. First launch shows folder access. Grant Caches (suggested). Optionally grant /Applications to uninstall apps to Trash. Skip / Continue Without Folders is allowed.
    2. Free: Smart Scan, Applications, Duplicates, Activity, Settings.
    3. Pro: Space Cleaner, Large Files, Space Lens, Orphans, and Clean Junk from Smart Scan. Open Upgrade to Pro in the sidebar.
    4. Paywall includes Restore Purchases plus Privacy Policy and Terms of Use links.
    5. Listing apps from /Applications does not require a grant. Moving an app to Trash prompts for /Applications (or ~/Applications).

    SANDBOX (Guideline 2.4.5)
    App Sandbox and Hardened Runtime are on. Entitlements: user-selected files read-write and app-scoped bookmarks only.

    The previous temporary exception for /.Trash has been removed. Trashing uses NSWorkspace.recycle so Finder performs the move. The app does not write to ~/.Trash, does not list other users’ Trash, does not request Full Disk Access, does not use helpers or privilege escalation, and does not tell users to run sudo.

    There is no Downloads-folder entitlement. Downloads, Desktop, Documents, and volumes are accessed only after the user grants a folder in NSOpenPanel.

    IN-APP PURCHASE (Guideline 3.1.2)
    Subscription group: Mac Cleaner Pro
    • shan.maccleaner.plus.pro.monthly — auto-renewable, 1 month, 3-day free trial for eligible new subscribers
    • shan.maccleaner.plus.pro.yearly — auto-renewable, 1 year, 3-day free trial for eligible new subscribers
    • shan.maccleaner.plus.pro.lifetime — non-consumable, no trial

    Prices come from StoreKit (not hardcoded). The paywall states title, length, price, trial, charge at confirmation, auto-renew, 24-hour renewal charge, unused-trial forfeiture, and how to cancel in Account Settings.

    LINKS (must be public, no sign-in)
    Privacy: https://sites.google.com/view/mac--cleaner/privacy-policy
    Terms: https://sites.google.com/view/mac--cleaner/terms-of-use
    Support: support.devshan@gmail.com
    """

    /// Guideline 2.4.5(i) sandbox justification after removing the Trash exception.
    static let sandboxJustification = """
    Mac Cleaner: Clean Up Storage is fully sandboxed (com.apple.security.app-sandbox). It only \
    scans folders the user grants through NSOpenPanel and persists those grants \
    with app-scoped security-scoped bookmarks.

    All deletion uses NSWorkspace.recycle — never FileManager.trashItem or \
    FileManager.removeItem — so Finder moves items to the user’s Trash and the \
    user can restore them. The app does not request a temporary exception for \
    ~/.Trash and does not write to that path itself.

    The app does not read or list other users’ Trash contents as a feature. It \
    does not request Full Disk Access, does not use privilege escalation, and \
    does not scan locations the user has not authorized.
    """
}
