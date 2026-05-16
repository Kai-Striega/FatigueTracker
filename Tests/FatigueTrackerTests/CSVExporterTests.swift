import Foundation
import Testing
@testable import FatigueTracker

@Suite("CSVExporter")
struct CSVExporterTests {
    static let header = "scheduled_at,responded_at,severity,severity_label,exertion_type,status,activity"

    @Test func emptyEntriesProducesHeaderOnly() {
        let csv = CSVExporter.makeCSV(entries: [])
        #expect(csv == Self.header + "\r\n")
    }

    @Test func singleFullyPopulatedEntry() {
        let scheduled = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14T22:13:20Z
        let responded = Date(timeIntervalSince1970: 1_700_000_060)
        let entry = TestHelpers.makeEntry(
            promptID: "abc",
            scheduledAt: scheduled,
            respondedAt: responded,
            severity: 4,
            activity: "walking",
            status: .responded,
            exertionType: .physical
        )

        let csv = CSVExporter.makeCSV(entries: [entry])
        let expected = Self.header + "\r\n" +
            "2023-11-14T22:13:20Z,2023-11-14T22:14:20Z,4,pushing,physical,responded,walking\r\n"
        #expect(csv == expected)
    }

    @Test func missingOptionalFieldsRenderAsEmptyColumns() {
        let scheduled = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = TestHelpers.makeEntry(
            scheduledAt: scheduled,
            respondedAt: nil,
            severity: nil,
            activity: "",
            status: .manual,
            exertionType: nil
        )

        let csv = CSVExporter.makeCSV(entries: [entry])
        let expected = Self.header + "\r\n" +
            "2023-11-14T22:13:20Z,,,,,manual,\r\n"
        #expect(csv == expected)
    }

    @Test func entriesAreSortedByScheduledAtAscending() {
        let early = TestHelpers.makeEntry(promptID: "early",
                                          scheduledAt: Date(timeIntervalSince1970: 1_000),
                                          activity: "early")
        let middle = TestHelpers.makeEntry(promptID: "middle",
                                           scheduledAt: Date(timeIntervalSince1970: 2_000),
                                           activity: "middle")
        let late = TestHelpers.makeEntry(promptID: "late",
                                         scheduledAt: Date(timeIntervalSince1970: 3_000),
                                         activity: "late")

        let csv = CSVExporter.makeCSV(entries: [late, early, middle])
        let lines = csv.split(separator: "\r\n", omittingEmptySubsequences: false).map(String.init)

        #expect(lines[0] == Self.header)
        #expect(lines[1].hasSuffix(",early"))
        #expect(lines[2].hasSuffix(",middle"))
        #expect(lines[3].hasSuffix(",late"))
    }

    @Test(arguments: [
        (1, "functioning"),
        (2, "functioning"),
        (3, "pushing"),
        (5, "pushing"),
        (6, "stopped"),
        (7, "stopped"),
    ])
    func severityLabelMatchesZone(severity: Int, expectedLabel: String) {
        let entry = TestHelpers.makeEntry(severity: severity)
        let csv = CSVExporter.makeCSV(entries: [entry])
        #expect(csv.contains(",\(severity),\(expectedLabel),"))
    }

    @Test(arguments: [
        ("comma, inside", "\"comma, inside\""),
        ("quote\" inside", "\"quote\"\" inside\""),
        ("newline\ninside", "\"newline\ninside\""),
        ("carriage\rreturn", "\"carriage\nreturn\""),
        ("crlf\r\ninside", "\"crlf\ninside\""),
        ("plain text", "plain text"),
        ("", ""),
    ])
    func activityFieldEscaping(input: String, expectedCell: String) {
        let entry = TestHelpers.makeEntry(activity: input)
        let csv = CSVExporter.makeCSV(entries: [entry])
        // Strip header + row separator to isolate the data row + its terminator.
        let prefix = Self.header + "\r\n2023-11-14T22:13:20Z,,,,,manual,"
        #expect(csv == prefix + expectedCell + "\r\n")
    }

    @Test func usesCRLFLineEndings() {
        let entry = TestHelpers.makeEntry(activity: "x")
        let csv = CSVExporter.makeCSV(entries: [entry])
        // No bare LFs outside of escaped fields. With activity "x" there are none.
        #expect(csv.contains("\r\n"))
        #expect(!csv.replacingOccurrences(of: "\r\n", with: "").contains("\n"))
    }

    @Test func bothExertionTypesRoundTripToCsvLabel() {
        let physical = TestHelpers.makeEntry(promptID: "p",
                                             scheduledAt: Date(timeIntervalSince1970: 1),
                                             exertionType: .physical)
        let cognitive = TestHelpers.makeEntry(promptID: "c",
                                              scheduledAt: Date(timeIntervalSince1970: 2),
                                              exertionType: .cognitive)
        let csv = CSVExporter.makeCSV(entries: [physical, cognitive])
        #expect(csv.contains(",physical,"))
        #expect(csv.contains(",cognitive,"))
    }
}
