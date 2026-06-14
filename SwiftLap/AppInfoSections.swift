//
//  AppInfoSections.swift
//  SwiftLap (iOS)
//
//  Shared "Feedback" + "About the Developer" sections, used in BOTH the
//  swimmer Settings screen and the coach Settings sheet so the two roles
//  stay identical.
//
//  NOTE: the feedback email and developer bio are PLACEHOLDERS for now —
//  Kimaya will supply the real values. To fill them in, just set the two
//  constants below; the UI switches from the "coming soon" placeholder to
//  the real content automatically.
//

import SwiftUI

struct AppInfoSections: View {
    // MARK: - Fill these in later ----------------------------------------
    /// Support / feedback email address. Leave empty to show a placeholder.
    private let feedbackEmail = "feedback@swiftlap.in"
    /// Developer bio shown under "About the Developer". Leave empty for placeholder.
    private let developerBio = """
    My alarm goes off at 4 a.m. every day! I'm Kimaya, a Grade 10 student from Chennai, India. I am a competitive swimmer and top-10 finisher at the CISCE National Swimming Championships 2025.

    I have always had a vision to contribute to the swimming community. As I taught myself coding and AI, the idea for this app grew alongside those skills. I've designed it to help swimmers receive personalised workouts tailored to their goals.

    Built by a swimmer who knows the challenges of generic group workouts while trying to achieve their own goals.
    """
    /// Contact address shown under the developer bio. Leave empty to hide.
    private let contactEmail = "contact@swiftlap.in"
    // --------------------------------------------------------------------

    var body: some View {
        Group {
            // MARK: Feedback
            Section {
                if feedbackEmail.isEmpty {
                    Text("Feedback email coming soon.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else if let url = URL(string: "mailto:\(feedbackEmail)") {
                    Link(destination: url) {
                        Label("Email us", systemImage: "envelope")
                    }
                    Text(feedbackEmail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } header: {
                Text("Feedback")
            } footer: {
                Text("Found a bug or have an idea? We'd love to hear from you.")
            }

            // MARK: About the Developer
            Section {
                if developerBio.isEmpty {
                    Text("More about the developer coming soon.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    Text(developerBio)
                        .font(.callout)
                    if !contactEmail.isEmpty, let url = URL(string: "mailto:\(contactEmail)") {
                        Link(destination: url) {
                            Label("Contact: \(contactEmail)", systemImage: "envelope")
                                .font(.caption)
                        }
                    }
                }
            } header: {
                Text("About the Developer")
            }
        }
    }
}

/// Coach Settings sheet — the coach has no standalone Settings screen, so this
/// hosts the shared Feedback + About sections (opened from the coach menu).
struct CoachSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                AppInfoSections()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
