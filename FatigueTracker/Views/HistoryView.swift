import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        sort: \FatigueEntry.scheduledAt,
        order: .reverse
    ) private var entries: [FatigueEntry]

    @State private var showingManualEntry = false
    @State private var editingPromptID: String?

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No entries yet",
                        systemImage: "list.bullet.clipboard",
                        description: Text("Use Quick Log to record one now.")
                    )
                } else {
                    List {
                        ForEach(entries) { entry in
                            Button {
                                editingPromptID = entry.promptID
                            } label: {
                                EntryRow(entry: entry)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("entry-row")
                        }
                        .onDelete(perform: deleteEntries)
                    }
                    .accessibilityIdentifier("entry-list")
                }
            }
            .navigationTitle("Fatigue Log")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingManualEntry = true
                    } label: {
                        Label("Quick Log", systemImage: "plus.circle.fill")
                    }
                    .accessibilityIdentifier("quick-log-button")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: FatigueLogCSV(entries: entries),
                        preview: SharePreview("Fatigue Log")
                    ) {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(entries.isEmpty)
                    .accessibilityIdentifier("export-csv-button")
                }
            }
            .sheet(isPresented: $showingManualEntry) {
                EntryFormView(mode: .manual)
            }
            .sheet(item: Binding(
                get: { editingPromptID.map { EditingID(promptID: $0) } },
                set: { editingPromptID = $0?.promptID }
            )) { editing in
                EntryFormView(mode: .editing(promptID: editing.promptID))
            }
        }
    }

    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(entries[index])
        }
        try? modelContext.save()
    }

}

private struct EditingID: Identifiable {
    let promptID: String
    var id: String { promptID }
}

struct EntryRow: View {
    let entry: FatigueEntry

    private var wasRetroactive: Bool {
        guard let responded = entry.respondedAt else { return false }
        return responded.timeIntervalSince(entry.scheduledAt) > 300
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SeverityBadge(severity: entry.severity)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(entry.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if wasRetroactive {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Logged retroactively")
                    }
                    if let exertion = entry.exertionType {
                        Image(systemName: exertion.symbolName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel(exertion.label)
                    }
                }

                if let s = entry.severity {
                    Text(SeverityZone.from(severity: s).fullLabel)
                        .font(.caption)
                        .foregroundStyle(SeverityZone.from(severity: s).color)
                }
                if entry.activity.isEmpty {
                    Text("(no activity recorded)")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(entry.activity)
                        .font(.body)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// Colors by zone (3 colors), with the numeric 1–7 value shown as the primary signal.
struct SeverityBadge: View {
    let severity: Int?

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 36, height: 36)
            Text(label)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private var label: String {
        if let s = severity { return "\(s)" }
        return "?"
    }

    private var color: Color {
        guard let s = severity else { return Color(white: 0.55) }
        return SeverityZone.from(severity: s).color
    }
}

