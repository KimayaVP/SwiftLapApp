//
//  WatchLoginView.swift
//  SwiftLap (watchOS)
//

import SwiftUI

struct WatchLoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var digits: [String] = ["", "", "", ""]
    @State private var loading = false
    @State private var error: String?

    private var code: String { digits.joined() }
    private var isFilled: Bool { digits.allSatisfy { !$0.isEmpty } }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: "figure.pool.swim")
                    .font(.system(size: 30))
                    .foregroundColor(.cyan)
                Text("SwiftLap").font(.headline)
                Text("Enter your 4-digit code")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                // 4 digit boxes
                HStack(spacing: 6) {
                    ForEach(0..<4, id: \.self) { i in
                        Text(digits[i].isEmpty ? "-" : digits[i])
                            .font(.title3.bold())
                            .frame(width: 30, height: 34)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(6)
                    }
                }

                // Digit pad rows 1–9
                ForEach([[1, 2, 3], [4, 5, 6], [7, 8, 9]], id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.self) { digit in
                            Button("\(digit)") { appendDigit("\(digit)") }
                                .frame(width: 38, height: 32)
                                .background(Color.gray.opacity(0.25))
                                .cornerRadius(6)
                        }
                    }
                }

                // Bottom row: backspace, 0
                HStack(spacing: 8) {
                    Button(action: backspace) {
                        Image(systemName: "delete.left")
                            .font(.caption)
                    }
                    .frame(width: 38, height: 32)
                    .background(Color.gray.opacity(0.25))
                    .cornerRadius(6)

                    Button("0") { appendDigit("0") }
                        .frame(width: 38, height: 32)
                        .background(Color.gray.opacity(0.25))
                        .cornerRadius(6)

                    Color.clear.frame(width: 38, height: 32)
                }

                if let error {
                    Text(error).font(.caption2).foregroundColor(.red)
                }

                Button(action: link) {
                    if loading { ProgressView() } else { Text("Link Watch") }
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .disabled(!isFilled || loading)
            }
            .padding()
        }
    }

    func appendDigit(_ d: String) {
        guard let i = digits.firstIndex(of: "") else { return }
        digits[i] = d
    }

    func backspace() {
        for i in stride(from: 3, through: 0, by: -1) {
            if !digits[i].isEmpty {
                digits[i] = ""
                return
            }
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
