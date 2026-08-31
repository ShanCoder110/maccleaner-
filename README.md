# MacCleaner+

Sandboxed macOS storage manager and app uninstaller for the Mac App Store.

## Features

**Free**
- Smart Scan with live circular progress
- Applications uninstall (Trash) with related leftovers in granted folders
- Duplicates
- Activity log
- Settings (appearance, folder permissions, subscription)

**Pro**
- Space Cleaner (caches, logs, AI tool data)
- Large Files
- Space Lens
- Orphans
- Clean Junk from Smart Scan

## Requirements

- macOS 14.0+
- Xcode 16+
- Apple Developer account for App Store / TestFlight

## Bundle

| | |
|---|---|
| Display name | MacCleaner+ |
| Bundle ID | `shan.maccleaner.plus` |
| Version | 1.0 |

## Run locally

1. Open `mac_cleaner.xcodeproj` in Xcode
2. Select your signing **Team**
3. Run the `mac_cleaner` scheme (StoreKit Configuration: `Products.storekit` for local IAP)

On first launch, grant folder access (Caches, Logs, Application Support, etc.). Scanning only looks inside folders you authorize.

## Subscriptions (StoreKit)

| Product ID | Type |
|---|---|
| `shan.maccleaner.plus.pro.monthly` | Auto-renewable + 3-day trial |
| `shan.maccleaner.plus.pro.yearly` | Auto-renewable + 3-day trial |
| `shan.maccleaner.plus.pro.lifetime` | Non-consumable |

Privacy Policy is the hosted Google Sites URL in `AppLegal.hostedPrivacyPolicyURL` (paywall and Settings open it). Paste that same URL into App Store Connect. Support email is `AppLegal.supportEmail`. Paywall prices come only from StoreKit `Product.displayPrice`.

## Privacy & safety

- App Sandbox on
- User-selected folders via security-scoped bookmarks
- Deletes move items to **Trash** only
- No analytics / telemetry networking

## App Store upload

See `UPLOAD_CHECKLIST.md` and `APP_STORE_REVIEW_NOTES.md` in this repo (local docs; markdown is gitignored except this README).
