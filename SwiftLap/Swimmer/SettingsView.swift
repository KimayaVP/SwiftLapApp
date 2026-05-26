//
//  SettingsView.swift
//  SwiftLap (iOS)
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var showOnLeaderboard = true
    @State private var watch: WatchStatus?
    @State private var generatedCode: String?
    @State private var loading = true
    @State private var showDeleteConfirm = false

    var body: some View {
        List {
            Section("Leaderboard") {
                Toggle("Show me on the coach leaderboard", isOn: $showOnLeaderboard)
                    .onChange(of: showOnLeaderboard) { _, newValue in
                        Task { await setVisibility(newValue) }
                    }
            }

            Section("Apple Watch") {
                if let w = watch, w.linked {
                    Label("Watch linked · \(w.workoutCount) workout\(w.workoutCount == 1 ? "" : "s") synced",
                          systemImage: "applewatch")
                    Button("Generate New Code") { Task { await genCode() } }
                    Button("Unlink Watch", role: .destructive) { Task { await unlink() } }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Get SwiftLap on your Apple Watch").font(.caption.weight(.semibold))
                        Text("It usually installs automatically with this app. If it's not there, open the Watch app on your iPhone → Available Apps → install SwiftLap. Then open it on your watch and enter a code below.")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Text("No watch linked yet. Generate a code and enter it on your Apple Watch.")
                        .font(.caption).foregroundStyle(.secondary)
                    Button("Generate Watch Code") { Task { await genCode() } }
                }
                if let code = generatedCode {
                    VStack(spacing: 4) {
                        Text("Your code").font(.caption).foregroundStyle(.secondary)
                        Text(code).font(.system(size: 32, weight: .bold, design: .rounded)).foregroundStyle(.cyan)
                        Text("Enter on your watch (expires in 10 min)").font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
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
        .task { await load() }
        .alert("Delete Account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { Task { await auth.deleteAccount() } }
        } message: {
            Text("This permanently deletes your account and all your data. This cannot be undone.")
        }
    }

    private func load() async {
        guard let id = auth.currentUser?.id else { return }
        loading = true
        showOnLeaderboard = (try? await APIClient.shared.fetchLeaderboardVisibility(swimmerId: id)) ?? true
        watch = try? await APIClient.shared.watchStatus(swimmerId: id)
        loading = false
    }

    private func setVisibility(_ value: Bool) async {
        guard let id = auth.currentUser?.id else { return }
        try? await APIClient.shared.setLeaderboardVisibility(swimmerId: id, show: value)
    }

    private func genCode() async {
        guard let id = auth.currentUser?.id else { return }
        generatedCode = try? await APIClient.shared.generateWatchCode(swimmerId: id)
    }

    private func unlink() async {
        guard let id = auth.currentUser?.id else { return }
        try? await APIClient.shared.unlinkWatch(swimmerId: id)
        generatedCode = nil
        watch = try? await APIClient.shared.watchStatus(swimmerId: id)
    }
}
