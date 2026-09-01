//
//  AppStoreReviewNotes.swift
//  mac_cleaner
//
//  Paste the justification below into App Store Connect Review Notes.
//  Keep the /.Trash temporary exception narrow — do not widen the path.
//

import Foundation

enum AppStoreReviewNotes {
    /// Guideline 2.4.5(i) sandbox + temporary exception justification.
    static let trashExceptionJustification = """
    Mac Cleaner: Clean Up Storage is fully sandboxed (com.apple.security.app-sandbox). It only \
    scans folders the user grants through NSOpenPanel and persists those grants \
    with app-scoped security-scoped bookmarks.

    All deletion uses FileManager.trashItem — never FileManager.removeItem — so \
    the user can restore files from Trash. Moving an authorized item to Trash \
    requires write access to ~/.Trash. The temporary exception \
    com.apple.security.temporary-exception.files.home-relative-path.read-write \
    is limited to the single path /.Trash for that purpose.

    The app does not read or list other users’ Trash contents as a feature. It \
    does not request Full Disk Access, does not use privilege escalation, and \
    does not scan locations the user has not authorized.
    """
}
