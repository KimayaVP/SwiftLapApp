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
    @State private var filter = "all"   // all | upcoming | over

    private var filteredMeets: [Meet] {
        filter == "all" ? meets : meets.filter { ($0.status ?? "over") == filter }
    }

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

            Section {
                Picker("Filter", selection: $filter) {
                    Text("All").tag("all")
                    Text("Upcoming").tag("upcoming")
                    Text("Over").tag("over")
                }
                .pickerStyle(.segmented)
            }

            Section("Meets & Races") {
                if loading {
                    ProgressView()
                } else if filteredMeets.isEmpty {
                    Text(filter == "all" ? "No meets yet" : "No \(filter) meets").foregroundStyle(.secondary)
                } else {
                    ForEach(filteredMeets) { m in
                        NavigationLink { MeetDetailView(meet: m) } label: { meetRow(m) }
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
            AddMeetSheet { name, date, location, events in
                await createMeet(name: name, date: date, location: location, events: events)
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private func meetRow(_ m: Meet) -> some View {
        let isUpcoming = (m.status ?? "over") == "upcoming"
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(m.name).font(.subheadline.weight(.medium))
                Text(isUpcoming ? "Upcoming" : "Over")
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 2)
                    .background(isUpcoming ? Color.cyan.opacity(0.25) : Color.secondary.opacity(0.2))
                    .clipShape(Capsule())
            }
            HStack(spacing: 6) {
                if let d = m.date { Text(d) }
                if let loc = m.location, !loc.isEmpty { Text("· \(loc)") }
                if isUpcoming {
                    Text("· \(m.eventCount ?? 0) event\((m.eventCount ?? 0) == 1 ? "" : "s")")
                } else {
                    Text("· \(m.resultCount ?? 0)/\(m.eventCount ?? 0) logged")
                    if (m.pendingCount ?? 0) > 0 {
                        Text("· \(m.pendingCount ?? 0) to log").foregroundStyle(.orange)
                    }
                }
            }
            .font(.caption).foregroundStyle(.secondary)
        }
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

    private func createMeet(name: String, date: String?, location: String?, events: [APIClient.MeetEventInput]) async {
        guard let id = auth.currentUser?.id else { return }
        let meet = try? await APIClient.shared.createMeet(swimmerId: id, name: name, date: date, location: location, events: events)
        // For an upcoming meet, schedule a local reminder to log times the day after.
        if let meet, let dateStr = date, let d = parseISODate(dateStr),
           d >= Calendar.current.startOfDay(for: Date()) {
            await LocalNotifications.requestPermission()
            LocalNotifications.scheduleMeetLogReminder(meetName: name, meetDate: d, meetId: meet.id)
        }
        await load()
    }
}

// MARK: - Add meet (with multiple events)

private struct AddMeetSheet: View {
    @Environment(\.dismiss) var dismiss
    let onCreate: (String, String?, String?, [APIClient.MeetEventInput]) async -> Void

    @State private var name = ""
    @State private var date = Date()
    @State private var location = ""
    @State private var events: [DraftEvent] = []
    @State private var stroke = "Freestyle"
    @State private var distance = 50
    @State private var minutes = ""
    @State private var seconds = ""
    @State private var saving = false

    private struct DraftEvent: Identifiable {
        let id = UUID()
        var stroke: String
        var distance: Int
        var minutes: Int
        var seconds: Int
    }

    private var isUpcoming: Bool {
        Calendar.current.startOfDay(for: date) >= Calendar.current.startOfDay(for: Date())
    }
    private var timeLabel: String { isUpcoming ? "Expected time" : "Your time" }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Meet name", text: $name)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Location (optional)", text: $location)
                }

                Section {
                    if events.isEmpty {
                        Text(isUpcoming
                             ? "Add the events you're swimming, with your expected/goal time."
                             : "Add the events you swam, with the time you did.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        ForEach(events) { e in
                            HStack {
                                Text("\(e.stroke) \(e.distance)m")
                                Spacer()
                                if e.minutes > 0 || e.seconds > 0 {
                                    Text("\(isUpcoming ? "exp " : "")\(formatLapTime(Double(e.minutes * 60 + e.seconds)))")
                                        .foregroundStyle(.secondary).monospacedDigit()
                                }
                            }
                        }
                        .onDelete { events.remove(atOffsets: $0) }
                    }
                } header: { Text("Events") }

                Section("Add event") {
                    Picker("Stroke", selection: $stroke) { ForEach(strokeOptions, id: \.self) { Text($0) } }
                    Picker("Distance", selection: $distance) { ForEach(distanceOptions, id: \.self) { Text("\($0)m").tag($0) } }
                    HStack {
                        Text(timeLabel).foregroundStyle(.secondary)
                        Spacer()
                        TextField("Min", text: $minutes).keyboardType(.numberPad).frame(width: 50).multilineTextAlignment(.trailing)
                        Text(":").foregroundStyle(.secondary)
                        TextField("Sec", text: $seconds).keyboardType(.numberPad).frame(width: 50)
                    }
                    Button("Add event") { addEvent() }
                }
            }
            .navigationTitle("Add Meet")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Create") {
                        saving = true
                        Task {
                            await onCreate(name, isoDate(date), location.isEmpty ? nil : location, mappedEvents())
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || saving)
                }
            }
        }
    }

    private func addEvent() {
        events.append(DraftEvent(stroke: stroke, distance: distance,
                                 minutes: Int(minutes) ?? 0, seconds: Int(seconds) ?? 0))
        minutes = ""; seconds = ""
    }

    // Map drafts to API inputs: expected times for upcoming meets, actual otherwise.
    private func mappedEvents() -> [APIClient.MeetEventInput] {
        events.map { e in
            if isUpcoming {
                return APIClient.MeetEventInput(stroke: e.stroke, distance: e.distance,
                                                expectedMinutes: e.minutes, expectedSeconds: e.seconds,
                                                minutes: nil, seconds: nil)
            } else {
                return APIClient.MeetEventInput(stroke: e.stroke, distance: e.distance,
                                                expectedMinutes: nil, expectedSeconds: nil,
                                                minutes: e.minutes, seconds: e.seconds)
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
    @State private var logging: MeetResult?

    var body: some View {
        List {
            Section("Events") {
                if loading {
                    ProgressView()
                } else if results.isEmpty {
                    Text("No events yet").foregroundStyle(.secondary)
                } else {
                    ForEach(results) { r in resultRow(r) }
                }
            }
            Section("Add another event") {
                AddResultInline(meetId: meet.id) { await load() }
            }
        }
        .navigationTitle(meet.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $logging) { ev in
            LogResultSheet(event: ev) { minutes, seconds, place, medal in
                await logResult(ev, minutes: minutes, seconds: seconds, place: place, medal: medal)
            }
        }
        .task { await load() }
    }

    @ViewBuilder
    private func resultRow(_ r: MeetResult) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(r.stroke) \(r.distance)m").font(.subheadline.weight(.medium))
                if r.timeSeconds == nil {
                    if let e = r.expectedSeconds {
                        Text("Expected: \(formatLapTime(e))").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("No expected time").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 6) {
                        if let p = r.place { Text("Place: \(p)") }
                        if let e = r.expectedSeconds { Text("· exp \(formatLapTime(e))") }
                    }.font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let t = r.timeSeconds {
                if r.isPb == true { Text("PB").font(.caption2).foregroundStyle(.green) }
                Text(medalEmoji(r.medal))
                Text(formatLapTime(t)).font(.headline).monospacedDigit()
            } else {
                Button("Log time") { logging = r }
                    .buttonStyle(.borderedProminent).controlSize(.small)
            }
        }
    }

    private func medalEmoji(_ m: String?) -> String {
        switch m { case "gold": return "🥇"; case "silver": return "🥈"; case "bronze": return "🥉"; default: return "" }
    }

    private func load() async {
        guard let id = auth.currentUser?.id else { return }
        loading = true
        results = (try? await APIClient.shared.fetchMeetResults(meetId: meet.id, swimmerId: id)) ?? []
        loading = false
        // If everything's logged, drop the reminder.
        if results.allSatisfy({ $0.timeSeconds != nil }) {
            LocalNotifications.cancelMeetLogReminder(meetId: meet.id)
        }
    }

    private func logResult(_ r: MeetResult, minutes: Int, seconds: Int, place: Int?, medal: String?) async {
        guard let id = auth.currentUser?.id else { return }
        try? await APIClient.shared.logMeetResult(resultId: r.id, minutes: minutes, seconds: seconds, place: place, medal: medal, swimmerId: id)
        await load()
    }
}

// MARK: - Log an existing (expected) event's actual time

private struct LogResultSheet: View {
    @Environment(\.dismiss) var dismiss
    let event: MeetResult
    let onSave: (Int, Int, Int?, String?) async -> Void

    @State private var minutes = ""
    @State private var seconds = ""
    @State private var place = ""
    @State private var medal = ""
    @State private var saving = false

    private let medals = ["", "gold", "silver", "bronze"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("\(event.stroke) \(event.distance)m").font(.headline)
                    if let e = event.expectedSeconds {
                        Text("Expected: \(formatLapTime(e))").foregroundStyle(.secondary)
                    }
                }
                Section("Your time") {
                    HStack {
                        TextField("Min", text: $minutes).keyboardType(.numberPad)
                        Text(":").foregroundStyle(.secondary)
                        TextField("Sec", text: $seconds).keyboardType(.numberPad)
                    }
                    TextField("Place (optional)", text: $place).keyboardType(.numberPad)
                    Picker("Medal", selection: $medal) {
                        ForEach(medals, id: \.self) { Text($0.isEmpty ? "None" : $0.capitalized).tag($0) }
                    }
                }
            }
            .navigationTitle("Log Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let m = Int(minutes) ?? 0, s = Int(seconds) ?? 0
                        guard m > 0 || s > 0 else { return }
                        saving = true
                        Task {
                            await onSave(m, s, Int(place), medal.isEmpty ? nil : medal)
                            dismiss()
                        }
                    }.disabled(saving)
                }
            }
        }
    }
}

// MARK: - Add a brand-new event result inline (within meet detail)

private struct AddResultInline: View {
    let meetId: String
    let onAdded: () async -> Void
    @EnvironmentObject var auth: AuthManager

    @State private var stroke = "Freestyle"
    @State private var distance = 50
    @State private var minutes = ""
    @State private var seconds = ""
    @State private var place = ""
    @State private var medal = ""
    @State private var saving = false
    private let medals = ["", "gold", "silver", "bronze"]

    var body: some View {
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
        Button { Task { await add() } } label: {
            if saving { ProgressView() } else { Text("Add Result") }
        }.disabled(saving)
    }

    private func add() async {
        guard let id = auth.currentUser?.id else { return }
        let m = Int(minutes) ?? 0, s = Int(seconds) ?? 0
        guard m > 0 || s > 0 else { return }
        saving = true
        try? await APIClient.shared.addRaceResult(meetId: meetId, swimmerId: id, stroke: stroke, distance: distance, minutes: m, seconds: s, place: Int(place), medal: medal.isEmpty ? nil : medal)
        minutes = ""; seconds = ""; place = ""; medal = ""
        await onAdded()
        saving = false
    }
}

private func isoDate(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
}

private func parseISODate(_ s: String) -> Date? {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.timeZone = .current
    return f.date(from: s)
}
