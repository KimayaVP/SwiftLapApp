//
//  AchievementsView.swift
//  SwiftLap (iOS)
//

import SwiftUI

struct AchievementsView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var data: APIClient.AchievementsResponse?
    @State private var coachBadges: [CoachBadge] = []
    @State private var loading = true

    private let badgeColumns = [GridItem(.adaptive(minimum: 80), spacing: 12)]

    var body: some View {
        List {
            if let d = data {
                Section {
                    HStack {
                        streakStat("🔥", d.streak.currentStreak, "Day Streak")
                        Divider()
                        streakStat("⭐️", d.streak.longestStreak, "Best Streak")
                    }
                }
                if let c = d.challenge, let name = c.name {
                    Section("Weekly Challenge") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(name).font(.subheadline.weight(.semibold))
                            if let desc = c.desc { Text(desc).font(.caption).foregroundStyle(.secondary) }
                            if let p = c.progress, let t = c.target, t > 0 {
                                ProgressView(value: Double(min(p, t)), total: Double(t))
                                Text("\(p)/\(t)\(c.completed == true ? "  ✅ Complete" : "")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                Section("Badges") {
                    LazyVGrid(columns: badgeColumns, spacing: 12) {
                        ForEach(d.all) { b in
                            VStack(spacing: 4) {
                                Text(b.icon).font(.system(size: 30)).opacity(b.earned == true ? 1 : 0.3)
                                Text(b.name).font(.caption2).multilineTextAlignment(.center)
                                    .foregroundStyle(b.earned == true ? .primary : .secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            } else if loading {
                ProgressView()
            }

            if !coachBadges.isEmpty {
                Section("Coach Badges") {
                    ForEach(coachBadges) { cb in
                        HStack(spacing: 12) {
                            Text(cb.badgeIcon ?? "🏅").font(.title2)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cb.badgeName ?? "Badge").font(.subheadline.weight(.medium))
                                if let m = cb.message, !m.isEmpty {
                                    Text(m).font(.caption).foregroundStyle(.secondary)
                                }
                                if let n = cb.coach?.name {
                                    Text("From \(n)").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Achievements")
        .task { await load() }
    }

    private func streakStat(_ icon: String, _ value: Int, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(icon).font(.title2)
            Text("\(value)").font(.title.bold())
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func load() async {
        guard let id = auth.currentUser?.id else { return }
        loading = true
        data = try? await APIClient.shared.fetchAchievements(swimmerId: id)
        coachBadges = (try? await APIClient.shared.fetchCoachBadges(swimmerId: id)) ?? []
        loading = false
    }
}
