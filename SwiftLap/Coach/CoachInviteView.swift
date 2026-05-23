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
    @State private var status: String?
    @State private var pending: [OutgoingInvite] = []

    var body: some View {
        NavigationStack {
            List {
                Section("Invite a Swimmer") {
                    TextField("Swimmer email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        Task { await send() }
                    } label: {
                        if sending { ProgressView() } else { Text("Send Invite") }
                    }
                    .disabled(email.isEmpty || sending)
                    if let status { Text(status).font(.caption).foregroundStyle(.secondary) }
                    Text("If they are not on SwiftLap yet, they get an email to sign up.")
                        .font(.caption2).foregroundStyle(.secondary)
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
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } } }
            .task { await loadPending() }
        }
    }

    private func send() async {
        guard let id = auth.currentUser?.id else { return }
        sending = true; status = nil
        do {
            let resp = try await APIClient.shared.inviteSwimmer(coachId: id, email: email)
            status = resp.emailed == true ? (resp.message ?? "Invite email sent") : "Invite sent to \(resp.swimmer?.name ?? "swimmer")!"
            email = ""
            await loadPending()
        } catch {
            status = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        sending = false
    }

    private func loadPending() async {
        guard let id = auth.currentUser?.id else { return }
        pending = (try? await APIClient.shared.outgoingInvites(coachId: id)) ?? []
    }
}
