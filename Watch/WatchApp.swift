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

/// Local store for the linked swimmer id (replaces the old APIService storage).
enum WatchStore {
    private static let key = "swimmerId"
    static func swimmerId() -> String? { UserDefaults.standard.string(forKey: key) }
    static func setSwimmerId(_ id: String) { UserDefaults.standard.set(id, forKey: key) }
    static func clear() { UserDefaults.standard.removeObject(forKey: key) }
}
