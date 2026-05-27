//
//  NotificationsView.swift
//  SwiftLap (iOS)
//
//  In-app notification inbox + a reusable bell button (with unread badge) for
//  swimmer and coach home screens. Backed by /api/notifications.
//

import SwiftUI

/// Toolbar bell that shows the unread count and opens the inbox.
struct NotificationsBell: View {
    @EnvironmentObject var auth: AuthManager
    @State private var unread = 0
    @State private var show = false

    var body: some View {
        Button { show = true } label: {
            Image(systemName: "bell")
                .overlay(alignment: .topTrailing) {
                    if unread > 0 {
                        Text(unread > 9 ? "9+" : "\(unread)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Capsule().fill(.red))
                            .offset(x: 9, y: -8)
                    }
                }
        }
        .accessibilityLabel("Notifications")
        .task { await loadCount() }
        .sheet(isPresented: $show, onDismiss: { Task { await loadCount() } }) {
            NotificationsView().environmentObject(auth)
        }
    }

    private func loadCount() async {
        guard let id = auth.currentUser?.id else { return }
        unread = (try? await APIClient.shared.fetchNotifications(userId: id))?.unread ?? 0
    }
}

struct NotificationsView: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var items: [AppNotification] = []
    @State private var loading = true

    var body: some View {
        NavigationStack {
            List {
                if loading {
                    ProgressView()
                } else if items.isEmpty {
                    Text("No notifications yet").foregroundStyle(.secondary)
                } else {
                    ForEach(items) { n in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(n.title)
                                .font(.subheadline.weight(n.readAt == nil ? .semibold : .regular))
                            if let b = n.body, !b.isEmpty {
                                Text(b).font(.caption).foregroundStyle(.secondary)
                            }
                            if let t = n.createdAt {
                                Text(String(t.prefix(10))).font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                        .listRowBackground(n.readAt == nil ? Color.cyan.opacity(0.08) : Color.clear)
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task { await load() }
        }
    }

    private func load() async {
        guard let id = auth.currentUser?.id else { return }
        loading = true
        items = (try? await APIClient.shared.fetchNotifications(userId: id))?.notifications ?? []
        loading = false
        // Mark everything read now that the inbox is open.
        try? await APIClient.shared.markNotificationsRead()
    }
}
