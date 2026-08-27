//
//  FeatureGate.swift
//  mac_cleaner
//

import Foundation

enum FeatureGate {
    static func requiresPro(for destination: AppDestination) -> Bool {
        destination.requiresPro
    }

    /// Clean Junk on Smart Scan is a Pro action.
    static var cleanJunkRequiresPro: Bool { true }
}
