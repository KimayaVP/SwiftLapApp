//
//  FriendsView.swift
//  SwiftLap (iOS)
//

import SwiftUI

struct FriendsView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var groups: [FriendGroup] = []
    @State private var loading = true
    @State private var showCreate = false
    @State private var showJoin = false
    @State private var createdCode: String?      // set after creating; shown once the sheet closes
    @State private var showCreatedAlert = false

    var body: some View {
        List {
            Section("Your Groups") {
                if loading {
                    ProgressView()
                } else if groups.isEmpty {
                    Text("No groups yet").foregroundStyle(.secondary)
                } else {
                    ForEach(groups) { g in
                        NavigationLink { GroupLeaderboardView(group: g) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(g.name).font(.subheadline.weight(.medium))
                                if let code = g.inviteCode { Text("Invite code: \(code)").font(.caption2).foregroundStyle(.secondary) }
                            }
                        }
                    }
                }
            }
            Section {
                Button("Create Group") { showCreate = true }
                Button("Join Group") { showJoin = true }
            }
        }
        .navigationTitle("Friends")
        .sheet(isPresented: $showCreate, onDismiss: {
            // Present the "share this code" alert only after the sheet has fully
            // closed — presenting it during dismissal makes SwiftUI drop it.
            if createdCode != nil { showCreatedAlert = true }
        }) {
            TextEntrySheet(title: "Create Group", placeholder: "Group name", actionLabel: "Create") { name in
                await create(name)
            }
        }
        .alert("Group created", isPresented: $showCreatedAlert, presenting: createdCode) { _ in
            Button("OK") { createdCode = nil }
        } message: { code in
            Text("Share this invite code with friends so they can join:\n\n\(code)")
        }
        .sheet(isPresented: $showJoin) {
            TextEntrySheet(title: "Join Group", placeholder: "Invite code", actionLabel: "Join") { code in
                await join(code)
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard let id = auth.currentUser?.id else { return }
        loading = true
        groups = (try? await APIClient.shared.fetchGroups(swimmerId: id)) ?? []
        loading = false
    }

    private func create(_ name: String) async {
        guard let id = auth.currentUser?.id, !name.isEmpty else { return }
        // `try?` on a throwing call returning String? yields String??; flatten it.
        createdCode = (try? await APIClient.shared.createGroup(name: name, swimmerId: id)) ?? nil
        await load()
    }

    private func join(_ code: String) async {
        guard let id = auth.currentUser?.id, !code.isEmpty else { return }
        try? await APIClient.shared.joinGroup(code: code, swimmerId: id)
        await load()
    }
}

struct GroupLeaderboardView: View {
    @EnvironmentObject var auth: AuthManager
    let group: FriendGroup

    @State private var entries: [LeaderboardEntry] = []
    @State private var loading = true

    var body: some View {
        List {
            if let code = group.inviteCode {
                Section { Text("Invite code: \(code)").font(.subheadline) }
            }
            Section("Leaderboard") {
                if loading {
                    ProgressView()
                } else if entries.isEmpty {
                    Text("No members ranked yet").foregroundStyle(.secondary)
                } else {
                    ForEach(entries) { e in
                        HStack {
                            Text("#\(e.rank ?? 0)").font(.headline).foregroundStyle(.cyan).frame(width: 40, alignment: .leading)
                            Text(e.name)
                            Spacer()
                            Text(e.compositeScore.map { String(format: "%.0f", $0) } ?? "-")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            entries = (try? await APIClient.shared.groupLeaderboard(groupId: group.id)) ?? []
            loading = false
        }
    }
}

private struct TextEntrySheet: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let placeholder: String
    let actionLabel: String
    let onSubmit: (String) async -> Void

    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form { TextField(placeholder, text: $text) }
                .navigationTitle(title)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(actionLabel) { Task { await onSubmit(text); dismiss() } }.disabled(text.isEmpty)
                    }
                }
        }
    }
}
