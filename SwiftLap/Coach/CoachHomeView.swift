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
    @State private var showReview = false
    @State private var pendingCount = 0

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
                    BrandMark(role: "coach")
                }
                ToolbarItem(placement: .topBarTrailing) { NotificationsBell() }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showReview = true } label: {
                        Image(systemName: "play.rectangle")
                            .overlay(alignment: .topTrailing) {
                                if pendingCount > 0 {
                                    Text(pendingCount > 9 ? "9+" : "\(pendingCount)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 4).padding(.vertical, 1)
                                        .background(Capsule().fill(Theme.coral))
                                        .offset(x: 9, y: -8)
                                }
                            }
                    }
                    .accessibilityLabel("Videos to review")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showInvite = true } label: { Label("Invite Swimmer", systemImage: "person.badge.plus") }
                        if auth.biometricAvailable {
                            Button {
                                if auth.biometricEnabled { auth.disableBiometricLogin() }
                                else { Task { await auth.enableBiometricLogin() } }
                            } label: {
                                Label(auth.biometricEnabled ? "Disable \(auth.biometricTypeName) login" : "Enable \(auth.biometricTypeName) login",
                                      systemImage: auth.biometricEnabled ? "lock.open" : "faceid")
                            }
                        }
                        Button(role: .destructive) { auth.logout() } label: { Label("Log out", systemImage: "rectangle.portrait.and.arrow.right") }
                        Button(role: .destructive) { showDeleteConfirm = true } label: { Label("Delete Account", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .task { await loadPending() }
            .sheet(isPresented: $showReview, onDismiss: { Task { await loadPending() } }) {
                PendingReviewView().environmentObject(auth)
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

    private func loadPending() async {
        guard let id = auth.currentUser?.id else { return }
        pendingCount = (try? await APIClient.shared.pendingReviewVideos(coachId: id))?.count ?? 0
    }
}

// MARK: - Review queue (videos awaiting coach feedback)

struct PendingReviewView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var items: [PendingVideo] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            List {
                if loading {
                    ProgressView()
                } else if items.isEmpty {
                    Text("No videos waiting for review 🎉").foregroundStyle(.secondary)
                } else {
                    ForEach(items) { v in
                        NavigationLink {
                            CoachSwimmerView(swimmer: CoachSwimmer(
                                id: v.swimmerId, name: v.swimmerName, status: "no_goals",
                                goalsCount: nil, goalsAhead: nil, sessionsThisMonth: nil, streak: nil))
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.swimmerName).font(.subheadline.weight(.medium))
                                Text("\(v.stroke)\(v.createdAt.map { " · " + shortDate($0) } ?? "")")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Videos to Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task { await load() }
        }
    }

    private func load() async {
        guard let id = auth.currentUser?.id else { return }
        loading = true
        items = (try? await APIClient.shared.pendingReviewVideos(coachId: id)) ?? []
        loading = false
    }

    private func shortDate(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        if let d = f.date(from: iso) {
            let o = DateFormatter(); o.dateStyle = .medium
            return o.string(from: d)
        }
        return String(iso.prefix(10))
    }
}
