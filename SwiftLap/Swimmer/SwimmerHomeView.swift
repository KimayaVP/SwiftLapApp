//
//  SwimmerHomeView.swift
//  SwiftLap (iOS)
//
//  Swimmer landing screen: greeting, no-coach banner, and a native tile grid
//  that navigates to each feature. (Coach linking is invite-only — swimmers
//  cannot request a coach; they accept invites instead.)
//

import SwiftUI

struct SwimmerHomeView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var invites: [CoachRequest] = []
    @State private var pendingRecs = 0

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BrandMark(role: "swimmer")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(invites) { invite in
                        inviteCard(invite)
                    }
                    if auth.currentUser?.coachId == nil && invites.isEmpty {
                        noCoachBanner
                    }
                    LazyVGrid(columns: columns, spacing: 14) {
                        NavigationLink { RecentsView() } label: { Tile(icon: "chart.bar.fill", title: "Recents") }
                        NavigationLink { GoalsView() } label: { Tile(icon: "target", title: "Goals") }
                        NavigationLink { TrainingView() } label: { Tile(icon: "calendar", title: "Training") }
                        NavigationLink { MeetsView() } label: { Tile(icon: "flag.checkered", title: "Meets & Races", badge: pendingRecs) }
                        NavigationLink { InsightsView() } label: { Tile(icon: "chart.line.uptrend.xyaxis", title: "Insights & Rank") }
                        NavigationLink { AchievementsView() } label: { Tile(icon: "medal.fill", title: "Achievements") }
                        NavigationLink { VideoView() } label: { Tile(icon: "video.fill", title: "Video & Feedback") }
                        NavigationLink { FriendsView() } label: { Tile(icon: "person.2.fill", title: "Friends") }
                    }
                    .buttonStyle(.plain)   // suppress iOS 26 Liquid-Glass halo on the tiles
                }
                .padding()
            }
            .navigationTitle("Hi, \(firstName)")
            .task { await loadInvites() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { NotificationsBell() }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { ContactFeedbackView() } label: { Image(systemName: "envelope") }
                        .accessibilityLabel("Contact & Feedback")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView() } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
        }
    }

    private var firstName: String {
        (auth.currentUser?.name ?? "").split(separator: " ").first.map(String.init) ?? "there"
    }

    private var noCoachBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("🏊 Training Solo").font(.headline)
            Text("You're not linked to a coach yet. Ask your coach to send you an invite from their SwiftLap account.")
                .font(.subheadline).foregroundStyle(.secondary)
            Text("Coach not on SwiftLap yet? Ask them to sign up — then they can invite you.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.orange.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.orange.opacity(0.3)))
    }

    private func inviteCard(_ invite: CoachRequest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("👨‍🏫 Coach invite").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text("\(invite.from?.name ?? "A coach") invited you to join their team")
                .font(.subheadline)
            HStack {
                Button("Accept") { Task { await respond(invite, "accept") } }
                    .buttonStyle(.borderedProminent)
                Button("Decline") { Task { await respond(invite, "reject") } }
                    .buttonStyle(.bordered).tint(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.teal.opacity(0.12)))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.teal.opacity(0.3)))
    }

    private func loadInvites() async {
        guard let id = auth.currentUser?.id else { return }
        let all = (try? await APIClient.shared.incomingRequests(userId: id)) ?? []
        invites = all.filter { $0.type == "coach_to_swimmer" }
        let recs = (try? await APIClient.shared.fetchMeetRecommendations(swimmerId: id)) ?? []
        pendingRecs = recs.filter { ($0.status ?? "pending") == "pending" }.count
    }

    private func respond(_ invite: CoachRequest, _ action: String) async {
        try? await APIClient.shared.respondRequest(requestId: invite.id, action: action)
        if action == "accept", let coachId = invite.from?.id {
            auth.markLinkedToCoach(coachId)
        }
        invites.removeAll { $0.id == invite.id }
    }
}

struct Tile: View {
    let icon: String
    let title: String
    var badge: Int = 0

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.softGradient)
                    .frame(width: 54, height: 54)
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Theme.teal)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.navy)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 124)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.teal.opacity(0.12), lineWidth: 1)
        )
        .overlay(alignment: .topTrailing) {
            if badge > 0 {
                Text(badge > 9 ? "9+" : "\(badge)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(Theme.coral))
                    .offset(x: -8, y: 8)
            }
        }
        .shadow(color: Theme.navy.opacity(0.06), radius: 8, x: 0, y: 3)
    }
}
