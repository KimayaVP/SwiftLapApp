//
//  ContentView.swift
//  SwiftLap (iOS)
//
//  Top-level gate: login when signed out, swimmer or coach home when signed in.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        if auth.currentUser == nil {
            LoginView()
        } else if auth.currentUser?.role == "coach" {
            CoachHomePlaceholder()
        } else {
            #if DEBUG
            switch Self.debugScreen {
            case "recents": NavigationStack { RecentsView() }
            case "goals": NavigationStack { GoalsView() }
            case "achievements": NavigationStack { AchievementsView() }
            case "insights": NavigationStack { InsightsView() }
            case "settings": NavigationStack { SettingsView() }
            default: SwimmerHomeView()
            }
            #else
            SwimmerHomeView()
            #endif
        }
    }

    #if DEBUG
    /// Screenshot hook: launch with `-screen recents` / `-screen goals`.
    static var debugScreen: String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-screen"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    #endif
}

/// Coach side is built in M5.
struct CoachHomePlaceholder: View {
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.cyan)
                Text("Coach dashboard").font(.title2.bold())
                Text("Coming in M5").foregroundStyle(.secondary)
                Button(role: .destructive) { auth.logout() } label: {
                    Text("Log out")
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 12)
            }
            .padding()
            .navigationTitle("Hi, \(auth.currentUser?.name ?? "Coach")")
        }
    }
}
