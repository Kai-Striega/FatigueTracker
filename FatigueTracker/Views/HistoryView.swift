import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<FatigueEntry> { $0.statusRaw != "pending" },
        sort: \FatigueEntry.scheduledAt,
        order: .reverse
    ) private var entries: [FatigueEntry]
    
    @State private var showingExport = false
    @State private var exportURL: URL?
    @State private var showingManualEntry = false
    @State private var editingPromptID: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No entries yet",
                        systemImage: "list.bullet.clipboard",
                        description: Text("Entries appear here once you respond to a prompt, or use Quick Log to record one now.")
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
                        }
                        .onDelete(perform: deleteEntries)
                    }
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
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        prepareExport()
                    } label: {
                        Label("Export CSV", systemImage: "square.and.arrow.up")
                    }
                    .disabled(entries.isEmpty)
                }
            }
            .sheet(isPresented: $showingExport) {
                if let url = exportURL {
                    ShareSheet(items: [url])
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
    
    private func prepareExport() {
        let csv = CSVExporter.makeCSV(entries: entries)
        let filename = "fatigue-log-\(Date().formatted(.iso8601.year().month().day())).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            exportURL = url
            showingExport = true
        } catch {
            print("Failed to write CSV: \(error)")
        }
    }
}

private struct EditingID: Identifiable {
    let promptID: String
    var id: String { promptID }
}

struct EntryRow: View {
    let entry: FatigueEntry
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SeverityBadge(severity: entry.severity, status: entry.status)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if entry.status == .manual {
                        Text("· manual")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                switch entry.status {
                case .missed:
                    Text("Missed")
                        .font(.body)
                        .italic()
                        .foregroundStyle(.secondary)
                case .pending:
                    Text("Pending…")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                case .responded, .manual:
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
                    if !entry.categories.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(entry.categories, id: \.self) { cat in
                                Text(cat)
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary.opacity(0.15),
                                                in: Capsule())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// Colors by zone (3 colors), with the numeric 1–7 value shown as the primary signal.
/// Per-zone coloring keeps the visual language tied to the functional meaning.
struct SeverityBadge: View {
    let severity: Int?
    let status: EntryStatus
    
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
        if status == .missed { return "–" }
        if let s = severity { return "\(s)" }
        return "?"
    }
    
    private var color: Color {
        if status == .missed { return Color(white: 0.55) }
        guard let s = severity else { return Color(white: 0.55) }
        return SeverityZone.from(severity: s).color
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
