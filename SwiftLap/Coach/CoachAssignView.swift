//
//  CoachAssignView.swift
//  SwiftLap (iOS)
//
//  Assign a Goal or Routine to a swimmer (narrowed by batch first so the
//  swimmer list stays short), and review everything already assigned.
//

import SwiftUI

struct CoachAssignView: View {
    @EnvironmentObject var auth: AuthManager

    /// When set (e.g. opened from a swimmer's page), the swimmer is preselected
    /// and the batch picker is hidden.
    var preselect: CoachSwimmer? = nil

    @State private var swimmers: [CoachSwimmer] = []
    @State private var batches: [(batch: Batch, memberIds: [String])] = []
    @State private var batchFilter = "all"     // "all" | batchId | "individuals"
    @State private var swimmerId = ""
    @State private var tab = 0                  // 0 = goal, 1 = routine

    // Goal
    @State private var stroke = "Freestyle"
    @State private var distance = 50
    @State private var minutes = ""
    @State private var seconds = ""

    // Routine
    @State private var title = ""
    @State private var details = ""

    @State private var status: String?
    @State private var assignedGoals: [Goal] = []
    @State private var assignedRoutines: [CoachRoutine] = []

    var body: some View {
        List {
            if let pre = preselect {
                Section("Swimmer") {
                    Text(pre.name).font(.subheadline.weight(.medium))
                }
            } else {
                Section("Choose a swimmer") {
                    Picker("Batch", selection: $batchFilter) {
                        Text("All swimmers").tag("all")
                        ForEach(batches, id: \.batch.id) { b in Text(b.batch.name).tag(b.batch.id) }
                        Text("Individuals").tag("individuals")
                    }
                    .onChange(of: batchFilter) { _, _ in
                        if !visibleSwimmers.contains(where: { $0.id == swimmerId }) { swimmerId = "" }
                    }
                    Picker("Swimmer", selection: $swimmerId) {
                        Text("Select…").tag("")
                        ForEach(visibleSwimmers) { Text($0.name).tag($0.id) }
                    }
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

            // What's already been assigned, with live status for goals.
            if tab == 0 {
                Section("Assigned Goals") {
                    if assignedGoals.isEmpty {
                        Text("No goals assigned yet.").foregroundStyle(.secondary)
                    } else {
                        ForEach(assignedGoals) { goalRow($0) }
                    }
                }
            } else {
                Section("Assigned Routines") {
                    if assignedRoutines.isEmpty {
                        Text("No routines assigned yet.").foregroundStyle(.secondary)
                    } else {
                        ForEach(assignedRoutines) { r in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.title).font(.subheadline.weight(.medium))
                                Text(r.swimmerName ?? "Swimmer").font(.caption2).foregroundStyle(.secondary)
                                if let d = r.details, !d.isEmpty {
                                    Text(d).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Goals & Routines")
        .task { await load() }
    }

    private var visibleSwimmers: [CoachSwimmer] {
        switch batchFilter {
        case "all": return swimmers
        case "individuals":
            let inAny = Set(batches.flatMap { $0.memberIds })
            return swimmers.filter { !inAny.contains($0.id) }
        default:
            let ids = Set(batches.first { $0.batch.id == batchFilter }?.memberIds ?? [])
            return swimmers.filter { ids.contains($0.id) }
        }
    }

    @ViewBuilder
    private func goalRow(_ g: Goal) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(g.swimmerName ?? "Swimmer")").font(.subheadline.weight(.medium))
                Text("\(g.stroke) \(g.distance)m · target \(formatLapTime(g.targetSeconds))")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            statusPill(g.status)
        }
    }

    @ViewBuilder
    private func statusPill(_ status: String?) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case "ahead": return ("On track", .green)
            case "behind": return ("Behind", Theme.coral)
            default: return ("No data", .secondary)
            }
        }()
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.15)))
    }

    private func load() async {
        guard let id = auth.currentUser?.id else { return }
        if let pre = preselect { swimmerId = pre.id }
        swimmers = (try? await APIClient.shared.coachDashboard(coachId: id))?.swimmers ?? []
        let bs = (try? await APIClient.shared.fetchBatches(coachId: id)) ?? []
        var result: [(Batch, [String])] = []
        for b in bs {
            let members = (try? await APIClient.shared.batchLeaderboard(batchId: b.id)) ?? []
            result.append((b, members.map { $0.id }))
        }
        batches = result
        await loadAssigned()
    }

    private func loadAssigned() async {
        guard let id = auth.currentUser?.id else { return }
        var goals = (try? await APIClient.shared.assignedGoals(coachId: id)) ?? []
        var routines = (try? await APIClient.shared.assignedRoutines(coachId: id)) ?? []
        // On a single swimmer's page, only show what's assigned to them.
        if let pre = preselect {
            goals = goals.filter { $0.swimmerId == pre.id }
            routines = routines.filter { $0.swimmerId == pre.id }
        }
        assignedGoals = goals
        assignedRoutines = routines
    }

    private func assignGoal() async {
        guard let coachId = auth.currentUser?.id, !swimmerId.isEmpty else { return }
        let m = Int(minutes) ?? 0, s = Int(seconds) ?? 0
        guard m > 0 || s > 0 else { status = "Enter a target time"; return }
        do {
            try await APIClient.shared.assignGoal(coachId: coachId, swimmerId: swimmerId, stroke: stroke, distance: distance, targetMinutes: m, targetSeconds: s)
            minutes = ""; seconds = ""; status = "Goal assigned"
            await loadAssigned()
        } catch { status = (error as? APIError)?.errorDescription ?? error.localizedDescription }
    }

    private func assignRoutine() async {
        guard let coachId = auth.currentUser?.id, !swimmerId.isEmpty, !title.isEmpty else { return }
        do {
            try await APIClient.shared.assignRoutine(coachId: coachId, swimmerId: swimmerId, title: title, details: details.isEmpty ? nil : details)
            title = ""; details = ""; status = "Routine assigned"
            await loadAssigned()
        } catch { status = (error as? APIError)?.errorDescription ?? error.localizedDescription }
    }
}
