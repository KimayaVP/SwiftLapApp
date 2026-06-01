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
    @State private var promptRole: String?   // role tapped in the OAuth role prompt

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Brand header
                VStack(spacing: 10) {
                    ZStack {
                        Circle().fill(Theme.softGradient).frame(width: 96, height: 96)
                        Image(systemName: "figure.pool.swim")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(Theme.teal)
                    }
                    Text("SwiftLap")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.navy)
                    Text("Track. Analyze. Improve.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 12)

                Picker("", selection: $mode) {
                    Text("Login").tag(0)
                    Text("Sign Up").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.top, 4)

                VStack(spacing: 12) {
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
                        Text("I am a…").font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        HStack(spacing: 12) {
                            roleCard("swimmer", icon: "figure.pool.swim", label: "Swimmer")
                            roleCard("coach", icon: "figure.wave", label: "Coach")
                        }
                    }
                }

                Button {
                    Task { await submit() }
                } label: {
                    if auth.isWorking { ProgressView().tint(.white) }
                    else { Text(mode == 0 ? "Login" : "Create Account") }
                }
                .buttonStyle(.brandPrimary)
                .disabled(auth.isWorking)

                if let err = auth.errorMessage {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(Theme.coral)
                        .multilineTextAlignment(.center)
                }

                HStack {
                    Rectangle().fill(.quaternary).frame(height: 1)
                    Text("or").font(.caption).foregroundStyle(.secondary)
                    Rectangle().fill(.quaternary).frame(height: 1)
                }
                .padding(.vertical, 2)

                // Google — white card, branded "G", consistent height with Apple.
                Button {
                    Task { await auth.signInWithGoogle() }
                } label: {
                    HStack(spacing: 10) {
                        Text("G")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: 0x4285F4))
                        Text("Continue with Google")
                            .font(.headline)
                            .foregroundStyle(Theme.navy)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color(.separator), lineWidth: 1))
                }
                .buttonStyle(.plain)

                SignInWithAppleButton(.continue) { request in
                    let nonce = Self.randomNonce()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = Self.sha256(nonce)
                } onCompletion: { result in
                    handleApple(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding()
        }
        .sheet(isPresented: $auth.needsRolePrompt, onDismiss: { promptRole = nil }) {
            rolePrompt
        }
    }

    // Selectable role card (sign-up form).
    private func roleCard(_ value: String, icon: String, label: String) -> some View {
        let selected = role == value
        return Button {
            role = value
        } label: {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(selected ? .white : Theme.teal)
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selected ? .white : Theme.navy)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(selected ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color(.secondarySystemBackground)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? .clear : Theme.teal.opacity(0.25), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var rolePrompt: some View {
        VStack(spacing: 18) {
            Text("👋 Welcome\(auth.pendingName.map { ", \($0)" } ?? "")!")
                .font(.title2.bold())
            Text("One quick thing — how will you use SwiftLap?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                promptRoleCard("swimmer", icon: "figure.pool.swim", label: "I'm a Swimmer")
                promptRoleCard("coach", icon: "figure.wave", label: "I'm a Coach")
            }
            if let err = auth.errorMessage {
                Text(err).font(.caption).foregroundStyle(Theme.coral).multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .presentationDetents([.medium])
    }

    // Role card in the OAuth prompt: highlights immediately on tap, then shows a
    // spinner while the signup finishes.
    private func promptRoleCard(_ value: String, icon: String, label: String) -> some View {
        let selected = promptRole == value
        return Button {
            promptRole = value
            Task { await auth.finishOAuthSignup(role: value) }
        } label: {
            VStack(spacing: 10) {
                if selected && auth.isWorking {
                    ProgressView().tint(.white).frame(height: 30)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(selected ? .white : Theme.teal)
                        .frame(height: 30)
                }
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(selected ? .white : Theme.navy)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? AnyShapeStyle(Theme.gradient) : AnyShapeStyle(Color(.secondarySystemBackground)))
            )
        }
        .buttonStyle(.plain)
        .disabled(auth.isWorking)
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
