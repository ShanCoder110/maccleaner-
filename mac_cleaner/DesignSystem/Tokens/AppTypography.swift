//
//  AppTypography.swift
//  mac_cleaner
//
//  SF Pro system typography scale tuned for premium macOS utilities.
//

import SwiftUI

enum AppTypography {
    /// 28pt · semibold — hero / empty-state titles
    static let largeTitle = Font.system(size: 28, weight: .semibold, design: .default)

    /// 22pt · semibold — page titles
    static let title = Font.system(size: 22, weight: .semibold, design: .default)

    /// 17pt · semibold — card / section titles
    static let title2 = Font.system(size: 17, weight: .semibold, design: .default)

    /// 15pt · semibold — list headlines, sidebar labels
    static let headline = Font.system(size: 15, weight: .semibold, design: .default)

    /// 13pt · medium — emphasized body
    static let bodyMedium = Font.system(size: 13, weight: .medium, design: .default)

    /// 13pt · regular — primary body
    static let body = Font.system(size: 13, weight: .regular, design: .default)

    /// 12pt · medium — control labels, badges
    static let calloutMedium = Font.system(size: 12, weight: .medium, design: .default)

    /// 12pt · regular — secondary copy
    static let callout = Font.system(size: 12, weight: .regular, design: .default)

    /// 11pt · medium — meta labels
    static let captionMedium = Font.system(size: 11, weight: .medium, design: .default)

    /// 11pt · regular — captions, helper text
    static let caption = Font.system(size: 11, weight: .regular, design: .default)

    /// 10pt · medium — micro labels
    static let micro = Font.system(size: 10, weight: .medium, design: .default)

    /// Monospaced figures for sizes / metrics
    static let mono = Font.system(size: 13, weight: .medium, design: .monospaced)

    static let monoCaption = Font.system(size: 11, weight: .medium, design: .monospaced)
}
