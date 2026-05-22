//
//  ContentView.swift
//  SwiftLap (iOS)
//
//  Top-level gate: show login when signed out, the app shell when signed in.
//  Real swimmer/coach tabs land in M4/M5.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        if auth.currentUser == nil {
            LoginView()
        } else {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        TabView {
            HomePlaceholder()
                .tabItem { Label("Home", systemImage: "house.fill") }
            ProfilePlaceholder()
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .tint(.cyan)
    }
}

private struct HomePlaceholder: View {
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.pool.swim")
                .font(.system(size: 56))
                .foregroundStyle(.cyan)
            Text("Welcome, \(auth.currentUser?.name ?? "")!")
                .font(.title2.bold())
            if let role = auth.currentUser?.role {
                Text(role == "coach" ? "👨‍🏫 Coach" : "🏊 Swimmer")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

private struct ProfilePlaceholder: View {
    @EnvironmentObject var auth: AuthManager

    var body: some View {
        VStack(spacing: 16) {
            Text(auth.currentUser?.name ?? "")
                .font(.title2.bold())
            Text(auth.currentUser?.email ?? "")
                .foregroundStyle(.secondary)
            Button(role: .destructive) {
                auth.logout()
            } label: {
                Text("Log out").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 20)
        }
        .padding()
    }
}
