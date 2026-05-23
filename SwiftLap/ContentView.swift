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
            #if DEBUG
            switch Self.debugScreen {
            case "coachOverview": NavigationStack { CoachOverviewView() }
            case "coachLeaderboard": NavigationStack { CoachLeaderboardView() }
            default: CoachHomeView()
            }
            #else
            CoachHomeView()
            #endif
        } else {
            #if DEBUG
            switch Self.debugScreen {
            case "recents": NavigationStack { RecentsView() }
            case "goals": NavigationStack { GoalsView() }
            case "achievements": NavigationStack { AchievementsView() }
            case "insights": NavigationStack { InsightsView() }
            case "settings": NavigationStack { SettingsView() }
            case "training": NavigationStack { TrainingView() }
            case "meets": NavigationStack { MeetsView() }
            case "friends": NavigationStack { FriendsView() }
            case "video": NavigationStack { VideoView() }
            default: SwimmerHomeView()
            }
            #else
            SwimmerHomeView()
            #endif
        }
    }

    #if DEBUG
    /// Screenshot hook: launch with `-screen <name>`.
    static var debugScreen: String? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "-screen"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    #endif
}
