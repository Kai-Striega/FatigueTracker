import Testing
@testable import FatigueTracker

@Suite("SeverityZone")
struct SeverityZoneTests {
    @Test(arguments: [
        (1, SeverityZone.functioning),
        (2, SeverityZone.functioning),
        (3, SeverityZone.pushing),
        (4, SeverityZone.pushing),
        (5, SeverityZone.pushing),
        (6, SeverityZone.stopped),
        (7, SeverityZone.stopped),
    ])
    func mapsInRangeSeverityToZone(severity: Int, expected: SeverityZone) {
        #expect(SeverityZone.from(severity: severity) == expected)
    }

    /// Behaviour for out-of-range inputs is currently:
    /// - values ≤ 2 (including 0 and negatives) map to `.functioning`
    /// - values ≥ 6 (including 8+) map to `.stopped`
    /// Locking that in so a refactor that introduces clamping/validation can't
    /// silently change it.
    @Test(arguments: [
        (0, SeverityZone.functioning),
        (-1, SeverityZone.functioning),
        (8, SeverityZone.stopped),
        (100, SeverityZone.stopped),
    ])
    func outOfRangeSeverityFallsIntoBoundaryZones(severity: Int, expected: SeverityZone) {
        #expect(SeverityZone.from(severity: severity) == expected)
    }

    @Test func csvLabelMatchesRawValue() {
        for zone in SeverityZone.allCases {
            #expect(zone.csvLabel == zone.rawValue)
        }
    }

    @Test func labelsAreNonEmptyAndDistinctPerZone() {
        let fullLabels = SeverityZone.allCases.map(\.fullLabel)
        let shortLabels = SeverityZone.allCases.map(\.shortLabel)
        let csvLabels = SeverityZone.allCases.map(\.csvLabel)

        #expect(fullLabels.allSatisfy { !$0.isEmpty })
        #expect(shortLabels.allSatisfy { !$0.isEmpty })
        #expect(Set(fullLabels).count == SeverityZone.allCases.count)
        #expect(Set(shortLabels).count == SeverityZone.allCases.count)
        #expect(Set(csvLabels).count == SeverityZone.allCases.count)
    }
}
