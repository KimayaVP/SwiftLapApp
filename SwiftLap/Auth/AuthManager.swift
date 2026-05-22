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

    init() {
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
            self.persist(user)
        }
    }

    func signupEmail(name: String, email: String, password: String, role: String) async {
        await run {
            let resp = try await APIClient.shared.signup(name: name, email: email, password: password, role: role)
            guard let user = resp.user else { throw APIError.server(resp.error ?? "Sign up failed") }
            // Backend returns a session for new signups → log straight in.
            self.persist(user)
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
        if let user = resp.user { persist(user); return }
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
            self.pendingToken = nil
            self.needsRolePrompt = false
            self.persist(user)
        }
    }

    // MARK: - Logout

    func logout() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: storeKey)
        if let supabase {
            Task { try? await supabase.auth.signOut() }
        }
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
