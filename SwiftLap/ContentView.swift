//
//  ContentView.swift
//  SwiftLap (iOS)
//
//  App shell. Real auth + tabs land in later milestones; this confirms
//  the project builds and runs and that the Shared layer links in.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            HomePlaceholder()
                .tabItem { Label("Home", systemImage: "house.fill") }
            Text("Profile")
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .tint(.cyan)
    }
}

private struct HomePlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.pool.swim")
                .font(.system(size: 56))
                .foregroundStyle(.cyan)
            Text("SwiftLap")
                .font(.largeTitle.bold())
            Text("Track. Analyze. Improve.")
                .foregroundStyle(.secondary)
            Text("API: \(AppConfig.apiBaseURL.host() ?? "—")")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
