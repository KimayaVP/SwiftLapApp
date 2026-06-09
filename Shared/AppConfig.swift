//
//  AppConfig.swift
//  Shared (iOS + watch)
//
//  Central config shared by both apps. The API client (M2) builds on this.
//

import Foundation

enum AppConfig {
    /// The deployed SwiftLap backend. Both the iOS app and the watch app talk to this.
    static let apiBaseURL = URL(string: "https://swiftlap.in")!
}
