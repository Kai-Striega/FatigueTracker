import Foundation
import SwiftData
import Testing
@testable import FatigueTracker

@Suite("FatigueEntry model")
@MainActor
struct FatigueEntryModelTests {
    @Test func insertAndFetchRoundTripPreservesFields() throws {
        let context = try TestHelpers.makeInMemoryContext()
        let scheduled = Date(timeIntervalSince1970: 1_700_000_000)
        let responded = Date(timeIntervalSince1970: 1_700_000_300)

        let entry = TestHelpers.makeEntry(
            promptID: "round-trip",
            scheduledAt: scheduled,
            respondedAt: responded,
            severity: 5,
            activity: "coding session",
            status: .responded,
            exertionType: .cognitive
        )
        context.insert(entry)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<FatigueEntry>())
        #expect(fetched.count == 1)
        let result = try #require(fetched.first)
        #expect(result.promptID == "round-trip")
        #expect(result.scheduledAt == scheduled)
        #expect(result.respondedAt == responded)
        #expect(result.severity == 5)
        #expect(result.activity == "coding session")
        #expect(result.status == .responded)
        #expect(result.exertionType == .cognitive)
    }

    @Test func optionalFieldsRoundTripAsNil() throws {
        let context = try TestHelpers.makeInMemoryContext()
        let entry = TestHelpers.makeEntry(
            promptID: "nil-fields",
            severity: nil,
            activity: "",
            status: .manual,
            exertionType: nil
        )
        context.insert(entry)
        try context.save()

        let result = try #require(try context.fetch(FetchDescriptor<FatigueEntry>()).first)
        #expect(result.respondedAt == nil)
        #expect(result.severity == nil)
        #expect(result.exertionType == nil)
        #expect(result.exertionTypeRaw == nil)
    }

    @Test func deletingRemovesEntryFromSubsequentFetches() throws {
        let context = try TestHelpers.makeInMemoryContext()
        let entry = TestHelpers.makeEntry(promptID: "to-delete")
        context.insert(entry)
        try context.save()

        context.delete(entry)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<FatigueEntry>())
        #expect(fetched.isEmpty)
    }

    /// `promptID` is `@Attribute(.unique)` — SwiftData upserts on the unique key,
    /// so inserting a second entry with the same promptID replaces the first.
    /// Locking that behaviour in: if it changes (e.g. to throwing an error),
    /// the test should be updated deliberately.
    @Test func duplicatePromptIDUpsertsRatherThanDuplicating() throws {
        let context = try TestHelpers.makeInMemoryContext()
        let first = TestHelpers.makeEntry(promptID: "same-id", activity: "first")
        context.insert(first)
        try context.save()

        let second = TestHelpers.makeEntry(promptID: "same-id", activity: "second")
        context.insert(second)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<FatigueEntry>())
        #expect(fetched.count == 1)
        #expect(fetched.first?.activity == "second")
    }

    @Test func statusRawAndEnumStayInSync() throws {
        let entry = TestHelpers.makeEntry(status: .responded)
        #expect(entry.statusRaw == "responded")
        entry.status = .manual
        #expect(entry.statusRaw == "manual")
    }

    @Test func exertionTypeRawAndEnumStayInSync() throws {
        let entry = TestHelpers.makeEntry(exertionType: .physical)
        #expect(entry.exertionTypeRaw == "physical")
        entry.exertionType = .cognitive
        #expect(entry.exertionTypeRaw == "cognitive")
        entry.exertionType = nil
        #expect(entry.exertionTypeRaw == nil)
    }

    /// A legacy entry persisted before `exertionType` existed will have a nil
    /// `exertionTypeRaw`. Confirm the computed property handles that cleanly.
    @Test func legacyEntryWithoutExertionTypeRawReadsAsNil() {
        let entry = TestHelpers.makeEntry()
        entry.exertionTypeRaw = nil
        #expect(entry.exertionType == nil)
    }
}
