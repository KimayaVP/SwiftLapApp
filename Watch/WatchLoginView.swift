//
//  WatchLoginView.swift
//  SwiftLap (watchOS)
//

import SwiftUI

struct WatchLoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var code = ""
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "figure.pool.swim")
                    .font(.system(size: 40))
                    .foregroundColor(.cyan)
                Text("SwiftLap").font(.headline)
                Text("Enter your 6-digit code from the website")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                TextField("Code", text: $code)
                if let error {
                    Text(error).font(.caption2).foregroundColor(.red)
                }
                Button(action: link) {
                    if loading { ProgressView() } else { Text("Link Watch") }
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .disabled(code.count < 6 || loading)
            }
            .padding()
        }
    }

    private func link() {
        loading = true
        error = nil
        Task {
            do {
                let link = try await APIClient.shared.verifyWatchCode(code)
                WatchStore.setSwimmerId(link.swimmerId)
                WatchStore.setWatchToken(link.watchToken)
                isLoggedIn = true
            } catch {
                self.error = (error as? APIError)?.errorDescription ?? "Invalid code"
            }
            loading = false
        }
    }
}
