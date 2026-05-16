import SwiftUI
import SwiftData

/// What the form is editing. Drives lookup behavior and save semantics.
enum EntryFormMode: Equatable {
    case manual
    case editing(promptID: String)
}

struct EntryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let mode: EntryFormMode

    @State private var severity: Int = 4
    @State private var activity: String = ""
    @State private var scheduledAt: Date = Date()
    @State private var exertionType: ExertionType = .physical
    @State private var loadedEntry: FatigueEntry?

    /// Recent distinct activity strings for the suggestion strip.
    @Query(
        sort: \FatigueEntry.scheduledAt,
        order: .reverse
    ) private var recentEntries: [FatigueEntry]

    var body: some View {
        NavigationStack {
            Form {
                dateSection
                anchorSection
                severitySection
                exertionSection
                activitySection
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear {
                loadInitialState()
            }
        }
    }

    // MARK: - Sections

    private var dateSection: some View {
        Section("When did this happen?") {
            DatePicker(
                "When",
                selection: $scheduledAt,
                in: ...Date(),
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
        }
    }

    /// Shows the most recent entry as an anchor for the rating.
    /// Skips if no prior anchor exists or if the previous entry is the one being edited.
    @ViewBuilder
    private var anchorSection: some View {
        if let anchor = anchorEntry {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    SeverityBadge(severity: anchor.severity)
                        .scaleEffect(0.85)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last entry — \(relativeTimeString(from: anchor.scheduledAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !anchor.activity.isEmpty {
                            Text(anchor.activity)
                                .font(.subheadline)
                                .lineLimit(2)
                        }
                    }
                }
            } header: {
                Text("For reference")
            }
        }
    }

    private var severitySection: some View {
        Section("How are you doing?") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text(SeverityZone.from(severity: severity).fullLabel)
                        .font(.headline)
                        .foregroundStyle(SeverityZone.from(severity: severity).color)
                    Spacer()
                    Text("\(severity)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }

                Slider(
                    value: Binding(
                        get: { Double(severity) },
                        set: { severity = Int($0.rounded()) }
                    ),
                    in: 1...7,
                    step: 1
                )
                .tint(SeverityZone.from(severity: severity).color)

                ZoneKeywordStrip(currentZone: SeverityZone.from(severity: severity))
            }
            .padding(.vertical, 4)
        }
    }

    private var exertionSection: some View {
        Section("Type of exertion") {
            Picker("Exertion", selection: $exertionType) {
                ForEach(ExertionType.allCases, id: \.self) { type in
                    Label(type.label, systemImage: type.symbolName).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var activitySection: some View {
        Section("What were you doing?") {
            TextField("e.g. walked to kitchen, read for 20 min",
                       text: $activity, axis: .vertical)
                .lineLimit(3...6)

            if !recentActivitySuggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(recentActivitySuggestions, id: \.self) { suggestion in
                            Button {
                                activity = suggestion
                            } label: {
                                Text(suggestion)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color.secondary.opacity(0.15),
                                                in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
            }
        }
    }

    // MARK: - Computed

    private var title: String {
        switch mode {
        case .manual: return "Quick Log"
        case .editing: return "Edit Entry"
        }
    }

    /// The most recent entry strictly before `scheduledAt`, skipping the one being edited.
    private var anchorEntry: FatigueEntry? {
        recentEntries.first { entry in
            guard entry.scheduledAt < scheduledAt else { return false }
            if case .editing(let editingID) = mode {
                return entry.promptID != editingID
            }
            return true
        }
    }

    /// Up to 10 distinct recent activity strings, ordered by recency.
    private var recentActivitySuggestions: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for entry in recentEntries {
            let trimmed = entry.activity.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if seen.insert(key).inserted {
                result.append(trimmed)
                if result.count >= 10 { break }
            }
        }
        return result
    }

    // MARK: - Actions

    private func loadInitialState() {
        let defaultSeverity = recentEntries.first?.severity ?? 4
        let defaultExertion = recentEntries.first?.exertionType ?? .physical

        switch mode {
        case .manual:
            severity = defaultSeverity
            activity = ""
            scheduledAt = Date()
            exertionType = defaultExertion

        case .editing(let promptID):
            let descriptor = FetchDescriptor<FatigueEntry>(
                predicate: #Predicate { $0.promptID == promptID }
            )
            if let entry = (try? modelContext.fetch(descriptor))?.first {
                loadedEntry = entry
                severity = entry.severity ?? defaultSeverity
                activity = entry.activity
                scheduledAt = entry.scheduledAt
                exertionType = entry.exertionType ?? defaultExertion
            }
        }
    }

    private func save() {
        let now = Date()

        switch mode {
        case .manual:
            let entry = FatigueEntry(
                promptID: UUID().uuidString,
                scheduledAt: scheduledAt,
                respondedAt: now,
                severity: severity,
                activity: activity,
                status: .manual,
                exertionType: exertionType
            )
            modelContext.insert(entry)

        case .editing:
            if let existing = loadedEntry {
                existing.severity = severity
                existing.activity = activity
                existing.scheduledAt = scheduledAt
                existing.exertionType = exertionType
            }
        }

        try? modelContext.save()
        dismiss()
    }

    // MARK: - Formatting

    private func relativeTimeString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Subviews

/// Strip of zone keywords shown beneath the severity slider.
/// Each label is highlighted when the slider is in its zone.
/// Widths are proportional to the integer range each zone covers (2/3/2 of 7).
struct ZoneKeywordStrip: View {
    let currentZone: SeverityZone

    var body: some View {
        HStack(spacing: 4) {
            label(for: .functioning, weight: 2)
            label(for: .pushing, weight: 3)
            label(for: .stopped, weight: 2)
        }
        .font(.caption2)
    }

    @ViewBuilder
    private func label(for zone: SeverityZone, weight: CGFloat) -> some View {
        let isActive = zone == currentZone
        Text(zone.shortLabel)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .foregroundStyle(isActive ? zone.color : Color.secondary)
            .fontWeight(isActive ? .semibold : .regular)
            .layoutPriority(weight)
    }
}
