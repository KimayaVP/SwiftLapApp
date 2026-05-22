//
//  LoginView.swift
//  SwiftLap (iOS)
//

import SwiftUI
import AuthenticationServices
import CryptoKit

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var mode = 0          // 0 = login, 1 = sign up
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var role = "swimmer"
    @State private var currentNonce: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(systemName: "figure.pool.swim")
                    .font(.system(size: 50))
                    .foregroundStyle(.cyan)
                Text("SwiftLap").font(.largeTitle.bold())
                Text("Track. Analyze. Improve.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("", selection: $mode) {
                    Text("Login").tag(0)
                    Text("Sign Up").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.top, 8)

                if mode == 1 {
                    TextField("Name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                TextField("Email", text: $email)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Password", text: $password)
                    .textFieldStyle(.roundedBorder)

                if mode == 1 {
                    Picker("Role", selection: $role) {
                        Text("Swimmer").tag("swimmer")
                        Text("Coach").tag("coach")
                    }
                    .pickerStyle(.segmented)
                }

                Button {
                    Task { await submit() }
                } label: {
                    Group {
                        if auth.isWorking { ProgressView() }
                        else { Text(mode == 0 ? "Login" : "Create Account") }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .controlSize(.large)
                .disabled(auth.isWorking)

                if let err = auth.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                HStack {
                    Rectangle().fill(.quaternary).frame(height: 1)
                    Text("or").font(.caption).foregroundStyle(.secondary)
                    Rectangle().fill(.quaternary).frame(height: 1)
                }
                .padding(.vertical, 4)

                Button {
                    Task { await auth.signInWithGoogle() }
                } label: {
                    Label("Continue with Google", systemImage: "globe")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                SignInWithAppleButton(.continue) { request in
                    let nonce = Self.randomNonce()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = Self.sha256(nonce)
                } onCompletion: { result in
                    handleApple(result)
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 50)
            }
            .padding()
        }
        .sheet(isPresented: $auth.needsRolePrompt) {
            rolePrompt
        }
    }

    private var rolePrompt: some View {
        VStack(spacing: 16) {
            Text("👋 Welcome\(auth.pendingName.map { ", \($0)" } ?? "")!")
                .font(.title2.bold())
            Text("One quick thing — how will you use SwiftLap?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await auth.finishOAuthSignup(role: "swimmer") }
            } label: {
                Text("🏊 I'm a Swimmer").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            Button {
                Task { await auth.finishOAuthSignup(role: "coach") }
            } label: {
                Text("👨‍🏫 I'm a Coach").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).controlSize(.large)
        }
        .padding()
        .presentationDetents([.medium])
    }

    private func submit() async {
        if mode == 0 {
            await auth.loginEmail(email: email, password: password)
        } else {
            await auth.signupEmail(name: name, email: email, password: password, role: role)
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authResults):
            guard let cred = authResults.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8),
                  let nonce = currentNonce else { return }
            Task { await auth.signInWithApple(idToken: idToken, nonce: nonce) }
        case .failure(let error):
            auth.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Nonce helpers (Apple-recommended boilerplate)

    private static func randomNonce(length: Int = 32) -> String {
        let chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._"
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            _ = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if random < chars.count {
                result.append(chars[chars.index(chars.startIndex, offsetBy: Int(random))])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let hashed = SHA256.hash(data: Data(input.utf8))
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
}
