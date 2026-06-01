//
//  CoachBatchesView.swift
//  SwiftLap (iOS)
//
//  Swimmers grouped by batch (+ an Individuals group), create batches,
//  invite swimmers, manage batch membership, and per-swimmer coach actions.
//

import SwiftUI
import AVKit

struct CoachBatchesView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var swimmers: [CoachSwimmer] = []
    @State private var batches: [(batch: Batch, memberIds: [String])] = []
    @State private var loading = true
    @State private var showCreate = false
    @State private var showInvite = false
    @State private var createError: String?

    var body: some View {
        List {
            ForEach(batches, id: \.batch.id) { entry in
                Section {
                    let members = swimmers.filter { entry.memberIds.contains($0.id) }
                    if members.isEmpty {
                        Text("No swimmers in this batch yet").foregroundStyle(.secondary)
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
                    Text(loading ? "Loading…" : "No individual swimmers").foregroundStyle(.secondary)
                } else {
                    ForEach(indiv) { swimmerLink($0) }
                }
            }
        }
        .navigationTitle("Batches & Swimmers")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showCreate = true } label: { Label("New Batch", systemImage: "folder.badge.plus") }
                    Button { showInvite = true } label: { Label("Add Swimmer", systemImage: "person.badge.plus") }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateBatchSheet { name in await createBatch(name) }
        }
        .sheet(isPresented: $showInvite, onDismiss: { Task { await load() } }) {
            CoachInviteView().environmentObject(auth)
        }
        .alert("Couldn't create batch", isPresented: Binding(get: { createError != nil }, set: { if !$0 { createError = nil } })) {
            Button("OK", role: .cancel) { createError = nil }
        } message: {
            Text(createError ?? "")
        }
        .refreshable { await load() }
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

    /// Returns an error message on failure (e.g. duplicate name), nil on success.
    private func createBatch(_ name: String) async -> String? {
        guard let id = auth.currentUser?.id, !name.isEmpty else { return "Enter a batch name" }
        do {
            try await APIClient.shared.createBatch(name: name, coachId: id)
            await load()
            return nil
        } catch {
            let msg = (error as? APIError)?.errorDescription ?? error.localizedDescription
            createError = msg
            return msg
        }
    }
}

// MARK: - Per-swimmer page (assign, reactions, comments, awards, videos)

struct CoachSwimmerView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    let swimmer: CoachSwimmer

    @State private var comment = ""
    @State private var badgeMessage = ""
    @State private var selectedBadgeId: UUID?
    @State private var status: String?
    @State private var videos: [VideoFeedback] = []
    @State private var videoNotes: [String: String] = [:]
    @State private var showRemoveConfirm = false
    @State private var assignedGoals: [Goal] = []
    @State private var assignedRoutines: [CoachRoutine] = []
    @State private var reactionToast: String?

    private let columns = [GridItem(.adaptive(minimum: 90), spacing: 10)]

    var body: some View {
        List {
            // Assign + what's already assigned to this swimmer.
            Section("Goals & Routines") {
                NavigationLink {
                    CoachAssignView(preselect: swimmer).environmentObject(auth)
                } label: {
                    Label("Assign a goal or routine", systemImage: "target")
                }
                if assignedGoals.isEmpty && assignedRoutines.isEmpty {
                    Text("Nothing assigned yet.").font(.caption).foregroundStyle(.secondary)
                }
                ForEach(assignedGoals) { g in
                    HStack {
                        Text("🎯 \(g.stroke) \(g.distance)m").font(.subheadline)
                        Spacer()
                        Text("\(formatLapTime(g.targetSeconds))").font(.caption).foregroundStyle(.secondary)
                        Text((g.achieved == true) ? "✅" : statusEmoji(g.status))
                    }
                }
                ForEach(assignedRoutines) { r in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("📋 \(r.title)").font(.subheadline)
                        if let d = r.details, !d.isEmpty { Text(d).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }

            if !videos.isEmpty {
                Section("Videos") {
                    ForEach(videos) { v in videoReviewRow(v) }
                }
            }

            Section {
                HStack(spacing: 18) {
                    ForEach(["🔥", "💪", "👏", "⭐️"], id: \.self) { r in
                        Button { Task { await react(r) } } label: {
                            Text(r).font(.title2)
                                .frame(width: 46, height: 46)
                                .background(Circle().fill(Color(.secondarySystemBackground)))
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            } header: {
                Text("Quick Reaction")
            } footer: {
                Text("Tap to instantly send \(swimmer.name) a reaction — they'll see it on their feed.")
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
                                .fill(selectedBadgeId == b.id ? Theme.teal.opacity(0.2) : Color(.secondarySystemBackground)))
                        }
                        .buttonStyle(.plain)
                    }
                }
                TextField("Message (optional)", text: $badgeMessage)
                Button("Award Badge") { Task { await award() } }.disabled(selectedBadgeId == nil)
            }
            if let status { Text(status).font(.caption).foregroundStyle(.green) }

            Section {
                Button("Remove from My Squad", role: .destructive) { showRemoveConfirm = true }
            } footer: {
                Text("Unattaches this swimmer from you. You'll no longer see their data; you can re-invite them later.")
            }
        }
        .navigationTitle(swimmer.name)
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if let reactionToast {
                Text(reactionToast)
                    .font(.subheadline.weight(.medium)).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Theme.gradient, in: Capsule())
                    .shadow(color: Theme.navy.opacity(0.2), radius: 8, y: 3)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task { await loadVideos(); await loadAssigned() }
        .alert("Remove \(swimmer.name)?", isPresented: $showRemoveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Remove", role: .destructive) { Task { await removeFromSquad() } }
        } message: {
            Text("They'll become unassigned and you'll no longer see their data. You can re-invite them later.")
        }
    }

    private func statusEmoji(_ status: String?) -> String {
        switch status { case "ahead": return "✅"; case "behind": return "🔻"; default: return "—" }
    }

    private func removeFromSquad() async {
        try? await APIClient.shared.unlinkSwimmer(swimmerId: swimmer.id)
        dismiss()
    }

    @ViewBuilder
    private func videoReviewRow(_ v: VideoFeedback) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(v.stroke)\(v.feedback.overallScore.map { " · AI \($0)/10" } ?? "")")
                .font(.subheadline.weight(.medium))
            if let urlStr = v.videoUrl, let url = URL(string: urlStr) {
                VideoPlayer(player: AVPlayer(url: url))
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                Text("Video no longer available (auto-deleted after 14 days).")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if let existing = v.coachFeedback, !existing.isEmpty {
                Text("Your feedback: \(existing)").font(.caption).foregroundStyle(.green)
            }
            TextField("Leave feedback on this clip", text: Binding(
                get: { videoNotes[v.id] ?? "" },
                set: { videoNotes[v.id] = $0 }
            ), axis: .vertical)
            Button("Send Feedback") { Task { await sendVideoFeedback(v) } }
                .disabled((videoNotes[v.id] ?? "").isEmpty)
        }
        .padding(.vertical, 4)
    }

    private func loadVideos() async {
        videos = (try? await APIClient.shared.fetchVideoFeedback(swimmerId: swimmer.id)) ?? []
    }

    private func loadAssigned() async {
        let goals = (try? await APIClient.shared.fetchGoals(swimmerId: swimmer.id)) ?? []
        assignedGoals = goals.filter { $0.source == "coach" }
        assignedRoutines = (try? await APIClient.shared.fetchCoachRoutines(swimmerId: swimmer.id)) ?? []
    }

    private func sendVideoFeedback(_ v: VideoFeedback) async {
        guard let coachId = auth.currentUser?.id, let note = videoNotes[v.id], !note.isEmpty else { return }
        try? await APIClient.shared.coachVideoFeedback(videoId: v.id, coachId: coachId, feedback: note)
        videoNotes[v.id] = ""
        status = "Video feedback sent"
        await loadVideos()
    }

    private func react(_ emoji: String) async {
        guard let id = auth.currentUser?.id else { return }
        try? await APIClient.shared.addCoachComment(coachId: id, swimmerId: swimmer.id, comment: nil, reaction: emoji)
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { reactionToast = "Sent \(emoji)" }
        Task {
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            withAnimation(.easeOut(duration: 0.3)) { reactionToast = nil }
        }
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
    @State private var allBatches: [Batch] = []
    @State private var loading = true

    var body: some View {
        List {
            Section("Members") {
                if members.isEmpty {
                    Text(loading ? "Loading…" : "No swimmers in this batch yet").foregroundStyle(.secondary)
                } else {
                    ForEach(members) { m in
                        HStack {
                            Text(m.name)
                            Spacer()
                            let targets = allBatches.filter { $0.id != batch.id }
                            if !targets.isEmpty {
                                Menu("Move") {
                                    ForEach(targets) { t in
                                        Button(t.name) { Task { await move(m.id, to: t.id) } }
                                    }
                                }.font(.caption)
                            }
                            Button("Remove", role: .destructive) { Task { await remove(m.id) } }.font(.caption)
                        }
                    }
                }
            }
            Section("Add Swimmer") {
                if available.isEmpty {
                    Text(loading ? "Loading…" : "Everyone on your squad is already in this batch. Invite more from Batches & Swimmers ➕.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(available) { s in
                        Button { Task { await add(s.id) } } label: { Label(s.name, systemImage: "plus.circle") }
                    }
                }
            }
            Section("Batch Leaderboard") {
                if members.isEmpty {
                    Text("No swimmers in this batch yet").foregroundStyle(.secondary)
                } else {
                    ForEach(members) { m in
                        HStack {
                            Text("#\(m.rank ?? 0)").foregroundStyle(Theme.teal).frame(width: 36, alignment: .leading)
                            Text(m.name)
                            Spacer()
                            Text(m.compositeScore.map { String(format: "%.0f", $0) } ?? "-").font(.subheadline.weight(.semibold))
                        }
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
        allBatches = (try? await APIClient.shared.fetchBatches(coachId: id)) ?? []
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

    private func move(_ swimmerId: String, to toBatchId: String) async {
        try? await APIClient.shared.moveSwimmer(swimmerId: swimmerId, fromBatchId: batch.id, toBatchId: toBatchId)
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
    /// Returns an error message to display, or nil on success (then dismisses).
    let onCreate: (String) async -> String?
    @State private var name = ""
    @State private var saving = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Batch name (e.g. Morning Squad)", text: $name)
                } footer: {
                    if let error { Text(error).foregroundStyle(Theme.coral) }
                }
            }
            .navigationTitle("Create Batch")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            saving = true; error = nil
                            let result = await onCreate(name.trimmingCharacters(in: .whitespaces))
                            saving = false
                            if let result { error = result } else { dismiss() }
                        }
                    } label: {
                        if saving { ProgressView() } else { Text("Create") }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                }
            }
        }
    }
}
