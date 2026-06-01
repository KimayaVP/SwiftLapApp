//
//  CoachInviteView.swift
//  SwiftLap (iOS)
//

import SwiftUI

struct CoachInviteView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var sending = false
    @State private var errorText: String?
    @State private var toast: String?          // transient "invite sent" confirmation
    @State private var pending: [OutgoingInvite] = []

    var body: some View {
        NavigationStack {
            Form {
                Section("Invite a Swimmer") {
                    TextField("Swimmer email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if let errorText {
                        Text(errorText).font(.caption).foregroundStyle(Theme.coral)
                    }
                    Text("If they are not on SwiftLap yet, they get an email to sign up.")
                        .font(.caption2).foregroundStyle(.secondary)
                }

                Section {
                    Button {
                        Task { await send() }
                    } label: {
                        if sending { ProgressView().tint(.white) } else { Text("Send Invite") }
                    }
                    .buttonStyle(.brandPrimary)
                    .disabled(email.isEmpty || sending)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if !pending.isEmpty {
                    Section("Pending Invites Sent") {
                        ForEach(pending) { p in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(p.to?.name ?? p.to?.email ?? "Swimmer").font(.subheadline)
                                Text("Awaiting response").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Invite Swimmer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("Close")
                }
            }
            .overlay(alignment: .top) { toastBanner }
            .task { await loadPending() }
        }
    }

    @ViewBuilder
    private var toastBanner: some View {
        if let toast {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                Text(toast).font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Theme.gradient, in: Capsule())
            .shadow(color: Theme.navy.opacity(0.2), radius: 8, y: 3)
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func send() async {
        guard let id = auth.currentUser?.id else { return }
        sending = true; errorText = nil
        do {
            let resp = try await APIClient.shared.inviteSwimmer(coachId: id, email: email)
            let message = resp.emailed == true
                ? (resp.message ?? "Invite email sent")
                : "Invite sent to \(resp.swimmer?.name ?? "swimmer")!"
            email = ""
            await loadPending()
            showToast(message)
        } catch {
            errorText = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        sending = false
    }

    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { toast = message }
        Task {
            try? await Task.sleep(nanoseconds: 2_800_000_000)
            withAnimation(.easeOut(duration: 0.3)) { toast = nil }
        }
    }

    private func loadPending() async {
        guard let id = auth.currentUser?.id else { return }
        pending = (try? await APIClient.shared.outgoingInvites(coachId: id)) ?? []
    }
}
