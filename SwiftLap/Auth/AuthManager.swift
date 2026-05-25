//
//  AuthManager.swift
//  SwiftLap (iOS)
//
//  Owns the signed-in user. Email auth goes through the backend; Google and
//  Apple go through Supabase (OAuth web session / native ID token), then we
//  hand the resulting access token to the backend's /auth/oauth-sync.
//

import Foundation
import Supabase

@MainActor
final class AuthManager: ObservableObject {
    @Published var currentUser: Profile?
    @Published var errorMessage: String?
    @Published var isWorking = false

    // OAuth first-login role prompt
    @Published var needsRolePrompt = false
    @Published var pendingName: String?
    private var pendingToken: String?

    private var supabase: SupabaseClient?
    private let redirectURL = URL(string: "com.swiftlap.ios://login-callback")!
    private let storeKey = "currentUser"
    private let tokenKey = "accessToken"
    private var storedToken: String?

    init() {
        // Attach a Bearer token to every API request. Prefers the Supabase SDK
        // session (which auto-refreshes an expired token) once signed in, and
        // falls back to the last stored token.
        APIClient.shared.tokenProvider = { [weak self] in await self?.currentAccessToken() }
        storedToken = UserDefaults.standard.string(forKey: tokenKey)
        #if DEBUG
        // Screenshot/UI-test hook: launch with -uitestSwimmer / -uitestCoach to
        // skip login with a mock profile (fetches return empty → empty states).
        if CommandLine.arguments.contains("-uitestSwimmer") {
            currentUser = Profile(id: "UITEST", email: "test@swiftlap.app", name: "Test Swimmer", role: "swimmer", coachId: nil, watchLinkedAt: nil, showOnLeaderboard: nil)
            return
        }
        if CommandLine.arguments.contains("-uitestCoach") {
            currentUser = Profile(id: "UITEST", email: "coach@swiftlap.app", name: "Test Coach", role: "coach", coachId: nil, watchLinkedAt: nil, showOnLeaderboard: nil)
            return
        }
        #endif
        if let data = UserDefaults.standard.data(forKey: storeKey),
           let user = try? JSONDecoder().decode(Profile.self, from: data) {
            currentUser = user
        }
    }

    // MARK: - Email

    func loginEmail(email: String, password: String) async {
        await run {
            let resp = try await APIClient.shared.login(email: email, password: password)
            guard let user = resp.user else { throw APIError.server(resp.error ?? "Login failed") }
            self.storeToken(resp.session?.accessToken)
            self.persist(user)
            await self.loadSDKSession(resp.session)
        }
    }

    func signupEmail(name: String, email: String, password: String, role: String) async {
        await run {
            let resp = try await APIClient.shared.signup(name: name, email: email, password: password, role: role)
            guard let user = resp.user else { throw APIError.server(resp.error ?? "Sign up failed") }
            // Backend returns a session for new signups → log straight in.
            self.storeToken(resp.session?.accessToken)
            self.persist(user)
            await self.loadSDKSession(resp.session)
        }
    }

    // MARK: - Google

    func signInWithGoogle() async {
        await run {
            let client = try await self.client()
            let session = try await client.auth.signInWithOAuth(provider: .google, redirectTo: self.redirectURL)
            try await self.completeOAuth(token: session.accessToken)
        }
    }

    // MARK: - Apple (native)

    func signInWithApple(idToken: String, nonce: String) async {
        await run {
            let client = try await self.client()
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
            )
            try await self.completeOAuth(token: session.accessToken)
        }
    }

    // MARK: - OAuth role flow

    private func completeOAuth(token: String) async throws {
        let resp = try await APIClient.shared.oauthSync(accessToken: token)
        // The Supabase SDK already holds this session (we signed in through it),
        // so it can refresh the token; store it as a fallback too.
        if let user = resp.user { storeToken(token); persist(user); return }
        if resp.needsRole == true {
            pendingToken = token
            pendingName = resp.name
            needsRolePrompt = true
            return
        }
        throw APIError.server(resp.error ?? "Sign in failed")
    }

    func finishOAuthSignup(role: String) async {
        guard let token = pendingToken else { return }
        await run {
            let resp = try await APIClient.shared.oauthSync(accessToken: token, role: role)
            guard let user = resp.user else { throw APIError.server(resp.error ?? "Sign up failed") }
            self.storeToken(token)
            self.pendingToken = nil
            self.needsRolePrompt = false
            self.persist(user)
        }
    }

    /// After a swimmer accepts a coach's invite, reflect the link locally so the
    /// "no coach" banner disappears without needing a full re-login.
    func markLinkedToCoach(_ coachId: String) {
        guard let u = currentUser else { return }
        persist(Profile(id: u.id, email: u.email, name: u.name, role: u.role,
                        coachId: coachId, watchLinkedAt: u.watchLinkedAt,
                        showOnLeaderboard: u.showOnLeaderboard))
    }

    // MARK: - Delete account

    func deleteAccount() async {
        guard let id = currentUser?.id else { return }
        await run {
            try await APIClient.shared.deleteAccount(userId: id)
        }
        if errorMessage == nil { logout() }
    }

    // MARK: - Logout

    func logout() {
        currentUser = nil
        storeToken(nil)
        UserDefaults.standard.removeObject(forKey: storeKey)
        if let supabase {
            Task { try? await supabase.auth.signOut() }
        }
    }

    // MARK: - Token

    /// A current access token for API calls. Once signed in, reads from the
    /// Supabase SDK (auto-refreshing if expired); otherwise the stored token.
    func currentAccessToken() async -> String? {
        guard currentUser != nil else { return storedToken }
        if let client = try? await client(), let session = try? await client.auth.session {
            return session.accessToken
        }
        return storedToken
    }

    private func storeToken(_ token: String?) {
        storedToken = token
        if let token { UserDefaults.standard.set(token, forKey: tokenKey) }
        else { UserDefaults.standard.removeObject(forKey: tokenKey) }
    }

    /// Loads the email-login session into the Supabase SDK so it can refresh the
    /// access token. Best-effort: login still succeeds if Supabase is unreachable.
    private func loadSDKSession(_ session: Session?) async {
        guard let session, let refresh = session.refreshToken else { return }
        try? await client().auth.setSession(accessToken: session.accessToken, refreshToken: refresh)
    }

    // MARK: - Helpers

    private func persist(_ user: Profile) {
        currentUser = user
        if let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    private func client() async throws -> SupabaseClient {
        if let supabase { return supabase }
        let cfg = try await APIClient.shared.fetchConfig()
        guard let url = URL(string: cfg.supabaseUrl) else { throw APIError.invalidURL }
        let client = SupabaseClient(supabaseURL: url, supabaseKey: cfg.supabaseAnonKey)
        supabase = client
        return client
    }

    private func run(_ op: () async throws -> Void) async {
        isWorking = true
        errorMessage = nil
        do {
            try await op()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        isWorking = false
    }
}
