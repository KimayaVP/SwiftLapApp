//
//  CoachOverviewView.swift
//  SwiftLap (iOS)
//

import SwiftUI

struct CoachOverviewView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var swimmers: [CoachSwimmer] = []
    @State private var batches: [(batch: Batch, memberIds: [String])] = []
    @State private var filter = "all"          // "all" | batchId | "individuals"
    @State private var loading = true
    @State private var drill: CategoryDrill?   // tapped stat box → swimmer list

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        List {
            Section("Filter by batch") {
                Menu {
                    Picker("Batch", selection: $filter) {
                        Text("All swimmers").tag("all")
                        ForEach(batches, id: \.batch.id) { b in Text(b.batch.name).tag(b.batch.id) }
                        Text("Individuals").tag("individuals")
                    }
                } label: {
                    HStack {
                        Text(filterLabel).foregroundStyle(Theme.navy)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                let f = filtered()
                LazyVGrid(columns: columns, spacing: 12) {
                    statBox("Total", "Total", f, Theme.navy)
                    statBox("On Track", "ahead", f.filter { $0.status == "ahead" }, .green)
                    statBox("Behind", "behind", f.filter { $0.status == "behind" }, Theme.coral)
                    statBox("No Goals", "no_goals", f.filter { $0.status == "no_goals" }, .secondary)
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Tap a box to see those swimmers.")
            }
            if loading { ProgressView() }
        }
        .navigationTitle("Team Overview")
        .sheet(item: $drill) { d in
            CategorySwimmersSheet(title: d.title, swimmers: d.swimmers)
                .environmentObject(auth)
        }
        .task { await load() }
    }

    private var filterLabel: String {
        switch filter {
        case "all": return "All swimmers"
        case "individuals": return "Individuals"
        default: return batches.first { $0.batch.id == filter }?.batch.name ?? "All swimmers"
        }
    }

    private func statBox(_ label: String, _ key: String, _ list: [CoachSwimmer], _ color: Color) -> some View {
        Button {
            drill = CategoryDrill(title: label, swimmers: list)
        } label: {
            VStack(spacing: 4) {
                Text("\(list.count)").font(.system(size: 30, weight: .bold)).foregroundStyle(color)
                Text(label).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(color.opacity(0.18), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func filtered() -> [CoachSwimmer] {
        switch filter {
        case "all": return swimmers
        case "individuals":
            let inAny = Set(batches.flatMap { $0.memberIds })
            return swimmers.filter { !inAny.contains($0.id) }
        default:
            let ids = Set(batches.first { $0.batch.id == filter }?.memberIds ?? [])
            return swimmers.filter { ids.contains($0.id) }
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

struct CategoryDrill: Identifiable {
    let id = UUID()
    let title: String
    let swimmers: [CoachSwimmer]
}

private struct CategorySwimmersSheet: View {
    @EnvironmentObject var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    let title: String
    let swimmers: [CoachSwimmer]

    var body: some View {
        NavigationStack {
            List {
                if swimmers.isEmpty {
                    Text("No swimmers in this category.").foregroundStyle(.secondary)
                } else {
                    ForEach(swimmers) { s in
                        NavigationLink { CoachSwimmerView(swimmer: s).environmentObject(auth) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(s.name).font(.subheadline.weight(.medium))
                                    Text("Goals \(s.goalsAhead ?? 0)/\(s.goalsCount ?? 0) · 🔥 \(s.streak ?? 0)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(statusIcon(s.status))
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }

    private func statusIcon(_ status: String) -> String {
        switch status { case "ahead": return "✅"; case "behind": return "🔻"; default: return "—" }
    }
}
