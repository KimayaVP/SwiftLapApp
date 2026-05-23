//
//  CoachPlaceholders.swift
//  SwiftLap (iOS)
//
//  Stubs for coach screens not yet built. Filled in over the rest of M5.
//

import SwiftUI

private struct CoachComingSoon: View {
    let title: String
    let icon: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 44)).foregroundStyle(.cyan.opacity(0.7))
            Text(title).font(.title3.bold())
            Text("Coming soon").foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CoachBatchesView: View { var body: some View { CoachComingSoon(title: "Batches & Swimmers", icon: "person.3.fill") } }
struct CoachRecommendView: View { var body: some View { CoachComingSoon(title: "Recommend Meet", icon: "flag.checkered") } }
struct CoachAssignView: View { var body: some View { CoachComingSoon(title: "Assign", icon: "target") } }

struct CoachInviteView: View {
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            CoachComingSoon(title: "Invite Swimmer", icon: "person.badge.plus")
                .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } } }
        }
    }
}
