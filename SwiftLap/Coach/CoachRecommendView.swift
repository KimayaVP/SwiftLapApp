//
//  CoachRecommendView.swift
//  SwiftLap (iOS)
//

import SwiftUI

struct CoachRecommendView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var swimmers: [CoachSwimmer] = []
    @State private var batches: [(batch: Batch, memberIds: [String])] = []
    @State private var selectedIds: Set<String> = []
    @State private var meetName = ""
    @State private var date = Date()
    @State private var note = ""
    @State private var sending = false
    @State private var status: String?

    var body: some View {
        List {
            if !batches.isEmpty {
                Section("Quick-pick a batch") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(batches, id: \.batch.id) { b in
                                Button(b.batch.name) { selectedIds = Set(b.memberIds) }
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(Capsule().fill(Color(.tertiarySystemFill)))
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            Section("Swimmers") {
                if swimmers.isEmpty {
                    Text("No swimmers yet").foregroundStyle(.secondary)
                } else {
                    ForEach(swimmers) { s in
                        Button { toggle(s.id) } label: {
                            HStack {
                                Image(systemName: selectedIds.contains(s.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selectedIds.contains(s.id) ? .cyan : .secondary)
                                Text(s.name).foregroundStyle(.primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            Section("Meet") {
                TextField("Meet / Race name", text: $meetName)
                DatePicker("Date (optional)", selection: $date, displayedComponents: .date)
                TextField("Note (optional)", text: $note, axis: .vertical)
            }
            Section {
                Button {
                    Task { await send() }
                } label: {
                    if sending { ProgressView() } else { Text("Send Recommendation") }
                }
                .disabled(selectedIds.isEmpty || meetName.isEmpty || sending)
                if let status { Text(status).font(.caption).foregroundStyle(.green) }
            }
        }
        .navigationTitle("Recommend Meet")
        .task { await load() }
    }

    private func toggle(_ id: String) {
        if selectedIds.contains(id) { selectedIds.remove(id) } else { selectedIds.insert(id) }
    }

    private func load() async {
        guard let id = auth.currentUser?.id else { return }
        swimmers = (try? await APIClient.shared.coachDashboard(coachId: id))?.swimmers ?? []
        let bs = (try? await APIClient.shared.fetchBatches(coachId: id)) ?? []
        var result: [(Batch, [String])] = []
        for b in bs {
            let members = (try? await APIClient.shared.batchLeaderboard(batchId: b.id)) ?? []
            result.append((b, members.map { $0.id }))
        }
        batches = result
    }

    private func send() async {
        guard let id = auth.currentUser?.id else { return }
        sending = true; status = nil
        do {
            try await APIClient.shared.recommendMeet(coachId: id, swimmerIds: Array(selectedIds), meetName: meetName, meetDate: isoDateString(date), note: note.isEmpty ? nil : note)
            status = "Recommendation sent to \(selectedIds.count) swimmer\(selectedIds.count == 1 ? "" : "s")!"
            meetName = ""; note = ""; selectedIds = []
        } catch {
            status = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        sending = false
    }
}

func isoDateString(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
}
