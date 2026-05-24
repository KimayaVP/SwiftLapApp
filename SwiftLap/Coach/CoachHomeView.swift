//
//  CoachHomeView.swift
//  SwiftLap (iOS)
//
//  Coach landing screen — native tile grid mirroring the web coach dashboard.
//

import SwiftUI

struct CoachHomeView: View {
    @EnvironmentObject var auth: AuthManager
    @State private var showInvite = false
    @State private var showDeleteConfirm = false

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    NavigationLink { CoachOverviewView() } label: { Tile(icon: "chart.bar.doc.horizontal", title: "Team Overview") }
                    NavigationLink { CoachLeaderboardView() } label: { Tile(icon: "trophy.fill", title: "Leaderboard") }
                    NavigationLink { CoachBatchesView() } label: { Tile(icon: "person.3.fill", title: "Batches & Swimmers") }
                    NavigationLink { CoachRecommendView() } label: { Tile(icon: "flag.checkered", title: "Recommend Meet") }
                    NavigationLink { CoachAssignView() } label: { Tile(icon: "target", title: "Assign") }
                }
                .padding()
            }
            .navigationTitle("Hi, \(firstName)")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("👨‍🏫 Coach").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showInvite = true } label: { Label("Invite Swimmer", systemImage: "person.badge.plus") }
                        Button(role: .destructive) { auth.logout() } label: { Label("Log out", systemImage: "rectangle.portrait.and.arrow.right") }
                        Button(role: .destructive) { showDeleteConfirm = true } label: { Label("Delete Account", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showInvite) { CoachInviteView() }
            .alert("Delete Account?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { Task { await auth.deleteAccount() } }
            } message: {
                Text("This permanently deletes your account and all your data. This cannot be undone.")
            }
        }
    }

    private var firstName: String {
        (auth.currentUser?.name ?? "").split(separator: " ").first.map(String.init) ?? "Coach"
    }
}
