//
//  InsightsView.swift
//  SwiftLap (iOS)
//

import SwiftUI

struct InsightsView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var insights: Insights?
    @State private var rank: LeaderboardEntry?
    @State private var loading = true

    var body: some View {
        List {
            if let r = rank {
                Section("Your Rank") {
                    HStack(alignment: .center) {
                        Text("#\(r.rank ?? 0)")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(Theme.teal)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("📈 \(improvementText(r.improvementPct)) improvement")
                            Text("🎯 \(r.goalPercent)% goals")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }

            if loading && insights == nil {
                ProgressView()
            } else if let i = insights {
                if i.totalSessions < 3 {
                    Section { Text("Log 3+ sessions to unlock insights").foregroundStyle(.secondary) }
                } else {
                    if let pace = i.paceTrend, let desc = pace.description {
                        Section("Pace Trend") { Text(desc) }
                    }
                    Section("Consistency") {
                        Text("\(i.consistencyScore ?? 0)%").font(.title3.bold())
                        if let d = i.consistencyDesc { Text(d).font(.caption).foregroundStyle(.secondary) }
                    }
                    if let g = i.goalInsight, let m = g.message {
                        Section("Goal") { Text(m) }
                    }
                    if let rk = i.rankingInsight, let mf = rk.mainFactor {
                        Section("Main Factor") { Text(mf) }
                    }
                }
            }
        }
        .navigationTitle("Insights & Rank")
        .task { await load() }
    }

    private func improvementText(_ pct: Double?) -> String {
        guard let pct else { return "–" }
        return (pct > 0 ? "+" : "") + String(format: "%.1f", pct) + "%"
    }

    private func load() async {
        guard let u = auth.currentUser else { return }
        loading = true
        insights = try? await APIClient.shared.fetchInsights(swimmerId: u.id)
        if let coachId = u.coachId {
            let lb = (try? await APIClient.shared.coachLeaderboard(coachId: coachId)) ?? []
            rank = lb.first { $0.id == u.id }
        }
        loading = false
    }
}
