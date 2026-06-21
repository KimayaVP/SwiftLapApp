//
//  GoalsView.swift
//  SwiftLap (iOS)
//

import SwiftUI

struct GoalsView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var goals: [Goal] = []
    @State private var loading = true
    @State private var error: String?

    @State private var stroke = "Freestyle"
    @State private var distance = 50
    @State private var minutes = ""
    @State private var seconds = ""
    @State private var saving = false
    @State private var pendingDelete: Goal?

    var body: some View {
        List {
            Section("Your Goals") {
                if loading {
                    ProgressView()
                } else if goals.isEmpty {
                    Text("Set a goal to start").foregroundStyle(.secondary)
                } else {
                    ForEach(goals) { goal in
                        Button { Task { await setActive(goal) } } label: { goalRow(goal) }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) { pendingDelete = goal } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
            }

            Section("Set a Goal") {
                Picker("Stroke", selection: $stroke) {
                    ForEach(strokeOptions, id: \.self) { Text($0) }
                }
                .onChange(of: stroke) { _, newStroke in
                    if !distancesFor(newStroke).contains(distance) {
                        distance = distancesFor(newStroke).first ?? 50
                    }
                }
                Picker("Distance", selection: $distance) {
                    ForEach(distancesFor(stroke), id: \.self) { Text("\($0)m").tag($0) }
                }
                HStack {
                    TextField("Min", text: $minutes).keyboardType(.numberPad)
                    Text(":").foregroundStyle(.secondary)
                    TextField("Sec", text: $seconds).keyboardType(.numberPad)
                }
                Button {
                    Task { await save() }
                } label: {
                    if saving { ProgressView() } else { Text("Set Goal") }
                }
                .disabled(saving)
                if let error { Text(error).font(.caption).foregroundStyle(.red) }
            }
        }
        .navigationTitle("Goals")
        .task { await load() }
        .alert("Delete this goal?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let g = pendingDelete { Task { await delete(g) } }
            }
        } message: {
            Text("This removes the goal. You can set it again anytime.")
        }
    }

    private func delete(_ goal: Goal) async {
        do {
            try await APIClient.shared.deleteGoal(id: goal.id)
            pendingDelete = nil
            await load()
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
            pendingDelete = nil
        }
    }

    @ViewBuilder
    private func goalRow(_ goal: Goal) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("\(goal.stroke) \(goal.distance)m").font(.subheadline.weight(.medium))
                    if goal.source == "coach" {
                        Text("👨‍🏫 Coach").font(.caption2).foregroundStyle(.purple)
                    }
                    if goal.isActive == true {
                        Text("✓ Active").font(.caption2).foregroundStyle(.green)
                    }
                }
                Text("Target: \(formatLapTime(goal.targetSeconds))").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if goal.achieved == true {
                Text("✅ Achieved").font(.caption).foregroundStyle(.green)
            } else if let best = goal.bestTime {
                Text("\(formatLapTime(best)) best").font(.caption).foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private func load() async {
        guard let id = auth.currentUser?.id else { return }
        loading = true
        do { goals = try await APIClient.shared.fetchGoals(swimmerId: id) }
        catch { /* leave empty */ }
        loading = false
    }

    private func setActive(_ goal: Goal) async {
        guard let id = auth.currentUser?.id else { return }
        do { try await APIClient.shared.setActiveGoal(swimmerId: id, goalId: goal.id); await load() }
        catch { self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription }
    }

    private func save() async {
        guard let id = auth.currentUser?.id else { return }
        let m = Int(minutes) ?? 0
        let s = Int(seconds) ?? 0
        guard m > 0 || s > 0 else { error = "Enter a target time"; return }
        saving = true; error = nil
        do {
            try await APIClient.shared.setGoal(swimmerId: id, stroke: stroke, distance: distance, targetMinutes: m, targetSeconds: s)
            minutes = ""; seconds = ""
            await load()
        } catch {
            self.error = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        saving = false
    }
}
