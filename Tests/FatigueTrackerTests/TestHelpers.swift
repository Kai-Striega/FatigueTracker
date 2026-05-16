import Foundation
import SwiftData
@testable import FatigueTracker

enum TestHelpers {
    static func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: FatigueEntry.self, configurations: config)
    }

    @MainActor
    static func makeInMemoryContext() throws -> ModelContext {
        let container = try makeInMemoryContainer()
        return ModelContext(container)
    }

    static func makeEntry(
        promptID: String = UUID().uuidString,
        scheduledAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
        respondedAt: Date? = nil,
        severity: Int? = nil,
        activity: String = "",
        status: EntryStatus = .manual,
        exertionType: ExertionType? = nil
    ) -> FatigueEntry {
        FatigueEntry(
            promptID: promptID,
            scheduledAt: scheduledAt,
            respondedAt: respondedAt,
            severity: severity,
            activity: activity,
            status: status,
            exertionType: exertionType
        )
    }
}
