import UIKit
import Testing
@testable import FatigueTracker

@Suite("ExertionType")
struct ExertionTypeTests {
    @Test func physicalMappings() {
        #expect(ExertionType.physical.label == "Physical")
        #expect(ExertionType.physical.symbolName == "figure.walk")
        #expect(ExertionType.physical.csvLabel == "physical")
        #expect(ExertionType.physical.rawValue == "physical")
    }

    @Test func cognitiveMappings() {
        #expect(ExertionType.cognitive.label == "Cognitive")
        #expect(ExertionType.cognitive.symbolName == "brain.head.profile")
        #expect(ExertionType.cognitive.csvLabel == "cognitive")
        #expect(ExertionType.cognitive.rawValue == "cognitive")
    }

    /// Guards against typos in SF Symbol names — a non-existent symbol renders
    /// as a blank glyph in the UI with no compile-time warning.
    @Test func symbolNamesResolveToRealSFSymbols() {
        for type in ExertionType.allCases {
            #expect(UIImage(systemName: type.symbolName) != nil,
                    "SF Symbol \(type.symbolName) does not exist")
        }
    }
}
