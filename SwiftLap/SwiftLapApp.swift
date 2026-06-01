//
//  SwiftLapApp.swift
//  SwiftLap (iOS)
//

import SwiftUI

@main
struct SwiftLapApp: App {
    @StateObject private var auth = AuthManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
        }
    }
}
