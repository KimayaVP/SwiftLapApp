//
//  APIClient.swift
//  Shared (iOS + watch)
//
//  Async wrapper around the SwiftLap REST API. Request bodies are sent as
//  camelCase (the backend reads camelCase keys, e.g. coachId/swimmerIds);
//  responses are decoded with .convertFromSnakeCase to map Supabase's
//  snake_case columns onto our camelCase model properties.
//

import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case server(String)            // backend returned { error: "..." }
    case http(Int, String)         // non-2xx with no parseable error

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Unexpected response from server"
        case .server(let msg): return msg
        case .http(let code, _): return "Request failed (HTTP \(code))"
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    private let session: URLSession = .shared
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    private let encoder: JSONEncoder = JSONEncoder()   // keep camelCase keys

    private struct ErrorBody: Decodable { let error: String? }
    private struct SuccessBody: Decodable { let success: Bool? }

    // MARK: Core

    func get<T: Decodable>(_ path: String) async throws -> T {
        try await perform(makeRequest(path, method: "GET"))
    }

    func post<T: Decodable, Body: Encodable>(_ path: String, _ body: Body) async throws -> T {
        var req = makeRequest(path, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(body)
        return try await perform(req)
    }

    @discardableResult
    func postExpectingError<Body: Encodable>(_ path: String, _ body: Body) async throws -> Bool {
        // For endpoints we call for their side effect ({ success: true }).
        let ok: SuccessBody = try await post(path, body)
        return ok.success ?? true
    }

    private func makeRequest(_ path: String, method: String) -> URLRequest {
        let url = URL(string: AppConfig.apiBaseURL.absoluteString + path)!
        var req = URLRequest(url: url)
        req.httpMethod = method
        return req
    }

    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await session.data(for: req)
        } catch {
            throw APIError.server(error.localizedDescription)
        }
        guard let http = resp as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            if let body = try? decoder.decode(ErrorBody.self, from: data), let msg = body.error {
                throw APIError.server(msg)
            }
            throw APIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.invalidResponse
        }
    }
}

// MARK: - Auth

extension APIClient {
    struct LoginBody: Encodable { let email: String; let password: String }
    struct SignupBody: Encodable { let name: String; let email: String; let password: String; let role: String }
    struct OAuthSyncBody: Encodable { let accessToken: String; let role: String? }

    func login(email: String, password: String) async throws -> AuthResponse {
        try await post("/api/auth/login", LoginBody(email: email, password: password))
    }

    func signup(name: String, email: String, password: String, role: String) async throws -> AuthResponse {
        try await post("/api/auth/signup", SignupBody(name: name, email: email, password: password, role: role))
    }

    func oauthSync(accessToken: String, role: String? = nil) async throws -> AuthResponse {
        try await post("/api/auth/oauth-sync", OAuthSyncBody(accessToken: accessToken, role: role))
    }
}

// MARK: - Swimmer data

extension APIClient {
    struct TimesResponse: Decodable { let times: [SwimTime] }
    struct GoalsResponse: Decodable { let goals: [Goal] }
    struct MeetsResponse: Decodable { let meets: [Meet] }
    struct RecommendationsResponse: Decodable { let recommendations: [MeetRecommendation] }

    func fetchTimes(swimmerId: String) async throws -> [SwimTime] {
        let r: TimesResponse = try await get("/api/times/\(swimmerId)")
        return r.times
    }

    struct LogTimeBody: Encodable {
        let swimmerId: String; let stroke: String; let distance: Int
        let minutes: Int; let seconds: Int
    }
    func logTime(swimmerId: String, stroke: String, distance: Int, minutes: Int, seconds: Int) async throws {
        try await postExpectingError("/api/times", LogTimeBody(swimmerId: swimmerId, stroke: stroke, distance: distance, minutes: minutes, seconds: seconds))
    }

    func fetchGoals(swimmerId: String) async throws -> [Goal] {
        let r: GoalsResponse = try await get("/api/goals/all/\(swimmerId)")
        return r.goals
    }

    struct SetGoalBody: Encodable {
        let swimmerId: String; let stroke: String; let distance: Int
        let targetMinutes: Int; let targetSeconds: Int
    }
    func setGoal(swimmerId: String, stroke: String, distance: Int, targetMinutes: Int, targetSeconds: Int) async throws {
        try await postExpectingError("/api/goals", SetGoalBody(swimmerId: swimmerId, stroke: stroke, distance: distance, targetMinutes: targetMinutes, targetSeconds: targetSeconds))
    }

    struct SetActiveGoalBody: Encodable { let swimmerId: String; let goalId: String }
    func setActiveGoal(swimmerId: String, goalId: String) async throws {
        try await postExpectingError("/api/goals/set-active", SetActiveGoalBody(swimmerId: swimmerId, goalId: goalId))
    }

    func fetchMeetRecommendations(swimmerId: String) async throws -> [MeetRecommendation] {
        let r: RecommendationsResponse = try await get("/api/meets/recommendations/\(swimmerId)")
        return r.recommendations
    }

    // Achievements
    struct AchievementsResponse: Decodable { let all: [Badge]; let streak: Streak; let challenge: Challenge? }
    func fetchAchievements(swimmerId: String) async throws -> AchievementsResponse {
        try await get("/api/achievements/\(swimmerId)")
    }

    struct CoachBadgesResponse: Decodable { let badges: [CoachBadge] }
    func fetchCoachBadges(swimmerId: String) async throws -> [CoachBadge] {
        let r: CoachBadgesResponse = try await get("/api/coach-badges/swimmer/\(swimmerId)")
        return r.badges
    }

    // Insights
    func fetchInsights(swimmerId: String) async throws -> Insights {
        try await get("/api/insights/\(swimmerId)")
    }

    // Settings
    struct SettingsResponse: Decodable { struct S: Decodable { let showOnLeaderboard: Bool }; let settings: S }
    func fetchLeaderboardVisibility(swimmerId: String) async throws -> Bool {
        let r: SettingsResponse = try await get("/api/settings/\(swimmerId)")
        return r.settings.showOnLeaderboard
    }
    struct VisibilityBody: Encodable { let swimmerId: String; let showOnLeaderboard: Bool }
    func setLeaderboardVisibility(swimmerId: String, show: Bool) async throws {
        try await postExpectingError("/api/settings/leaderboard-visibility", VisibilityBody(swimmerId: swimmerId, showOnLeaderboard: show))
    }

    // Coach invites the swimmer accepts
    struct IncomingResponse: Decodable { let requests: [CoachRequest] }
    func incomingRequests(userId: String) async throws -> [CoachRequest] {
        let r: IncomingResponse = try await get("/api/requests/incoming/\(userId)")
        return r.requests
    }
    struct RespondBody: Encodable { let requestId: String; let action: String }
    func respondRequest(requestId: String, action: String) async throws {
        try await postExpectingError("/api/requests/respond", RespondBody(requestId: requestId, action: action))
    }

    // Training
    struct TrainingPlanResponse: Decodable {
        let ready: Bool
        let plan: TrainingPlan?
        struct Missing: Decodable { let goals: Bool?; let times: Bool? }
        let missing: Missing?
    }
    func fetchTrainingPlan(swimmerId: String) async throws -> TrainingPlanResponse {
        try await get("/api/training-plan/\(swimmerId)")
    }
    struct RoutinesResponse: Decodable { let routines: [CoachRoutine] }
    func fetchCoachRoutines(swimmerId: String) async throws -> [CoachRoutine] {
        let r: RoutinesResponse = try await get("/api/training-routines/\(swimmerId)")
        return r.routines
    }

    // Meets
    func fetchMeets(swimmerId: String) async throws -> [Meet] {
        let r: MeetsResponse = try await get("/api/meets/\(swimmerId)")
        return r.meets
    }
    struct CreateMeetBody: Encodable { let name: String; let date: String?; let location: String?; let swimmerId: String }
    func createMeet(swimmerId: String, name: String, date: String?, location: String?) async throws {
        try await postExpectingError("/api/meets/create", CreateMeetBody(name: name, date: date, location: location, swimmerId: swimmerId))
    }
    struct RecRespondBody: Encodable { let recommendationId: String; let status: String; let swimmerId: String }
    func respondMeetRecommendation(recommendationId: String, status: String, swimmerId: String) async throws {
        try await postExpectingError("/api/meets/recommendation/respond", RecRespondBody(recommendationId: recommendationId, status: status, swimmerId: swimmerId))
    }
    struct MeetResultsResponse: Decodable { let meet: Meet?; let results: [MeetResult] }
    func fetchMeetResults(meetId: String, swimmerId: String) async throws -> [MeetResult] {
        let r: MeetResultsResponse = try await get("/api/meets/\(meetId)/results/\(swimmerId)")
        return r.results
    }
    struct AddResultBody: Encodable {
        let meetId: String; let swimmerId: String; let stroke: String; let distance: Int
        let minutes: Int; let seconds: Int; let place: Int?; let medal: String?
    }
    func addRaceResult(meetId: String, swimmerId: String, stroke: String, distance: Int, minutes: Int, seconds: Int, place: Int?, medal: String?) async throws {
        try await postExpectingError("/api/meets/add-result", AddResultBody(meetId: meetId, swimmerId: swimmerId, stroke: stroke, distance: distance, minutes: minutes, seconds: seconds, place: place, medal: medal))
    }

    // Groups (Friends)
    struct GroupsResponse: Decodable { let groups: [FriendGroup] }
    func fetchGroups(swimmerId: String) async throws -> [FriendGroup] {
        let r: GroupsResponse = try await get("/api/groups/\(swimmerId)")
        return r.groups
    }
    struct CreateGroupBody: Encodable { let name: String; let swimmerId: String }
    func createGroup(name: String, swimmerId: String) async throws {
        try await postExpectingError("/api/groups/create", CreateGroupBody(name: name, swimmerId: swimmerId))
    }
    struct JoinGroupBody: Encodable { let code: String; let swimmerId: String }
    func joinGroup(code: String, swimmerId: String) async throws {
        try await postExpectingError("/api/groups/join", JoinGroupBody(code: code, swimmerId: swimmerId))
    }
    func groupLeaderboard(groupId: String) async throws -> [LeaderboardEntry] {
        let r: LeaderboardResponse = try await get("/api/groups/\(groupId)/leaderboard")
        return r.leaderboard
    }
}

// MARK: - Coach data

extension APIClient {
    struct LeaderboardResponse: Decodable { let leaderboard: [LeaderboardEntry]; let enabled: Bool? }
    struct BatchesResponse: Decodable { let batches: [Batch] }

    func coachDashboard(coachId: String) async throws -> CoachDashboard {
        try await get("/api/coach/dashboard/\(coachId)")
    }

    func coachLeaderboard(coachId: String) async throws -> [LeaderboardEntry] {
        let r: LeaderboardResponse = try await get("/api/leaderboard/\(coachId)")
        return r.leaderboard
    }

    func batchLeaderboard(batchId: String) async throws -> [LeaderboardEntry] {
        let r: LeaderboardResponse = try await get("/api/batches/\(batchId)/leaderboard")
        return r.leaderboard
    }

    func fetchBatches(coachId: String) async throws -> [Batch] {
        let r: BatchesResponse = try await get("/api/batches/\(coachId)")
        return r.batches
    }
}

// MARK: - Watch

extension APIClient {
    func watchStatus(swimmerId: String) async throws -> WatchStatus {
        try await get("/api/watch/status/\(swimmerId)")
    }

    struct GenerateCodeBody: Encodable { let swimmerId: String }
    struct GenerateCodeResponse: Decodable { let code: String }
    func generateWatchCode(swimmerId: String) async throws -> String {
        let r: GenerateCodeResponse = try await post("/api/watch/generate-code", GenerateCodeBody(swimmerId: swimmerId))
        return r.code
    }

    struct UnlinkBody: Encodable { let swimmerId: String }
    func unlinkWatch(swimmerId: String) async throws {
        try await postExpectingError("/api/watch/unlink", UnlinkBody(swimmerId: swimmerId))
    }
}
