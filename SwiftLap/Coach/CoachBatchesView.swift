//
//  CoachBatchesView.swift
//  SwiftLap (iOS)
//
//  Swimmers grouped by batch (+ an Individuals group), create batches,
//  manage batch membership, and comment/award per swimmer.
//

import SwiftUI

struct CoachBatchesView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var swimmers: [CoachSwimmer] = []
    @State private var batches: [(batch: Batch, memberIds: [String])] = []
    @State private var loading = true
    @State private var showCreate = false

    var body: some View {
        List {
            ForEach(batches, id: \.batch.id) { entry in
                Section {
                    let members = swimmers.filter { entry.memberIds.contains($0.id) }
                    if members.isEmpty {
                        Text("No swimmers").foregroundStyle(.secondary)
                    } else {
                        ForEach(members) { swimmerLink($0) }
                    }
                } header: {
                    HStack {
                        Text("📦 \(entry.batch.name)")
                        Spacer()
                        NavigationLink("Manage") {
                            BatchManageView(batch: entry.batch) { Task { await load() } }
                        }
                        .font(.caption)
                    }
                }
            }

            Section("Individuals") {
                let inAny = Set(batches.flatMap { $0.memberIds })
                let indiv = swimmers.filter { !inAny.contains($0.id) }
                if indiv.isEmpty {
                    Text(loading ? "Loading…" : "None").foregroundStyle(.secondary)
                } else {
                    ForEach(indiv) { swimmerLink($0) }
                }
            }
        }
        .navigationTitle("Batches & Swimmers")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showCreate = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateBatchSheet { name in await createBatch(name) }
        }
        .task { await load() }
    }

    private func swimmerLink(_ s: CoachSwimmer) -> some View {
        NavigationLink { CoachSwimmerView(swimmer: s) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(s.name).font(.subheadline.weight(.medium))
                    Text("Goals \(s.goalsAhead ?? 0)/\(s.goalsCount ?? 0) · 🔥 \(s.streak ?? 0)")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text(statusIcon(s.status))
            }
        }
    }

    private func statusIcon(_ status: String) -> String {
        switch status { case "ahead": return "✅"; case "behind": return "🔻"; default: return "—" }
    }

    private func load() async {
        guard let id = auth.currentUser?.id else { return }
        loading = true
        swimmers = (try? await APIClient.shared.coachDashboard(coachId: id))?.swimmers ?? []
        let bs = (try? await APIClient.shared.fetchBatches(coachId: id)) ?? []
        var result: [(Batch, [String])] = []
        for b in bs {
            let members = (try? await APIClient.shared.batchLeaderboard(batchId: b.id)) ?? []
            result.append((b, members.map { $0.id }))
        }
        batches = result
        loading = false
    }

    private func createBatch(_ name: String) async {
        guard let id = auth.currentUser?.id, !name.isEmpty else { return }
        try? await APIClient.shared.createBatch(name: name, coachId: id)
        await load()
    }
}

// MARK: - Per-swimmer comment / award

struct CoachSwimmerView: View {
    @EnvironmentObject var auth: AuthManager
    let swimmer: CoachSwimmer

    @State private var comment = ""
    @State private var badgeMessage = ""
    @State private var selectedBadgeId: UUID?
    @State private var status: String?

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 10)]

    var body: some View {
        List {
            Section("Quick Reaction") {
                HStack(spacing: 16) {
                    ForEach(["🔥", "💪", "👏", "⭐️"], id: \.self) { r in
                        Button(r) { Task { await react(r) } }.font(.title2)
                    }
                }
            }
            Section("Comment") {
                TextField("Great job on your times!", text: $comment, axis: .vertical)
                Button("Send Comment") { Task { await sendComment() } }.disabled(comment.isEmpty)
            }
            Section("Award a Badge") {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(coachBadgeLibrary) { b in
                        Button { selectedBadgeId = b.id } label: {
                            VStack(spacing: 4) {
                                Text(b.icon).font(.title2)
                                Text(b.name).font(.caption2).multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 10)
                                .fill(selectedBadgeId == b.id ? Color.cyan.opacity(0.2) : Color(.secondarySystemBackground)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                TextField("Message (optional)", text: $badgeMessage)
                Button("Award Badge") { Task { await award() } }.disabled(selectedBadgeId == nil)
            }
            if let status { Text(status).font(.caption).foregroundStyle(.green) }
        }
        .navigationTitle(swimmer.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func react(_ emoji: String) async {
        guard let id = auth.currentUser?.id else { return }
        try? await APIClient.shared.addCoachComment(coachId: id, swimmerId: swimmer.id, comment: nil, reaction: emoji)
        status = "Reaction sent \(emoji)"
    }

    private func sendComment() async {
        guard let id = auth.currentUser?.id else { return }
        try? await APIClient.shared.addCoachComment(coachId: id, swimmerId: swimmer.id, comment: comment, reaction: nil)
        comment = ""
        status = "Comment sent"
    }

    private func award() async {
        guard let id = auth.currentUser?.id, let badge = coachBadgeLibrary.first(where: { $0.id == selectedBadgeId }) else { return }
        try? await APIClient.shared.awardBadge(coachId: id, swimmerId: swimmer.id, badgeName: badge.name, badgeIcon: badge.icon, message: badgeMessage.isEmpty ? nil : badgeMessage)
        badgeMessage = ""; selectedBadgeId = nil
        status = "Badge awarded 🏅"
    }
}

// MARK: - Batch manage

struct BatchManageView: View {
    @EnvironmentObject var auth: AuthManager
    let batch: Batch
    var onChange: () -> Void

    @State private var members: [LeaderboardEntry] = []
    @State private var available: [SwimmerRef] = []
    @State private var loading = true

    var body: some View {
        List {
            Section("Members") {
                if members.isEmpty {
                    Text(loading ? "Loading…" : "No swimmers").foregroundStyle(.secondary)
                } else {
                    ForEach(members) { m in
                        HStack {
                            Text(m.name)
                            Spacer()
                            Button("Remove", role: .destructive) { Task { await remove(m.id) } }.font(.caption)
                        }
                    }
                }
            }
            Section("Add Swimmer") {
                if available.isEmpty {
                    Text("Everyone is already in this batch").foregroundStyle(.secondary)
                } else {
                    ForEach(available) { s in
                        Button { Task { await add(s.id) } } label: { Label(s.name, systemImage: "plus.circle") }
                    }
                }
            }
            Section("Batch Leaderboard") {
                ForEach(members) { m in
                    HStack {
                        Text("#\(m.rank ?? 0)").foregroundStyle(.cyan).frame(width: 36, alignment: .leading)
                        Text(m.name)
                        Spacer()
                        Text(m.compositeScore.map { String(format: "%.0f", $0) } ?? "-").font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
        .navigationTitle(batch.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        guard let id = auth.currentUser?.id else { return }
        loading = true
        members = (try? await APIClient.shared.batchLeaderboard(batchId: batch.id)) ?? []
        available = (try? await APIClient.shared.batchAvailableSwimmers(batchId: batch.id, coachId: id)) ?? []
        loading = false
    }

    private func add(_ swimmerId: String) async {
        try? await APIClient.shared.addSwimmerToBatch(batchId: batch.id, swimmerId: swimmerId)
        await load(); onChange()
    }

    private func remove(_ swimmerId: String) async {
        try? await APIClient.shared.removeSwimmerFromBatch(batchId: batch.id, swimmerId: swimmerId)
        await load(); onChange()
    }
}

// MARK: - Helpers

struct BadgeOption: Identifiable {
    let id = UUID()
    let icon: String
    let name: String
}

let coachBadgeLibrary = [
    BadgeOption(icon: "🌟", name: "Star Performer"),
    BadgeOption(icon: "🏆", name: "Champion"),
    BadgeOption(icon: "🚀", name: "Most Improved"),
    BadgeOption(icon: "💎", name: "Diamond Effort"),
    BadgeOption(icon: "🎯", name: "Goal Crusher"),
    BadgeOption(icon: "🔥", name: "On Fire")
]

struct CreateBatchSheet: View {
    @Environment(\.dismiss) var dismiss
    let onCreate: (String) async -> Void
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form { TextField("Batch name (e.g. Morning Squad)", text: $name) }
                .navigationTitle("Create Batch")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Create") { Task { await onCreate(name); dismiss() } }.disabled(name.isEmpty)
                    }
                }
        }
    }
}
