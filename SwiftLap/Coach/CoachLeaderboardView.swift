//
//  CoachLeaderboardView.swift
//  SwiftLap (iOS)
//

import SwiftUI

struct CoachLeaderboardView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var batches: [Batch] = []
    @State private var selectedBatch = ""   // "" = all swimmers
    @State private var entries: [LeaderboardEntry] = []
    @State private var loading = true

    var body: some View {
        List {
            Section {
                Picker("Filter by batch", selection: $selectedBatch) {
                    Text("All swimmers").tag("")
                    ForEach(batches) { Text($0.name).tag($0.id) }
                }
            }
            Section("Leaderboard") {
                if loading {
                    ProgressView()
                } else if entries.isEmpty {
                    Text("No swimmers to rank yet").foregroundStyle(.secondary)
                } else {
                    ForEach(entries) { e in
                        HStack(spacing: 12) {
                            Text("#\(e.rank ?? 0)")
                                .font(.headline).foregroundStyle(rankColor(e.rank))
                                .frame(width: 38, alignment: .leading)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.name).font(.subheadline.weight(.medium))
                                HStack(spacing: 8) {
                                    Text("📈 \(improvement(e.improvementPct))")
                                    Text("🎯 \(e.goalPercent)%")
                                }
                                .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(e.compositeScore.map { String(format: "%.0f", $0) } ?? "-")
                                .font(.headline.weight(.bold))
                        }
                    }
                }
            }
        }
        .navigationTitle("Leaderboard")
        .task {
            await loadBatches()
            await loadBoard()
        }
        .onChange(of: selectedBatch) { _, _ in Task { await loadBoard() } }
    }

    private func rankColor(_ rank: Int?) -> Color {
        switch rank { case 1: return .yellow; case 2, 3: return .cyan; default: return .secondary }
    }

    private func improvement(_ pct: Double?) -> String {
        guard let pct else { return "–" }
        return (pct > 0 ? "+" : "") + String(format: "%.0f", pct) + "%"
    }

    private func loadBatches() async {
        guard let id = auth.currentUser?.id else { return }
        batches = (try? await APIClient.shared.fetchBatches(coachId: id)) ?? []
    }

    private func loadBoard() async {
        guard let id = auth.currentUser?.id else { return }
        loading = true
        if selectedBatch.isEmpty {
            entries = (try? await APIClient.shared.coachLeaderboard(coachId: id)) ?? []
        } else {
            entries = (try? await APIClient.shared.batchLeaderboard(batchId: selectedBatch)) ?? []
        }
        loading = false
    }
}
