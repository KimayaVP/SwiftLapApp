//
//  CoachRecommendView.swift
//  SwiftLap (iOS)
//
//  Pick recipients by batch (or Individuals) via a checkbox popup, then send a
//  meet recommendation. Sent recommendations are listed below and are editable.
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
    @State private var picking: RecipientGroup?
    @State private var sent: [MeetRecommendation] = []
    @State private var editing: MeetRecommendation?

    var body: some View {
        List {
            Section {
                ForEach(recipientGroups) { g in
                    Button { picking = g } label: {
                        HStack {
                            Image(systemName: g.isIndividuals ? "person" : "person.3.fill")
                                .foregroundStyle(Theme.teal)
                            Text(g.title).foregroundStyle(Theme.navy)
                            Spacer()
                            let n = selectedCount(in: g)
                            if n > 0 {
                                Text("\(n)").font(.caption.weight(.bold)).foregroundStyle(.white)
                                    .padding(.horizontal, 8).padding(.vertical, 2)
                                    .background(Capsule().fill(Theme.teal))
                            }
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Recipients")
            } footer: {
                if selectedIds.isEmpty {
                    Text("Tap a group to pick swimmers.")
                } else {
                    Text("\(selectedIds.count) swimmer\(selectedIds.count == 1 ? "" : "s") selected")
                        .foregroundStyle(Theme.teal)
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
                    if sending { ProgressView().tint(.white) } else { Text("Send Recommendation") }
                }
                .buttonStyle(.brandPrimary)
                .disabled(selectedIds.isEmpty || meetName.isEmpty || sending)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                if let status { Text(status).font(.caption).foregroundStyle(.green) }
            }

            if !sent.isEmpty {
                Section("Sent Recommendations") {
                    ForEach(sent) { r in
                        Button { editing = r } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("🏁 \(r.meetName)").font(.subheadline.weight(.medium)).foregroundStyle(Theme.navy)
                                    Text("To \(r.swimmerName ?? "swimmer")\(r.meetDate.map { " · \($0)" } ?? "")")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                statusPill(r.status)
                                Image(systemName: "pencil").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("Recommend Meet")
        .sheet(item: $picking) { g in
            RecipientPickerSheet(title: g.title, options: swimmersIn(g), selected: $selectedIds)
        }
        .sheet(item: $editing, onDismiss: { Task { await loadSent() } }) { r in
            EditRecommendationSheet(rec: r)
        }
        .task { await load() }
    }

    // MARK: groups

    private var recipientGroups: [RecipientGroup] {
        var groups = batches.map { RecipientGroup(title: $0.batch.name, swimmerIds: $0.memberIds, isIndividuals: false) }
        let inAny = Set(batches.flatMap { $0.memberIds })
        let individuals = swimmers.filter { !inAny.contains($0.id) }.map { $0.id }
        groups.append(RecipientGroup(title: "Individuals", swimmerIds: individuals, isIndividuals: true))
        return groups
    }

    private func swimmersIn(_ g: RecipientGroup) -> [CoachSwimmer] {
        let ids = Set(g.swimmerIds)
        return swimmers.filter { ids.contains($0.id) }
    }

    private func selectedCount(in g: RecipientGroup) -> Int {
        g.swimmerIds.filter { selectedIds.contains($0) }.count
    }

    @ViewBuilder
    private func statusPill(_ status: String?) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case "accepted": return ("Accepted", .green)
            case "declined": return ("Declined", Theme.coral)
            default: return ("Pending", .secondary)
            }
        }()
        Text(text).font(.caption2.weight(.semibold)).foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.15)))
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
        await loadSent()
    }

    private func loadSent() async {
        guard let id = auth.currentUser?.id else { return }
        sent = (try? await APIClient.shared.sentRecommendations(coachId: id)) ?? []
    }

    private func send() async {
        guard let id = auth.currentUser?.id else { return }
        sending = true; status = nil
        do {
            try await APIClient.shared.recommendMeet(coachId: id, swimmerIds: Array(selectedIds), meetName: meetName, meetDate: isoDateString(date), note: note.isEmpty ? nil : note)
            status = "Recommendation sent to \(selectedIds.count) swimmer\(selectedIds.count == 1 ? "" : "s")!"
            meetName = ""; note = ""; selectedIds = []
            await loadSent()
        } catch {
            status = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
        sending = false
    }
}

struct RecipientGroup: Identifiable {
    var id: String { title }
    let title: String
    let swimmerIds: [String]
    let isIndividuals: Bool
}

// MARK: - Checkbox popup

private struct RecipientPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let options: [CoachSwimmer]
    @Binding var selected: Set<String>

    var body: some View {
        NavigationStack {
            List {
                if options.isEmpty {
                    Text("No swimmers here yet.").foregroundStyle(.secondary)
                } else {
                    Button(allSelected ? "Deselect all" : "Select all") { toggleAll() }
                        .font(.caption.weight(.semibold))
                    ForEach(options) { s in
                        Button { toggle(s.id) } label: {
                            HStack {
                                Image(systemName: selected.contains(s.id) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(selected.contains(s.id) ? Theme.teal : .secondary)
                                Text(s.name).foregroundStyle(Theme.navy)
                                Spacer()
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var allSelected: Bool { !options.isEmpty && options.allSatisfy { selected.contains($0.id) } }
    private func toggle(_ id: String) { if selected.contains(id) { selected.remove(id) } else { selected.insert(id) } }
    private func toggleAll() {
        if allSelected { options.forEach { selected.remove($0.id) } }
        else { options.forEach { selected.insert($0.id) } }
    }
}

// MARK: - Edit a sent recommendation

private struct EditRecommendationSheet: View {
    @Environment(\.dismiss) var dismiss
    let rec: MeetRecommendation

    @State private var meetName: String
    @State private var hasDate: Bool
    @State private var date: Date
    @State private var note: String
    @State private var saving = false
    @State private var errorText: String?

    init(rec: MeetRecommendation) {
        self.rec = rec
        _meetName = State(initialValue: rec.meetName)
        let parsed = rec.meetDate.flatMap { Self.parse($0) }
        _hasDate = State(initialValue: parsed != nil)
        _date = State(initialValue: parsed ?? Date())
        _note = State(initialValue: rec.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recommendation") {
                    TextField("Meet / Race name", text: $meetName)
                    Toggle("Has a date", isOn: $hasDate)
                    if hasDate {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                    }
                    TextField("Note (optional)", text: $note, axis: .vertical)
                }
                if let swimmer = rec.swimmerName {
                    Section { Text("Sent to \(swimmer)").font(.caption).foregroundStyle(.secondary) }
                }
                Section {
                    Button("Withdraw Recommendation", role: .destructive) { Task { await withdraw() } }
                }
                if let errorText { Section { Text(errorText).foregroundStyle(Theme.coral).font(.caption) } }
            }
            .navigationTitle("Edit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: { if saving { ProgressView() } else { Text("Save") } }
                    .disabled(meetName.isEmpty || saving)
                }
            }
        }
    }

    private func save() async {
        saving = true; errorText = nil
        do {
            try await APIClient.shared.updateRecommendation(
                recommendationId: rec.id,
                meetName: meetName,
                meetDate: hasDate ? isoDateString(date) : nil,
                note: note.isEmpty ? nil : note)
            dismiss()
        } catch { errorText = (error as? APIError)?.errorDescription ?? error.localizedDescription }
        saving = false
    }

    private func withdraw() async {
        saving = true; errorText = nil
        do { try await APIClient.shared.deleteRecommendation(recommendationId: rec.id); dismiss() }
        catch { errorText = (error as? APIError)?.errorDescription ?? error.localizedDescription }
        saving = false
    }

    private static func parse(_ s: String) -> Date? {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.date(from: s)
    }
}

func isoDateString(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f.string(from: date)
}
