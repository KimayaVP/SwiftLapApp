//
//  RemoteConfig.swift
//  Shared (iOS + watch)
//
//  The backend exposes the public Supabase URL + anon key at /api/config
//  (same values the web app uses). We fetch them at runtime rather than
//  hardcoding the key into the app.
//

import Foundation

extension APIClient {
    struct RemoteConfig: Decodable {
        let supabaseUrl: String
        let supabaseAnonKey: String
    }

    func fetchConfig() async throws -> RemoteConfig {
        try await get("/api/config")
    }
}
