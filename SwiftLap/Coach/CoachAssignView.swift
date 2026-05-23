//
//  CoachAssignView.swift
//  SwiftLap (iOS)
//

import SwiftUI

struct CoachAssignView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var swimmers: [CoachSwimmer] = []
    @State private var swimmerId = ""
    @State private var tab = 0   // 0 = goal, 1 = routine

    // Goal
    @State private var stroke = "Freestyle"
    @State private var distance = 50
    @State private var minutes = ""
    @State private var seconds = ""

    // Routine
    @State private var title = ""
    @State private var details = ""

    @State private var status: String?

    var body: some View {
        List {
            Section("Swimmer") {
                Picker("Swimmer", selection: $swimmerId) {
                    Text("Select…").tag("")
                    ForEach(swimmers) { Text($0.name).tag($0.id) }
                }
            }
            Section {
                Picker("", selection: $tab) {
                    Text("Goal").tag(0)
                    Text("Routine").tag(1)
                }
                .pickerStyle(.segmented)
            }
            if tab == 0 {
                Section("Assign a Goal") {
                    Picker("Stroke", selection: $stroke) { ForEach(strokeOptions, id: \.self) { Text($0) } }
                    Picker("Distance", selection: $distance) { ForEach(distanceOptions, id: \.self) { Text("\($0)m").tag($0) } }
                    HStack {
                        TextField("Min", text: $minutes).keyboardType(.numberPad)
                        Text(":").foregroundStyle(.secondary)
                        TextField("Sec", text: $seconds).keyboardType(.numberPad)
                    }
                    Button("Assign Goal") { Task { await assignGoal() } }.disabled(swimmerId.isEmpty)
                }
            } else {
                Section("Assign a Routine") {
                    TextField("Title (e.g. Endurance week)", text: $title)
                    TextField("Details", text: $details, axis: .vertical)
                    Button("Assign Routine") { Task { await assignRoutine() } }.disabled(swimmerId.isEmpty || title.isEmpty)
                }
            }
            if let status { Text(status).font(.caption).foregroundStyle(.green) }
        }
        .navigationTitle("Assign")
        .task { await load() }
    }

    private func load() async {
        guard let id = auth.currentUser?.id else { return }
        swimmers = (try? await APIClient.shared.coachDashboard(coachId: id))?.swimmers ?? []
    }

    private func assignGoal() async {
        guard let coachId = auth.currentUser?.id, !swimmerId.isEmpty else { return }
        let m = Int(minutes) ?? 0, s = Int(seconds) ?? 0
        guard m > 0 || s > 0 else { status = "Enter a target time"; return }
        do {
            try await APIClient.shared.assignGoal(coachId: coachId, swimmerId: swimmerId, stroke: stroke, distance: distance, targetMinutes: m, targetSeconds: s)
            minutes = ""; seconds = ""; status = "Goal assigned"
        } catch { status = (error as? APIError)?.errorDescription ?? error.localizedDescription }
    }

    private func assignRoutine() async {
        guard let coachId = auth.currentUser?.id, !swimmerId.isEmpty, !title.isEmpty else { return }
        do {
            try await APIClient.shared.assignRoutine(coachId: coachId, swimmerId: swimmerId, title: title, details: details.isEmpty ? nil : details)
            title = ""; details = ""; status = "Routine assigned"
        } catch { status = (error as? APIError)?.errorDescription ?? error.localizedDescription }
    }
}
