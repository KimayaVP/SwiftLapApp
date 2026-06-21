//
//  AppInfoSections.swift
//  SwiftLap (iOS)
//
//  Dedicated "Contact & Feedback" screen — Contact us, Feedback, and About the
//  Developer (with photo). Reached from the home toolbar menu on BOTH roles so
//  the two stay identical. Previously these lived inside Settings; they were
//  moved out into their own screen (2026-06-21) to mirror web + Android.
//
//  The developer photo is the `DeveloperPhoto` asset (currently a placeholder —
//  replace developer_photo.png in Assets.xcassets/DeveloperPhoto.imageset with
//  Kimaya's real square photo). Falls back to an SF Symbol if the asset is absent.
//

import SwiftUI

// MARK: - Contact / feedback constants
private let feedbackEmail = "feedback@swiftlap.in"
private let contactEmail = "contact@swiftlap.in"
private let developerBio = """
My alarm goes off at 4 a.m. every day! I'm Kimaya, a Grade 10 student from Chennai, India. I am a competitive swimmer and top-10 finisher at the CISCE National Swimming Championships 2025.

I have always had a vision to contribute to the swimming community. As I taught myself coding and AI, the idea for this app grew alongside those skills. I've designed it to help swimmers receive personalised workouts tailored to their goals.

Built by a swimmer who knows the challenges of generic group workouts while trying to achieve their own goals.
"""

struct ContactFeedbackView: View {
    private var developerImage: Image {
        if let ui = UIImage(named: "DeveloperPhoto") { return Image(uiImage: ui) }
        return Image(systemName: "person.crop.circle.fill")
    }

    var body: some View {
        List {
            // MARK: Contact us
            Section {
                if let url = URL(string: "mailto:\(contactEmail)") {
                    Link(destination: url) { Label("Email us", systemImage: "envelope") }
                    Text(contactEmail)
                        .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            } header: {
                Text("Contact us")
            } footer: {
                Text("Questions about your account or the app? Reach out anytime.")
            }

            // MARK: Feedback
            Section {
                if let url = URL(string: "mailto:\(feedbackEmail)") {
                    Link(destination: url) { Label("Send feedback", systemImage: "bubble.left.and.bubble.right") }
                    Text(feedbackEmail)
                        .font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                }
            } header: {
                Text("Feedback")
            } footer: {
                Text("Found a bug or have an idea? We'd love to hear from you.")
            }

            // MARK: About the developer
            Section {
                HStack(spacing: 14) {
                    developerImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 72, height: 72)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Theme.teal.opacity(0.25), lineWidth: 1))
                        .foregroundStyle(Theme.teal)
                    Text("Kimaya").font(.headline).foregroundStyle(Theme.navy)
                }
                .padding(.vertical, 4)
                Text(developerBio).font(.callout)
            } header: {
                Text("About the developer")
            }
        }
        .navigationTitle("Contact & Feedback")
        .navigationBarTitleDisplayMode(.inline)
    }
}
