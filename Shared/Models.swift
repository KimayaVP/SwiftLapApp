//
//  Models.swift
//  Shared (iOS + watch)
//
//  Codable types mirroring the SwiftLap backend JSON. The API client decodes
//  with `.convertFromSnakeCase`, so snake_case columns (coach_id, time_seconds)
//  map to camelCase properties here, while already-camelCase computed fields
//  (improvementPct, isActive) map as-is.
//

import Foundation

// MARK: - Auth / Profile

struct Profile: Codable, Identifiable, Hashable {
    let id: String
    let email: String?
    let name: String
    let role: String          // "swimmer" | "coach"
    let coachId: String?
    let watchLinkedAt: String?
    let showOnLeaderboard: Bool?

    var isCoach: Bool { role == "coach" }
}

/// Supabase session returned by login/signup. We only need the access token.
struct Session: Codable {
    let accessToken: String
}

/// Unified shape for /auth/login, /auth/signup and /auth/oauth-sync.
struct AuthResponse: Codable {
    let success: Bool?
    let user: Profile?
    let session: Session?
    // oauth-sync first pass when a new OAuth user needs to choose a role:
    let needsRole: Bool?
    let name: String?
    let email: String?
    let error: String?
}

// MARK: - Times

struct SwimTime: Codable, Identifiable {
    let id: String
    let swimmerId: String?
    let stroke: String
    let distance: Int
    let timeSeconds: Double
    let date: String
    let source: String?
}

// MARK: - Goals

struct Goal: Codable, Identifiable {
    let id: String
    let swimmerId: String?
    let stroke: String
    let distance: Int
    let targetSeconds: Double
    let month: String?
    let source: String?       // "coach" when assigned by a coach
    // computed by /goals/all:
    let isActive: Bool?
    let achieved: Bool?
    let bestTime: Double?
    let gap: Double?
}

// MARK: - Meets

struct Meet: Codable, Identifiable {
    let id: String
    let name: String
    let date: String?
    let location: String?
    let resultCount: Int?
}

struct MeetRecommendation: Codable, Identifiable {
    let id: String
    let coachId: String?
    let swimmerId: String?
    let meetName: String
    let meetDate: String?
    let location: String?
    let stroke: String?
    let distance: Int?
    let note: String?
    let status: String?
    let coachName: String?
}

// MARK: - Batches & Leaderboard

struct Batch: Codable, Identifiable {
    let id: String
    let name: String
    let memberCount: Int?
}

/// Works for both the coach-wide leaderboard and a batch leaderboard
/// (fields differ slightly between the two endpoints, hence optionals).
struct LeaderboardEntry: Codable, Identifiable {
    let id: String
    let name: String
    let rank: Int?
    let improvementPct: Double?
    let consistencyScore: Int?
    let goalCompletionRate: Int?   // coach-wide leaderboard
    let goalRate: Int?             // batch leaderboard
    let streak: Int?
    let compositeScore: Double?
    let deltaFromTop: Double?

    var goalPercent: Int { goalCompletionRate ?? goalRate ?? 0 }
}

// MARK: - Coach dashboard

struct CoachSummary: Codable {
    let total: Int
    let ahead: Int
    let behind: Int
    let noGoals: Int
}

struct CoachSwimmer: Codable, Identifiable {
    let id: String
    let name: String
    let status: String             // "ahead" | "behind" | "no_goals"
    let goalsCount: Int?
    let goalsAhead: Int?
    let sessionsThisMonth: Int?
    let streak: Int?
}

struct CoachDashboard: Codable {
    let swimmers: [CoachSwimmer]
    let summary: CoachSummary
}

// MARK: - Watch

struct WatchStatus: Codable {
    let linked: Bool
    let linkedAt: String?
    let workoutCount: Int
}

// MARK: - Achievements

struct Streak: Codable {
    let currentStreak: Int
    let longestStreak: Int
}

struct Challenge: Codable {
    let name: String?
    let desc: String?
    let progress: Int?
    let target: Int?
    let completed: Bool?
}

struct Badge: Codable, Identifiable {
    let id: String
    let name: String
    let icon: String
    let desc: String?
    let earned: Bool?
}

struct CoachBadge: Codable, Identifiable {
    let id: String
    let badgeName: String?
    let badgeIcon: String?
    let message: String?
    let coach: NamedRef?
}

struct NamedRef: Codable { let name: String? }

// MARK: - Insights

struct PaceTrend: Codable { let direction: String?; let description: String? }
struct GoalInsight: Codable { let status: String?; let message: String? }
struct RankingInsight: Codable { let mainFactor: String? }

struct Insights: Codable {
    let totalSessions: Int
    let paceTrend: PaceTrend?
    let consistencyScore: Int?
    let consistencyDesc: String?
    let goalInsight: GoalInsight?
    let rankingInsight: RankingInsight?
}

// MARK: - Requests (coach invites the swimmer accepts)

struct RequestParty: Codable {
    let id: String
    let name: String
    let email: String?
    let role: String?
}

struct CoachRequest: Codable, Identifiable {
    let id: String
    let type: String
    let from: RequestParty?
}

// MARK: - Training

struct PlanMainSet: Codable, Identifiable {
    var id = UUID()
    let set: String
    let rest: String?
    let focus: String?
    enum CodingKeys: String, CodingKey { case set, rest, focus }
}

struct WorkoutDay: Codable, Identifiable {
    var id = UUID()
    let day: String
    let type: String?
    let totalDistance: String?
    let warmup: String?
    let main: [PlanMainSet]?
    let cooldown: String?
    enum CodingKeys: String, CodingKey { case day, type, totalDistance, warmup, main, cooldown }
}

struct TrainingPlan: Codable {
    let weekFocus: String?
    let intensity: String?
    let focusAreas: [String]?
    let workouts: [WorkoutDay]?
    let sessionsPerWeek: Int?
    let totalWeeklyDistance: String?
    let tips: [String]?
}

struct CoachRoutine: Codable, Identifiable {
    let id: String
    let title: String
    let details: String?
    let coachName: String?
}

// MARK: - Meet results & groups

struct MeetResult: Codable, Identifiable {
    let id: String
    let stroke: String
    let distance: Int
    let timeSeconds: Double
    let place: Int?
    let medal: String?
    let isPb: Bool?
}

struct FriendGroup: Codable, Identifiable {
    let id: String
    let name: String
    let code: String?
    let isOwner: Bool?
}
