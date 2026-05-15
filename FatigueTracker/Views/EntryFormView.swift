import SwiftUI
import SwiftData

/// What the form is editing. Drives lookup behavior and save semantics.
enum EntryFormMode: Equatable {
    case respondingToPrompt(PendingPrompt)
    case manual
    case editing(promptID: String)
}

struct EntryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var coordinator: NotificationCoordinator
    
    let mode: EntryFormMode
    
    @State private var severity: Int = 4
    @State private var activity: String = ""
    @State private var selectedCategories: Set<String> = []
    @State private var loadedEntry: FatigueEntry?
    
    /// All available tags, sorted. Re-fetched on appear.
    @Query(sort: \Tag.sortOrder) private var allTags: [Tag]
    
    /// Recent distinct activity strings for the suggestion strip.
    @Query(
        filter: #Predicate<FatigueEntry> {
            $0.statusRaw == "responded" || $0.statusRaw == "manual"
        },
        sort: \FatigueEntry.scheduledAt,
        order: .reverse
    ) private var recentEntries: [FatigueEntry]
    
    var body: some View {
        NavigationStack {
            Form {
                anchorSection
                severitySection
                activitySection
                categoriesSection
                
                if case .respondingToPrompt(let prompt) = mode {
                    Section {
                        Text("Prompt scheduled at \(prompt.scheduledAt.formatted(date: .omitted, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear {
                seedDefaultTagsIfNeeded()
                loadInitialState()
            }
        }
    }
    
    // MARK: - Sections
    
    /// Shows the most recent responded/manual entry as an anchor for the rating.
    /// Skips if no prior anchor exists or if the previous entry is the one being edited.
    @ViewBuilder
    private var anchorSection: some View {
        if let anchor = anchorEntry {
            Section {
                HStack(alignment: .top, spacing: 12) {
                    SeverityBadge(severity: anchor.severity, status: anchor.status)
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
                // Current zone label, large and bold, with the numeric value alongside.
                HStack(alignment: .firstTextBaseline) {
                    Text(SeverityZone.from(severity: severity).fullLabel)
                        .font(.headline)
                        .foregroundStyle(SeverityZone.from(severity: severity).color)
                    Spacer()
                    Text("\(severity)")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                
                // Slider snaps to integers 1...7.
                Slider(
                    value: Binding(
                        get: { Double(severity) },
                        set: { severity = Int($0.rounded()) }
                    ),
                    in: 1...7,
                    step: 1
                )
                .tint(SeverityZone.from(severity: severity).color)
                
                // Zone keyword strip beneath the slider.
                // Each label occupies roughly the proportion of the slider its zone covers.
                ZoneKeywordStrip(currentZone: SeverityZone.from(severity: severity))
            }
            .padding(.vertical, 4)
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
    
    private var categoriesSection: some View {
        Section {
            FlowLayout(spacing: 8) {
                ForEach(allTags) { tag in
                    CategoryChip(
                        name: tag.name,
                        isSelected: selectedCategories.contains(tag.name)
                    ) {
                        toggleCategory(tag.name)
                    }
                }
                CategoryChip(name: "+ Add", isSelected: false, isAddButton: true) {
                    promptForNewTag()
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Categories (optional)")
        } footer: {
            Text("Tap to tag this entry. Tags help group activities for analysis later.")
                .font(.caption)
        }
    }
    
    // MARK: - Computed
    
    private var title: String {
        switch mode {
        case .respondingToPrompt: return "Log Entry"
        case .manual: return "Quick Log"
        case .editing: return "Edit Entry"
        }
    }
    
    /// The most recent responded/manual entry that isn't the one being edited.
    private var anchorEntry: FatigueEntry? {
        recentEntries.first { entry in
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
    
    private func toggleCategory(_ name: String) {
        if selectedCategories.contains(name) {
            selectedCategories.remove(name)
        } else {
            selectedCategories.insert(name)
        }
    }
    
    /// Use a UIAlertController for the tag-name prompt because SwiftUI's
    /// alert text-field support is awkward and we want this to feel snappy.
    private func promptForNewTag() {
        let alert = UIAlertController(title: "New category",
                                       message: "Name a tag (e.g. 'household', 'work')",
                                       preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "tag name"
            field.autocapitalizationType = .none
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { _ in
            guard let raw = alert.textFields?.first?.text else { return }
            let name = raw.trimmingCharacters(in: .whitespaces).lowercased()
            guard !name.isEmpty else { return }
            // Avoid duplicate insertions
            if !allTags.contains(where: { $0.name == name }) {
                let nextOrder = (allTags.map(\.sortOrder).max() ?? 0) + 1
                modelContext.insert(Tag(name: name, sortOrder: nextOrder))
                try? modelContext.save()
            }
            selectedCategories.insert(name)
        })
        
        // Present from the active key window
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first(where: \.isKeyWindow)?.rootViewController {
            var top = root
            while let presented = top.presentedViewController { top = presented }
            top.present(alert, animated: true)
        }
    }
    
    private func seedDefaultTagsIfNeeded() {
        guard allTags.isEmpty else { return }
        for (index, name) in Tag.defaults.enumerated() {
            modelContext.insert(Tag(name: name, sortOrder: index))
        }
        try? modelContext.save()
    }
    
    private func loadInitialState() {
        // Default starting severity: last responded/manual entry, or 4 (middle of slider) if none.
        let defaultSeverity = recentEntries.first?.severity ?? 4
        
        switch mode {
        case .respondingToPrompt(let prompt):
            severity = prompt.preFilledSeverity ?? defaultSeverity
            let id = prompt.promptID
            let descriptor = FetchDescriptor<FatigueEntry>(
                predicate: #Predicate { $0.promptID == id }
            )
            loadedEntry = (try? modelContext.fetch(descriptor))?.first
            if let existing = loadedEntry, existing.status == .responded {
                severity = existing.severity ?? severity
                activity = existing.activity
                selectedCategories = Set(existing.categories)
            }
            
        case .manual:
            severity = defaultSeverity
            activity = ""
            selectedCategories = []
            
        case .editing(let promptID):
            let descriptor = FetchDescriptor<FatigueEntry>(
                predicate: #Predicate { $0.promptID == promptID }
            )
            if let entry = (try? modelContext.fetch(descriptor))?.first {
                loadedEntry = entry
                severity = entry.severity ?? defaultSeverity
                activity = entry.activity
                selectedCategories = Set(entry.categories)
            }
        }
    }
    
    private func save() {
        let now = Date()
        let categoriesList = Array(selectedCategories).sorted()
        
        switch mode {
        case .respondingToPrompt:
            if let existing = loadedEntry {
                existing.severity = severity
                existing.activity = activity
                existing.categories = categoriesList
                existing.respondedAt = now
                existing.status = .responded
            } else if case .respondingToPrompt(let prompt) = mode {
                let entry = FatigueEntry(
                    promptID: prompt.promptID,
                    scheduledAt: prompt.scheduledAt,
                    respondedAt: now,
                    severity: severity,
                    activity: activity,
                    categories: categoriesList,
                    status: .responded
                )
                modelContext.insert(entry)
            }
            
        case .manual:
            let entry = FatigueEntry(
                promptID: UUID().uuidString,
                scheduledAt: now,
                respondedAt: now,
                severity: severity,
                activity: activity,
                categories: categoriesList,
                status: .manual
            )
            modelContext.insert(entry)
            
        case .editing:
            if let existing = loadedEntry {
                existing.severity = severity
                existing.activity = activity
                existing.categories = categoriesList
                if existing.status == .missed {
                    existing.status = .responded
                    existing.respondedAt = now
                }
            }
        }
        
        try? modelContext.save()
        coordinator.pendingPrompt = nil
        dismiss()
    }
    
    private func cancel() {
        coordinator.pendingPrompt = nil
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

struct CategoryChip: View {
    let name: String
    let isSelected: Bool
    var isAddButton: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(name)
                .font(.subheadline)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(background, in: Capsule())
                .foregroundStyle(foreground)
                .overlay(
                    Capsule().stroke(strokeColor, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
    
    private var background: Color {
        if isAddButton { return Color.clear }
        return isSelected ? Color.accentColor : Color.secondary.opacity(0.12)
    }
    
    private var foreground: Color {
        if isAddButton { return Color.accentColor }
        return isSelected ? Color.white : Color.primary
    }
    
    private var strokeColor: Color {
        if isAddButton { return Color.accentColor.opacity(0.5) }
        return Color.clear
    }
}

/// Minimal flow layout (wraps chips onto multiple lines).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth {
                totalWidth = max(totalWidth, rowWidth - spacing)
                totalHeight += rowHeight + spacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalWidth = max(totalWidth, rowWidth - spacing)
        totalHeight += rowHeight
        return CGSize(width: totalWidth, height: totalHeight)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
