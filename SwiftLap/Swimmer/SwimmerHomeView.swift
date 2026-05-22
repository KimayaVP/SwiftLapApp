//
//  SwimmerHomeView.swift
//  SwiftLap (iOS)
//
//  Swimmer landing screen: greeting, no-coach banner, and a native tile grid
//  that navigates to each feature. (Coach linking is invite-only — swimmers
//  cannot request a coach; they accept invites instead.)
//

import SwiftUI

struct SwimmerHomeView: View {
    @EnvironmentObject var auth: AuthManager

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if auth.currentUser?.coachId == nil {
                        noCoachBanner
                    }
                    LazyVGrid(columns: columns, spacing: 14) {
                        NavigationLink { RecentsView() } label: { Tile(icon: "chart.bar.fill", title: "Recents") }
                        NavigationLink { GoalsView() } label: { Tile(icon: "target", title: "Goals") }
                        NavigationLink { TrainingView() } label: { Tile(icon: "calendar", title: "Training") }
                        NavigationLink { MeetsView() } label: { Tile(icon: "flag.checkered", title: "Meets & Races") }
                        NavigationLink { InsightsView() } label: { Tile(icon: "chart.line.uptrend.xyaxis", title: "Insights & Rank") }
                        NavigationLink { AchievementsView() } label: { Tile(icon: "medal.fill", title: "Achievements") }
                        NavigationLink { VideoView() } label: { Tile(icon: "video.fill", title: "Video & Feedback") }
                        NavigationLink { FriendsView() } label: { Tile(icon: "person.2.fill", title: "Friends") }
                    }
                }
                .padding()
            }
            .navigationTitle("Hi, \(firstName)")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("🏊 Swimmer").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        NavigationLink { SettingsView() } label: { Label("Settings", systemImage: "gearshape") }
                        Button(role: .destructive) { auth.logout() } label: { Label("Log out", systemImage: "rectangle.portrait.and.arrow.right") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private var firstName: String {
        (auth.currentUser?.name ?? "").split(separator: " ").first.map(String.init) ?? "there"
    }

    private var noCoachBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🏊 Training Solo").font(.headline)
            Text("You're not linked to a coach yet. Ask your coach to send you an invite from their SwiftLap account.")
                .font(.subheadline).foregroundStyle(.secondary)
            Text("Coach not on SwiftLap yet? Ask them to sign up — then they can invite you.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.3)))
    }
}

struct Tile: View {
    let icon: String
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30))
                .foregroundStyle(.cyan)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 110)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
}
