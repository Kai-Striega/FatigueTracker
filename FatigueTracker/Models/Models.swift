import Foundation
import SwiftData

/// Lifecycle state of a fatigue entry.
enum EntryStatus: String, Codable, CaseIterable {
    /// User responded within the timeout window
    case responded
    /// User logged this off-cycle (not tied to a notification)
    case manual
}

@Model
final class FatigueEntry {
    /// Stable ID — a UUID for manual entries.
    /// Unique to prevent duplicate rows.
    @Attribute(.unique) var promptID: String
    /// The scheduled prompt time, or the creation time for manual entries
    var scheduledAt: Date
    /// When the user actually responded
    var respondedAt: Date?
    /// 1–7 severity rating. Mapped to functional zones via SeverityZone:
    /// 1–2 functioning, 3–5 pushing through, 6–7 not functioning.
    var severity: Int?
    /// Free-text activity description
    var activity: String
    /// Current lifecycle status, stored as raw string for SwiftData compatibility
    var statusRaw: String
    /// Type of exertion (physical vs cognitive), stored as raw string.
    /// Optional so legacy entries created before this field continue to load.
    var exertionTypeRaw: String?

    var status: EntryStatus {
        get { EntryStatus(rawValue: statusRaw) ?? .manual }
        set { statusRaw = newValue.rawValue }
    }

    var exertionType: ExertionType? {
        get { exertionTypeRaw.flatMap(ExertionType.init(rawValue:)) }
        set { exertionTypeRaw = newValue?.rawValue }
    }

    init(promptID: String,
         scheduledAt: Date,
         respondedAt: Date? = nil,
         severity: Int? = nil,
         activity: String = "",
         status: EntryStatus = .manual,
         exertionType: ExertionType? = nil) {
        self.promptID = promptID
        self.scheduledAt = scheduledAt
        self.respondedAt = respondedAt
        self.severity = severity
        self.activity = activity
        self.statusRaw = status.rawValue
        self.exertionTypeRaw = exertionType?.rawValue
    }
}
