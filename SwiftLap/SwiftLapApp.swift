//
//  SwiftLapApp.swift
//  SwiftLap (iOS)
//

import SwiftUI

@main
struct SwiftLapApp: App {
    @StateObject private var auth = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
        }
    }
}
