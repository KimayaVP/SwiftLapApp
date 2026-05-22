//
//  MeetsView.swift
//  SwiftLap (iOS)
//

import SwiftUI

struct MeetsView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var recs: [MeetRecommendation] = []
    @State private var meets: [Meet] = []
    @State private var loading = true
    @State private var showAddMeet = false

    var body: some View {
        List {
            if !recs.isEmpty {
                Section("Coach Recommendations") {
                    ForEach(recs) { r in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("🏁 \(r.meetName)").font(.subheadline.weight(.semibold))
                            if let n = r.coachName { Text("From \(n)").font(.caption2).foregroundStyle(.secondary) }
                            if let note = r.note, !note.isEmpty { Text(note).font(.caption).foregroundStyle(.secondary) }
                            if r.status == "accepted" {
                                Text("✓ Accepted").font(.caption).foregroundStyle(.green)
                            } else {
                                HStack {
                                    Button("Accept") { Task { await respondRec(r, "accepted") } }
                                        .buttonStyle(.borderedProminent).controlSize(.small)
                                    Button("Dismiss") { Task { await respondRec(r, "declined") } }
                                        .buttonStyle(.bordered).controlSize(.small).tint(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Section("Meets & Races") {
                if loading {
                    ProgressView()
                } else if meets.isEmpty {
                    Text("No meets yet").foregroundStyle(.secondary)
                } else {
                    ForEach(meets) { m in
                        NavigationLink { MeetDetailView(meet: m) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(m.name).font(.subheadline.weight(.medium))
                                HStack(spacing: 6) {
                                    if let d = m.date { Text(d) }
                                    if let loc = m.location, !loc.isEmpty { Text("· \(loc)") }
                                    Text("· \(m.resultCount ?? 0) result\((m.resultCount ?? 0) == 1 ? "" : "s")")
                                }
                                .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Meets & Races")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showAddMeet = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showAddMeet) {
            AddMeetSheet { name, date, location in
                await createMeet(name: name, date: date, location: location)
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard let id = auth.currentUser?.id else { return }
        loading = true
        recs = ((try? await APIClient.shared.fetchMeetRecommendations(swimmerId: id)) ?? [])
            .filter { $0.status != "declined" }
        meets = (try? await APIClient.shared.fetchMeets(swimmerId: id)) ?? []
        loading = false
    }

    private func respondRec(_ r: MeetRecommendation, _ status: String) async {
        guard let id = auth.currentUser?.id else { return }
        try? await APIClient.shared.respondMeetRecommendation(recommendationId: r.id, status: status, swimmerId: id)
        await load()
    }

    private func createMeet(name: String, date: String?, location: String?) async {
        guard let id = auth.currentUser?.id else { return }
        try? await APIClient.shared.createMeet(swimmerId: id, name: name, date: date, location: location)
        await load()
    }
}

// MARK: - Add meet

private struct AddMeetSheet: View {
    @Environment(\.dismiss) var dismiss
    let onCreate: (String, String?, String?) async -> Void

    @State private var name = ""
    @State private var date = Date()
    @State private var location = ""
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                TextField("Meet name", text: $name)
                DatePicker("Date", selection: $date, displayedComponents: .date)
                TextField("Location", text: $location)
            }
            .navigationTitle("Add Meet")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        saving = true
                        Task {
                            await onCreate(name, isoDate(date), location.isEmpty ? nil : location)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || saving)
                }
            }
        }
    }
}

// MARK: - Meet detail

struct MeetDetailView: View {
    @EnvironmentObject var auth: AuthManager
    let meet: Meet

    @State private var results: [MeetResult] = []
    @State private var loading = true
    @State private var stroke = "Freestyle"
    @State private var distance = 50
    @State private var minutes = ""
    @State private var seconds = ""
    @State private var place = ""
    @State private var medal = ""
    @State private var saving = false

    private let medals = ["", "gold", "silver", "bronze"]

    var body: some View {
        List {
            Section("Results") {
                if loading {
                    ProgressView()
                } else if results.isEmpty {
                    Text("No results yet").foregroundStyle(.secondary)
                } else {
                    ForEach(results) { r in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(r.stroke) \(r.distance)m").font(.subheadline.weight(.medium))
                                if let p = r.place { Text("Place: \(p)").font(.caption).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            if r.isPb == true { Text("PB").font(.caption2).foregroundStyle(.green) }
                            Text(medalEmoji(r.medal))
                            Text(formatLapTime(r.timeSeconds)).font(.headline).monospacedDigit()
                        }
                    }
                }
            }
            Section("Add Race Result") {
                Picker("Stroke", selection: $stroke) { ForEach(strokeOptions, id: \.self) { Text($0) } }
                Picker("Distance", selection: $distance) { ForEach(distanceOptions, id: \.self) { Text("\($0)m").tag($0) } }
                HStack {
                    TextField("Min", text: $minutes).keyboardType(.numberPad)
                    Text(":").foregroundStyle(.secondary)
                    TextField("Sec", text: $seconds).keyboardType(.numberPad)
                }
                TextField("Place (optional)", text: $place).keyboardType(.numberPad)
                Picker("Medal", selection: $medal) {
                    ForEach(medals, id: \.self) { Text($0.isEmpty ? "None" : $0.capitalized).tag($0) }
                }
                Button { Task { await addResult() } } label: {
                    if saving { ProgressView() } else { Text("Add Result") }
                }.disabled(saving)
            }
        }
        .navigationTitle(meet.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func medalEmoji(_ m: String?) -> String {
        switch m { case "gold": return "🥇"; case "silver": return "🥈"; case "bronze": return "🥉"; default: return "" }
    }

    private func load() async {
        guard let id = auth.currentUser?.id else { return }
        loading = true
        results = (try? await APIClient.shared.fetchMeetResults(meetId: meet.id, swimmerId: id)) ?? []
        loading = false
    }

    private func addResult() async {
        guard let id = auth.currentUser?.id else { return }
        let m = Int(minutes) ?? 0, s = Int(seconds) ?? 0
        guard m > 0 || s > 0 else { return }
        saving = true
        try? await APIClient.shared.addRaceResult(meetId: meet.id, swimmerId: id, stroke: stroke, distance: distance, minutes: m, seconds: s, place: Int(place), medal: medal.isEmpty ? nil : medal)
        minutes = ""; seconds = ""; place = ""; medal = ""
        await load()
        saving = false
    }
}

private func isoDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
}
