//
//  TrainingView.swift
//  SwiftLap (iOS)
//

import SwiftUI

struct TrainingView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var response: APIClient.TrainingPlanResponse?
    @State private var routines: [CoachRoutine] = []
    @State private var loading = true

    var body: some View {
        List {
            if !routines.isEmpty {
                Section("Coach Routines") {
                    ForEach(routines) { r in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("📋 \(r.title)").font(.subheadline.weight(.semibold))
                                Text("👨‍🏫 Coach").font(.caption2).foregroundStyle(.purple)
                            }
                            if let from = r.coachName { Text("From \(from)").font(.caption2).foregroundStyle(.secondary) }
                            if let d = r.details, !d.isEmpty { Text(d).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }

            if loading {
                ProgressView()
            } else if let resp = response {
                if !resp.ready {
                    Section("This Week") {
                        Label(resp.missing?.goals == true ? "Set a goal" : "Goal set ✓", systemImage: resp.missing?.goals == true ? "circle" : "checkmark.circle.fill")
                        Label(resp.missing?.times == true ? "Log a time" : "Time logged ✓", systemImage: resp.missing?.times == true ? "circle" : "checkmark.circle.fill")
                        Text("Complete these to unlock your training plan.").font(.caption).foregroundStyle(.secondary)
                    }
                } else if let plan = resp.plan {
                    Section(plan.weekFocus ?? "This Week") {
                        if let intensity = plan.intensity {
                            Text("Intensity: \(intensity.uppercased())").font(.caption.weight(.semibold)).foregroundStyle(Theme.teal)
                        }
                        if let areas = plan.focusAreas, !areas.isEmpty {
                            Text(areas.joined(separator: " · ")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    ForEach(plan.workouts ?? []) { w in
                        Section("\(w.day)\(w.type.map { " · \($0)" } ?? "")") {
                            if let warmup = w.warmup { labeled("Warm-up", warmup) }
                            ForEach(w.main ?? []) { m in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(m.set).font(.subheadline)
                                    if let rest = m.rest, let focus = m.focus {
                                        Text("Rest \(rest) · \(focus)").font(.caption2).foregroundStyle(.secondary)
                                    }
                                }
                            }
                            if let cooldown = w.cooldown { labeled("Cool-down", cooldown) }
                        }
                    }
                    if let tips = plan.tips, !tips.isEmpty {
                        Section("Tips") {
                            ForEach(tips, id: \.self) { Text("• \($0)").font(.caption) }
                        }
                    }
                }
            }
        }
        .navigationTitle("Training")
        .task { await load() }
    }

    private func labeled(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.subheadline)
        }
    }

    private func load() async {
        guard let id = auth.currentUser?.id else { return }
        loading = true
        routines = (try? await APIClient.shared.fetchCoachRoutines(swimmerId: id)) ?? []
        response = try? await APIClient.shared.fetchTrainingPlan(swimmerId: id)
        loading = false
    }
}
