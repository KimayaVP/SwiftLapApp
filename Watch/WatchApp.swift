//
//  WatchApp.swift
//  SwiftLap (watchOS)
//
//  Migrated from the standalone SwiftLapWatch repo into the unified project.
//

import SwiftUI

@main
struct SwiftLapWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}

/// Local store for the linked swimmer id + the device token that authenticates
/// this watch when syncing workouts.
enum WatchStore {
    private static let key = "swimmerId"
    private static let tokenKey = "watchToken"
    static func swimmerId() -> String? { UserDefaults.standard.string(forKey: key) }
    static func setSwimmerId(_ id: String) { UserDefaults.standard.set(id, forKey: key) }
    static func watchToken() -> String? { UserDefaults.standard.string(forKey: tokenKey) }
    static func setWatchToken(_ t: String?) {
        if let t { UserDefaults.standard.set(t, forKey: tokenKey) }
        else { UserDefaults.standard.removeObject(forKey: tokenKey) }
    }
    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: tokenKey)
    }
}
