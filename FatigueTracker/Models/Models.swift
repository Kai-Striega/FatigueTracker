import Foundation
import SwiftData

/// Lifecycle state of a fatigue entry.
enum EntryStatus: String, Codable, CaseIterable {
    /// Notification scheduled, not yet responded to
    case pending
    /// User responded within the timeout window
    case responded
    /// Timeout passed with no response
    case missed
    /// User logged this off-cycle (not tied to a notification)
    case manual
}

@Model
final class FatigueEntry {
    /// Stable ID tying back to the scheduled notification (or a UUID for manual entries).
    /// Unique to prevent duplicate rows if scheduling runs twice.
    @Attribute(.unique) var promptID: String
    /// The scheduled prompt time, or the creation time for manual entries
    var scheduledAt: Date
    /// When the user actually responded (nil if pending or missed)
    var respondedAt: Date?
    /// 1–7 severity rating (nil if pending or missed). Mapped to functional zones
    /// via SeverityZone: 1–2 functioning, 3–5 pushing through, 6–7 not functioning.
    var severity: Int?
    /// Free-text activity description
    var activity: String
    /// Comma-joined list of category tag names. Stored as a single string for
    /// simplicity and easy CSV export. Empty string means no tags.
    var categoriesRaw: String
    /// Current lifecycle status, stored as raw string for SwiftData compatibility
    var statusRaw: String
    
    var status: EntryStatus {
        get { EntryStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
    
    /// Parsed list of category names. Trim and filter empties on read.
    var categories: [String] {
        get {
            categoriesRaw
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        set {
            categoriesRaw = newValue
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: ",")
        }
    }
    
    init(promptID: String,
         scheduledAt: Date,
         respondedAt: Date? = nil,
         severity: Int? = nil,
         activity: String = "",
         categories: [String] = [],
         status: EntryStatus = .pending) {
        self.promptID = promptID
        self.scheduledAt = scheduledAt
        self.respondedAt = respondedAt
        self.severity = severity
        self.activity = activity
        self.categoriesRaw = categories
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: ",")
        self.statusRaw = status.rawValue
    }
}

/// A user-managed category tag. Seeded with defaults on first run.
@Model
final class Tag {
    @Attribute(.unique) var name: String
    /// Display order in the picker
    var sortOrder: Int
    
    init(name: String, sortOrder: Int = 0) {
        self.name = name
        self.sortOrder = sortOrder
    }
    
    /// Default tags seeded on first run.
    static let defaults: [String] = [
        "physical", "cognitive", "social", "rest", "eating", "medical"
    ]
}

@Model
final class AppSettings {
    /// Minutes between prompts
    var intervalMinutes: Int
    /// Start of active window (hour 0–23)
    var activeStartHour: Int
    /// End of active window (hour 0–23, exclusive)
    var activeEndHour: Int
    /// Minutes after which an unanswered prompt is marked missed
    var missedTimeoutMinutes: Int
    
    init(intervalMinutes: Int = 60,
         activeStartHour: Int = 8,
         activeEndHour: Int = 22,
         missedTimeoutMinutes: Int = 20) {
        self.intervalMinutes = intervalMinutes
        self.activeStartHour = activeStartHour
        self.activeEndHour = activeEndHour
        self.missedTimeoutMinutes = missedTimeoutMinutes
    }
}
