//
//  Placeholders.swift
//  SwiftLap (iOS)
//
//  Stubs for swimmer tiles not yet built. Filled in over the rest of M4.
//

import SwiftUI

private struct ComingSoon: View {
    let title: String
    let icon: String
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(.cyan.opacity(0.7))
            Text(title).font(.title3.bold())
            Text("Coming soon").foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct VideoView: View { var body: some View { ComingSoon(title: "Video & Feedback", icon: "video.fill") } }
