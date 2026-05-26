//
//  VideoView.swift
//  SwiftLap (iOS)
//

import SwiftUI
import PhotosUI
import AVFoundation

/// Picked video as a file URL (so we can inspect its duration before upload).
struct PickedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
            try? FileManager.default.removeItem(at: temp)
            try FileManager.default.copyItem(at: received.file, to: temp)
            return PickedMovie(url: temp)
        }
    }
}

enum VideoUploadError: LocalizedError {
    case tooLong
    var errorDescription: String? {
        switch self { case .tooLong: return "Please choose a clip under 5 minutes." }
    }
}

struct VideoView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var stroke = "Freestyle"
    @State private var pickedItem: PhotosPickerItem?
    @State private var hasPicked = false
    @State private var uploading = false
    @State private var status: String?

    @State private var feedbacks: [VideoFeedback] = []
    @State private var comments: [CoachComment] = []
    @State private var loading = true

    var body: some View {
        List {
            Section("Upload Video") {
                Picker("Stroke", selection: $stroke) {
                    ForEach(strokeOptions, id: \.self) { Text($0) }
                }
                PhotosPicker(selection: $pickedItem, matching: .videos) {
                    Label(hasPicked ? "Video selected ✓" : "Choose a video", systemImage: "video.badge.plus")
                }
                Button {
                    Task { await upload() }
                } label: {
                    if uploading {
                        HStack { ProgressView(); Text("Analyzing…") }
                    } else {
                        Text("Upload")
                    }
                }
                .disabled(!hasPicked || uploading)
                if let status { Text(status).font(.caption).foregroundStyle(.secondary) }
            }

            Section {
                if loading {
                    ProgressView()
                } else if feedbacks.isEmpty {
                    Text("Upload a video for feedback").foregroundStyle(.secondary)
                } else {
                    ForEach(feedbacks.prefix(3)) { f in feedbackRow(f) }
                }
            } header: {
                HStack(spacing: 6) {
                    Text("Stroke Analysis")
                    Text("DEMO")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color.gray))
                        .foregroundStyle(.white)
                }
            } footer: {
                Text("Demonstration only — this shows sample technique notes, not real analysis of your video yet.")
            }

            Section("Coach Feedback") {
                if comments.isEmpty {
                    Text("No coach feedback yet").foregroundStyle(.secondary)
                } else {
                    ForEach(comments) { c in commentRow(c) }
                }
            }
        }
        .navigationTitle("Video & Feedback")
        .onChange(of: pickedItem) { _, newValue in
            hasPicked = newValue != nil
            status = nil
        }
        .task { await load() }
    }

    @ViewBuilder
    private func feedbackRow(_ f: VideoFeedback) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(f.stroke) • \(shortDate(f.createdAt))").font(.subheadline.weight(.medium))
                Spacer()
                if let score = f.feedback.overallScore {
                    Text("\(score)/10").font(.caption.weight(.bold)).foregroundStyle(.cyan)
                }
            }
            if let focus = f.feedback.priorityFocus {
                Text("Focus on: \(focus)").font(.caption).foregroundStyle(.secondary)
            }
            if let coach = f.coachFeedback, !coach.isEmpty {
                Text("👨‍🏫 Coach: \(coach)").font(.caption).foregroundStyle(.green)
            }
        }
    }

    @ViewBuilder
    private func commentRow(_ c: CoachComment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(c.coach?.name ?? "Coach").font(.subheadline.weight(.semibold)).foregroundStyle(.green)
                Spacer()
                Text(shortDate(c.createdAt)).font(.caption2).foregroundStyle(.secondary)
            }
            if let r = c.reaction, !r.isEmpty { Text(r).font(.title3) }
            if let comment = c.comment, !comment.isEmpty { Text(comment).font(.subheadline) }
            if let t = c.time, let s = t.stroke, let d = t.distance, let secs = t.timeSeconds {
                Text("On: \(s) \(d)m – \(formatLapTime(secs))").font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private func shortDate(_ iso: String?) -> String {
        guard let iso, iso.count >= 10 else { return "" }
        return String(iso.prefix(10))
    }

    private func load() async {
        guard let id = auth.currentUser?.id else { return }
        loading = true
        feedbacks = (try? await APIClient.shared.fetchVideoFeedback(swimmerId: id)) ?? []
        comments = (try? await APIClient.shared.fetchCoachComments(swimmerId: id)) ?? []
        loading = false
    }

    private func upload() async {
        guard let id = auth.currentUser?.id, let item = pickedItem else { return }
        uploading = true; status = nil
        do {
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                status = "Couldn't read that video"; uploading = false; return
            }
            let asset = AVURLAsset(url: movie.url)
            let duration = try await asset.load(.duration)
            if CMTimeGetSeconds(duration) > 300 { throw VideoUploadError.tooLong }
            let data = try Data(contentsOf: movie.url)
            try? FileManager.default.removeItem(at: movie.url)
            try await APIClient.shared.uploadVideo(swimmerId: id, stroke: stroke, videoData: data, filename: "swim.mov", mimeType: "video/quicktime")
            status = "Uploaded — feedback ready below."
            pickedItem = nil; hasPicked = false
            await load()
        } catch {
            status = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        uploading = false
    }
}
