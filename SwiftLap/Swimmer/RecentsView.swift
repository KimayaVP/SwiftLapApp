//
//  RecentsView.swift
//  SwiftLap (iOS)
//

import SwiftUI

struct RecentsView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var times: [SwimTime] = []
    @State private var loading = true
    @State private var error: String?

    @State private var stroke = "Freestyle"
    @State private var distance = 50
    @State private var minutes = ""
    @State private var seconds = ""
    @State private var logging = false

    var body: some View {
        List {
            Section("Log a Time") {
                Picker("Stroke", selection: $stroke) {
                    ForEach(strokeOptions, id: \.self) { Text($0) }
                }
                Picker("Distance", selection: $distance) {
                    ForEach(distanceOptions, id: \.self) { Text("\($0)m").tag($0) }
                }
                HStack {
                    TextField("Min", text: $minutes).keyboardType(.numberPad)
                    Text(":").foregroundStyle(.secondary)
                    TextField("Sec", text: $seconds).keyboardType(.numberPad)
                }
                Button {
                    Task { await logTime() }
                } label: {
                    if logging { ProgressView() } else { Text("Log Time") }
                }
                .disabled(logging)
                if let error { Text(error).font(.caption).foregroundStyle(.red) }
            }

            Section("Recent Times") {
                if loading {
                    ProgressView()
                } else if times.isEmpty {
                    Text("No times logged yet").foregroundStyle(.secondary)
                } else {
                    ForEach(times) { t in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(t.stroke) \(t.distance)m").font(.subheadline.weight(.medium))
                                Text(t.date).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(sourceIcon(t.source)).font(.caption)
                            Text(formatLapTime(t.timeSeconds)).font(.headline).monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle("Recents")
        .task { await load() }
    }

    private func sourceIcon(_ source: String?) -> String {
        switch source {
        case "apple_watch": return "⌚"
        case "race": return "🏁"
        default: return "✍️"
        }
    }

    private func load() async {
        guard let id = auth.currentUser?.id else { return }
        loading = true
        do { times = try await APIClient.shared.fetchTimes(swimmerId: id) }
        catch { /* leave empty */ }
        loading = false
    }

    private func logTime() async {
        guard let id = auth.currentUser?.id else { return }
        let m = Int(minutes) ?? 0
        let s = Int(seconds) ?? 0
        guard m > 0 || s > 0 else { error = "Enter a time"; return }
        logging = true; error = nil
        do {
            try await APIClient.shared.logTime(swimmerId: id, stroke: stroke, distance: distance, minutes: m, seconds: s)
            minutes = ""; seconds = ""
            await load()
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        logging = false
    }
}
