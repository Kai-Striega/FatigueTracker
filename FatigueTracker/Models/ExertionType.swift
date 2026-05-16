import Foundation

/// The kind of exertion an entry represents. Lets the user separate fatigue
/// driven by physical effort from fatigue driven by cognitive load.
enum ExertionType: String, CaseIterable {
    case physical
    case cognitive

    var label: String {
        switch self {
        case .physical:  return "Physical"
        case .cognitive: return "Cognitive"
        }
    }

    var symbolName: String {
        switch self {
        case .physical:  return "figure.walk"
        case .cognitive: return "brain.head.profile"
        }
    }

    var csvLabel: String { rawValue }
}
