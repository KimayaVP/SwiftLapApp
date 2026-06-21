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
    @State private var showReview = false
    @State private var showContact = false
    @State private var showSettings = false
    @State private var pendingCount = 0

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    BrandMark(role: "coach")
                    LazyVGrid(columns: columns, spacing: 14) {
                        NavigationLink { CoachOverviewView() } label: { Tile(icon: "chart.bar.doc.horizontal", title: "Team Overview") }
                        NavigationLink { CoachLeaderboardView() } label: { Tile(icon: "trophy.fill", title: "Leaderboard") }
                        NavigationLink { CoachBatchesView() } label: { Tile(icon: "person.3.fill", title: "Batches & Swimmers") }
                        NavigationLink { CoachRecommendView() } label: { Tile(icon: "flag.checkered", title: "Recommend Meet") }
                        NavigationLink { CoachAssignView() } label: { Tile(icon: "target", title: "Assign") }
                    }
                    .buttonStyle(.plain)   // suppress iOS 26 Liquid-Glass halo on the tiles
                }
                .padding()
            }
            .navigationTitle("Hi, \(firstName)")
            .toolbar {
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
                    Button { showInvite = true } label: { Image(systemName: "person.badge.plus") }
                        .accessibilityLabel("Invite Swimmer")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showContact = true } label: { Image(systemName: "envelope") }
                        .accessibilityLabel("Contact & Feedback")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
            .task { await loadPending() }
            .sheet(isPresented: $showReview, onDismiss: { Task { await loadPending() } }) {
                PendingReviewView().environmentObject(auth)
            }
            .sheet(isPresented: $showInvite) { CoachInviteView() }
            .sheet(isPresented: $showContact) {
                NavigationStack {
                    ContactFeedbackView()
                        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showContact = false } } }
                }
            }
            .sheet(isPresented: $showSettings) { CoachSettingsView() }
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

// MARK: - Coach Settings (Security + Log out + Delete)
// The coach now has a real Settings screen mirroring the swimmer's (minus the
// swimmer-only Leaderboard/Apple Watch rows), reached from a gear icon.

struct CoachSettingsView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var faceIDOn = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                if auth.biometricAvailable {
                    Section {
                        Toggle("Log in with \(auth.biometricTypeName)", isOn: $faceIDOn)
                            .onChange(of: faceIDOn) { _, newValue in
                                Task {
                                    if newValue {
                                        let ok = await auth.enableBiometricLogin()
                                        if !ok { faceIDOn = false }
                                    } else {
                                        auth.disableBiometricLogin()
                                    }
                                }
                            }
                        if let e = auth.biometricError { Text(e).font(.caption).foregroundStyle(Theme.coral) }
                    } header: {
                        Text("Security")
                    } footer: {
                        Text("Unlock SwiftLap with \(auth.biometricTypeName) instead of retyping your login. You'll still sign in normally on a new device.")
                    }
                }

                Section {
                    Button("Log out", role: .destructive) { auth.logout() }
                }

                Section {
                    Button("Delete Account", role: .destructive) { showDeleteConfirm = true }
                } footer: {
                    Text("Permanently deletes your account and all your data. This cannot be undone.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .onAppear { faceIDOn = auth.biometricEnabled }
            .alert("Delete Account?", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { Task { await auth.deleteAccount() } }
            } message: {
                Text("This permanently deletes your account and all your data. This cannot be undone.")
            }
        }
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
