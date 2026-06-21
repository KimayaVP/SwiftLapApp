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

    /// Supplies a current Supabase access token, attached as a Bearer header to
    /// every request. Set by AuthManager on the iOS app; left nil on the watch
    /// (which has no user session and only calls the public watch endpoints).
    var tokenProvider: (() async -> String?)?

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
        try await perform(await authorized(makeRequest(path, method: "GET")))
    }

    func post<T: Decodable, Body: Encodable>(_ path: String, _ body: Body) async throws -> T {
        var req = makeRequest(path, method: "POST")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(body)
        return try await perform(await authorized(req))
    }

    // Endpoints that need no token. Critically, /api/config must be excluded:
    // the token provider itself fetches config to build the Supabase client, so
    // attaching a token here would recurse (token -> config -> token -> ...).
    private static let publicPaths: Set<String> = [
        "/api/config", "/api/auth/login", "/api/auth/signup", "/api/auth/oauth-sync",
    ]

    // Adds the Bearer auth header when a token provider is configured.
    private func authorized(_ req: URLRequest) async -> URLRequest {
        if let path = req.url?.path, Self.publicPaths.contains(path) { return req }
        guard let token = await tokenProvider?() else { return req }
        var r = req
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return r
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

    struct DeleteAccountBody: Encodable { let userId: String }
    func deleteAccount(userId: String) async throws {
        try await postExpectingError("/api/auth/delete-account", DeleteAccountBody(userId: userId))
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

    /// Delete a logged time (accidental-tap recovery). Scoped to the caller server-side.
    func deleteTime(id: String) async throws {
        let req = await authorized(makeRequest("/api/times/\(id)", method: "DELETE"))
        let _: SuccessBody = try await perform(req)
    }

    /// Delete a goal (accidental-tap recovery). Scoped to the caller server-side.
    func deleteGoal(id: String) async throws {
        let req = await authorized(makeRequest("/api/goals/\(id)", method: "DELETE"))
        let _: SuccessBody = try await perform(req)
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
    // One event of a meet. For an upcoming meet set expectedMinutes/Seconds; for a
    // past meet set minutes/seconds. Nil optionals are omitted from the JSON.
    struct MeetEventInput: Encodable {
        let stroke: String
        let distance: Int
        var expectedMinutes: Int?
        var expectedSeconds: Int?
        var minutes: Int?
        var seconds: Int?
    }
    struct CreateMeetBody: Encodable { let name: String; let date: String?; let location: String?; let events: [MeetEventInput]; let swimmerId: String }
    struct CreateMeetResponse: Decodable { let meet: Meet? }
    @discardableResult
    func createMeet(swimmerId: String, name: String, date: String?, location: String?, events: [MeetEventInput]) async throws -> Meet? {
        let r: CreateMeetResponse = try await post("/api/meets/create", CreateMeetBody(name: name, date: date, location: location, events: events, swimmerId: swimmerId))
        return r.meet
    }
    struct LogResultBody: Encodable { let resultId: String; let minutes: Int; let seconds: Int; let place: Int?; let medal: String?; let swimmerId: String }
    func logMeetResult(resultId: String, minutes: Int, seconds: Int, place: Int?, medal: String?, swimmerId: String) async throws {
        try await postExpectingError("/api/meets/log-result", LogResultBody(resultId: resultId, minutes: minutes, seconds: seconds, place: place, medal: medal, swimmerId: swimmerId))
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
    struct CreateGroupResponse: Decodable { let group: FriendGroup? }
    /// Returns the new group's invite code so the UI can show it right away.
    @discardableResult
    func createGroup(name: String, swimmerId: String) async throws -> String? {
        let r: CreateGroupResponse = try await post("/api/groups/create", CreateGroupBody(name: name, swimmerId: swimmerId))
        return r.group?.inviteCode
    }
    struct JoinGroupBody: Encodable { let code: String; let swimmerId: String }
    func joinGroup(code: String, swimmerId: String) async throws {
        try await postExpectingError("/api/groups/join", JoinGroupBody(code: code, swimmerId: swimmerId))
    }
    func groupLeaderboard(groupId: String) async throws -> [LeaderboardEntry] {
        let r: LeaderboardResponse = try await get("/api/groups/\(groupId)/leaderboard")
        return r.leaderboard
    }

    // Notifications (in-app inbox)
    struct NotificationsResponse: Decodable { let notifications: [AppNotification]; let unread: Int }
    func fetchNotifications(userId: String) async throws -> NotificationsResponse {
        try await get("/api/notifications/\(userId)")
    }
    struct MarkReadBody: Encodable { let id: String? }
    func markNotificationsRead(id: String? = nil) async throws {
        try await postExpectingError("/api/notifications/read", MarkReadBody(id: id))
    }
    struct DeviceTokenBody: Encodable { let token: String; let platform: String }
    func registerDevice(token: String) async throws {
        try await postExpectingError("/api/notifications/register-device", DeviceTokenBody(token: token, platform: "ios"))
    }
    struct UnregisterDeviceBody: Encodable { let token: String }
    func unregisterDevice(token: String) async throws {
        try await postExpectingError("/api/notifications/unregister-device", UnregisterDeviceBody(token: token))
    }

    // Video & feedback
    struct FeedbackResponse: Decodable { let feedbacks: [VideoFeedback] }
    func fetchVideoFeedback(swimmerId: String) async throws -> [VideoFeedback] {
        let r: FeedbackResponse = try await get("/api/video/feedback/\(swimmerId)")
        return r.feedbacks
    }
    struct CommentsResponse: Decodable { let comments: [CoachComment] }
    func fetchCoachComments(swimmerId: String) async throws -> [CoachComment] {
        let r: CommentsResponse = try await get("/api/comments/swimmer/\(swimmerId)")
        return r.comments
    }

    struct CoachVideoFeedbackBody: Encodable { let videoId: String; let coachId: String; let feedback: String }
    func coachVideoFeedback(videoId: String, coachId: String, feedback: String) async throws {
        try await postExpectingError("/api/video/coach-feedback", CoachVideoFeedbackBody(videoId: videoId, coachId: coachId, feedback: feedback))
    }
}

// MARK: - Multipart video upload

extension APIClient {
    func uploadVideo(swimmerId: String, stroke: String, videoData: Data, filename: String, mimeType: String) async throws {
        let boundary = "Boundary-\(UUID().uuidString)"
        let url = URL(string: AppConfig.apiBaseURL.absoluteString + "/api/video/upload")!
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        appendField("swimmerId", swimmerId)
        appendField("stroke", stroke)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"video\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(videoData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        req = await authorized(req)
        let (data, resp) = try await session.upload(for: req, from: body)
        guard let http = resp as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            if let e = try? decoder.decode(ErrorBody.self, from: data), let m = e.error {
                throw APIError.server(m)
            }
            throw APIError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
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

    // Coach: swimmers, batches management, comments, badges, invites
    struct SwimmersResponse: Decodable { let swimmers: [SwimmerRef] }
    func fetchCoachSwimmers(coachId: String) async throws -> [SwimmerRef] {
        let r: SwimmersResponse = try await get("/api/coach/swimmers/\(coachId)")
        return r.swimmers
    }

    struct CreateBatchBody: Encodable { let name: String; let coachId: String }
    func createBatch(name: String, coachId: String) async throws {
        try await postExpectingError("/api/batches/create", CreateBatchBody(name: name, coachId: coachId))
    }

    // Coach review queue: clips from this coach's swimmers awaiting feedback.
    struct PendingResponse: Decodable { let pending: [PendingVideo] }
    func pendingReviewVideos(coachId: String) async throws -> [PendingVideo] {
        let r: PendingResponse = try await get("/api/video/pending/\(coachId)")
        return r.pending
    }

    // Move a swimmer between batches in one step (fromBatchId nil = just add).
    struct MoveSwimmerBody: Encodable { let swimmerId: String; let fromBatchId: String?; let toBatchId: String }
    func moveSwimmer(swimmerId: String, fromBatchId: String?, toBatchId: String) async throws {
        try await postExpectingError("/api/batches/move", MoveSwimmerBody(swimmerId: swimmerId, fromBatchId: fromBatchId, toBatchId: toBatchId))
    }

    // Remove a swimmer from the coach's roster entirely (unattach).
    struct UnlinkSwimmerBody: Encodable { let swimmerId: String }
    func unlinkSwimmer(swimmerId: String) async throws {
        try await postExpectingError("/api/requests/unlink", UnlinkSwimmerBody(swimmerId: swimmerId))
    }
    struct AvailableResponse: Decodable { let available: [SwimmerRef] }
    func batchAvailableSwimmers(batchId: String, coachId: String) async throws -> [SwimmerRef] {
        let r: AvailableResponse = try await get("/api/batches/\(batchId)/available/\(coachId)")
        return r.available
    }
    struct BatchSwimmerBody: Encodable { let batchId: String; let swimmerId: String }
    func addSwimmerToBatch(batchId: String, swimmerId: String) async throws {
        try await postExpectingError("/api/batches/add-swimmer", BatchSwimmerBody(batchId: batchId, swimmerId: swimmerId))
    }
    func removeSwimmerFromBatch(batchId: String, swimmerId: String) async throws {
        try await postExpectingError("/api/batches/remove-swimmer", BatchSwimmerBody(batchId: batchId, swimmerId: swimmerId))
    }

    struct CommentBody: Encodable { let coachId: String; let swimmerId: String; let comment: String?; let reaction: String? }
    func addCoachComment(coachId: String, swimmerId: String, comment: String?, reaction: String?) async throws {
        try await postExpectingError("/api/comments/add", CommentBody(coachId: coachId, swimmerId: swimmerId, comment: comment, reaction: reaction))
    }

    struct AwardBadgeBody: Encodable { let coachId: String; let swimmerId: String; let badgeName: String; let badgeIcon: String; let message: String? }
    func awardBadge(coachId: String, swimmerId: String, badgeName: String, badgeIcon: String, message: String?) async throws {
        try await postExpectingError("/api/coach-badges/award", AwardBadgeBody(coachId: coachId, swimmerId: swimmerId, badgeName: badgeName, badgeIcon: badgeIcon, message: message))
    }

    struct RecommendBody: Encodable { let coachId: String; let swimmerIds: [String]; let meetName: String; let meetDate: String?; let note: String? }
    func recommendMeet(coachId: String, swimmerIds: [String], meetName: String, meetDate: String?, note: String?) async throws {
        try await postExpectingError("/api/meets/recommend", RecommendBody(coachId: coachId, swimmerIds: swimmerIds, meetName: meetName, meetDate: meetDate, note: note))
    }

    struct AssignGoalBody: Encodable { let coachId: String; let swimmerId: String; let stroke: String; let distance: Int; let targetMinutes: Int; let targetSeconds: Int }
    func assignGoal(coachId: String, swimmerId: String, stroke: String, distance: Int, targetMinutes: Int, targetSeconds: Int) async throws {
        try await postExpectingError("/api/goals/assign", AssignGoalBody(coachId: coachId, swimmerId: swimmerId, stroke: stroke, distance: distance, targetMinutes: targetMinutes, targetSeconds: targetSeconds))
    }
    struct AssignRoutineBody: Encodable { let coachId: String; let swimmerId: String; let title: String; let details: String? }
    func assignRoutine(coachId: String, swimmerId: String, title: String, details: String?) async throws {
        try await postExpectingError("/api/training-routines/assign", AssignRoutineBody(coachId: coachId, swimmerId: swimmerId, title: title, details: details))
    }

    // Coach-facing lists of what they've assigned.
    func assignedGoals(coachId: String) async throws -> [Goal] {
        let r: GoalsResponse = try await get("/api/goals/assigned/\(coachId)")
        return r.goals
    }
    func assignedRoutines(coachId: String) async throws -> [CoachRoutine] {
        let r: RoutinesResponse = try await get("/api/training-routines/assigned/\(coachId)")
        return r.routines
    }

    // Coach-facing list + edit/withdraw of meet recommendations they've sent.
    func sentRecommendations(coachId: String) async throws -> [MeetRecommendation] {
        let r: RecommendationsResponse = try await get("/api/meets/recommendations/coach/\(coachId)")
        return r.recommendations
    }
    struct UpdateRecBody: Encodable { let recommendationId: String; let meetName: String; let meetDate: String?; let note: String? }
    func updateRecommendation(recommendationId: String, meetName: String, meetDate: String?, note: String?) async throws {
        try await postExpectingError("/api/meets/recommendation/update", UpdateRecBody(recommendationId: recommendationId, meetName: meetName, meetDate: meetDate, note: note))
    }
    func deleteRecommendation(recommendationId: String) async throws {
        let req = await authorized(makeRequest("/api/meets/recommendation/\(recommendationId)", method: "DELETE"))
        let _: SuccessBody = try await perform(req)
    }

    struct InviteBody: Encodable { let coachId: String; let swimmerEmail: String }
    struct InviteResponse: Decodable { let success: Bool?; let emailed: Bool?; let message: String?; let swimmer: SwimmerRef?; let error: String? }
    func inviteSwimmer(coachId: String, email: String) async throws -> InviteResponse {
        try await post("/api/requests/invite", InviteBody(coachId: coachId, swimmerEmail: email))
    }
    struct OutgoingResponse: Decodable { let requests: [OutgoingInvite] }
    func outgoingInvites(coachId: String) async throws -> [OutgoingInvite] {
        let r: OutgoingResponse = try await get("/api/requests/outgoing/\(coachId)")
        return r.requests
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

    // Watch app: link via 4-digit code, and send a workout
    struct VerifyCodeBody: Encodable { let code: String }
    struct VerifyCodeResponse: Decodable { let swimmerId: String?; let watchToken: String?; let error: String? }
    /// Returns the linked swimmer id and a device token to authenticate future syncs.
    func verifyWatchCode(_ code: String) async throws -> (swimmerId: String, watchToken: String?) {
        let r: VerifyCodeResponse = try await post("/api/watch/verify-code", VerifyCodeBody(code: code))
        guard let id = r.swimmerId else { throw APIError.server(r.error ?? "Invalid code") }
        return (id, r.watchToken)
    }

    struct WatchWorkoutBody: Encodable {
        let swimmerId: String; let duration: Int; let distance: Double; let laps: Int
        let strokeCount: Int; let avgHeartRate: Double; let calories: Double
        let lapTimes: [Double]; let lapStrokes: [Int]; let fatigueLevel: String
        let poolLength: Double; let date: String; let source: String
        let watchToken: String?
    }
    func sendWatchWorkout(swimmerId: String, duration: Int, distance: Double, laps: Int, strokeCount: Int, avgHeartRate: Double, calories: Double, lapTimes: [Double], lapStrokes: [Int], fatigueLevel: String, poolLength: Double, watchToken: String?) async throws {
        let body = WatchWorkoutBody(swimmerId: swimmerId, duration: duration, distance: distance, laps: laps, strokeCount: strokeCount, avgHeartRate: avgHeartRate, calories: calories, lapTimes: lapTimes, lapStrokes: lapStrokes, fatigueLevel: fatigueLevel, poolLength: poolLength, date: ISO8601DateFormatter().string(from: Date()), source: "apple_watch", watchToken: watchToken)
        try await postExpectingError("/api/watch/workout", body)
    }
}
