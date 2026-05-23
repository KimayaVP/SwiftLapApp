//
//  CoachOverviewView.swift
//  SwiftLap (iOS)
//

import SwiftUI

struct CoachOverviewView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var swimmers: [CoachSwimmer] = []
    @State private var batches: [(batch: Batch, memberIds: [String])] = []
    @State private var selected: Set<String> = []   // batch ids + "individuals"; empty = all
    @State private var loading = true

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        List {
            Section("Filter by batch") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        chip("All", id: "all")
                        ForEach(batches, id: \.batch.id) { b in chip(b.batch.name, id: b.batch.id) }
                        chip("Individuals", id: "individuals")
                    }
                    .padding(.vertical, 2)
                }
            }
            Section {
                let f = filtered()
                LazyVGrid(columns: columns, spacing: 12) {
                    statBox("Total", f.count, .primary)
                    statBox("On Track", f.filter { $0.status == "ahead" }.count, .green)
                    statBox("Behind", f.filter { $0.status == "behind" }.count, .red)
                    statBox("No Goals", f.filter { $0.status == "no_goals" }.count, .secondary)
                }
                .padding(.vertical, 4)
            }
            if loading { ProgressView() }
        }
        .navigationTitle("Team Overview")
        .task { await load() }
    }

    private func chip(_ title: String, id: String) -> some View {
        let isActive = id == "all" ? selected.isEmpty : selected.contains(id)
        return Button {
            if id == "all" { selected.removeAll() }
            else if selected.contains(id) { selected.remove(id) }
            else { selected.insert(id) }
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(isActive ? Color.cyan : Color(.tertiarySystemFill)))
                .foregroundStyle(isActive ? .white : .primary)
        }
        .buttonStyle(.plain)
    }

    private func statBox(_ label: String, _ value: Int, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(value)").font(.system(size: 30, weight: .bold)).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }

    private func filtered() -> [CoachSwimmer] {
        guard !selected.isEmpty else { return swimmers }
        let inAnyBatch = Set(batches.flatMap { $0.memberIds })
        return swimmers.filter { s in
            let inSelectedBatch = batches.contains { selected.contains($0.batch.id) && $0.memberIds.contains(s.id) }
            let isIndividual = selected.contains("individuals") && !inAnyBatch.contains(s.id)
            return inSelectedBatch || isIndividual
        }
    }

    private func load() async {
        guard let id = auth.currentUser?.id else { return }
        loading = true
        let dash = try? await APIClient.shared.coachDashboard(coachId: id)
        swimmers = dash?.swimmers ?? []
        let bs = (try? await APIClient.shared.fetchBatches(coachId: id)) ?? []
        var result: [(Batch, [String])] = []
        for b in bs {
            let members = (try? await APIClient.shared.batchLeaderboard(batchId: b.id)) ?? []
            result.append((b, members.map { $0.id }))
        }
        batches = result
        loading = false
    }
}
