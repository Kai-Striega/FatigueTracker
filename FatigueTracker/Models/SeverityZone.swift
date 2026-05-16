import SwiftUI

/// The three functional zones of fatigue severity, mapped from 1–7 integer values.
/// Single source of truth for zone boundaries, labels, colors, and notification pre-fill.
enum SeverityZone: String, CaseIterable {
    case functioning
    case pushing
    case stopped
    
    /// Map a 1–7 severity value to a zone.
    static func from(severity: Int) -> SeverityZone {
        switch severity {
        case ...2:    return .functioning  // 1–2
        case 3...5:   return .pushing      // 3–5
        default:      return .stopped      // 6–7
        }
    }
    
    /// Full label shown in the form and history view.
    var fullLabel: String {
        switch self {
        case .functioning: return "Functioning normally"
        case .pushing:     return "Pushing through"
        case .stopped:     return "Not functioning"
        }
    }
    
    /// Short label for the keyword strip beneath the severity slider.
    var shortLabel: String {
        switch self {
        case .functioning: return "Functioning"
        case .pushing:     return "Pushing"
        case .stopped:     return "Stopped"
        }
    }

    /// Snake_case identifier for the CSV export.
    var csvLabel: String { rawValue }

    /// Colorblind-safe color for this zone. Used in the severity badge and slider track.
    /// Chosen from the viridis-adjacent palette: monotonic in luminance, distinguishable
    /// under deuteranopia and protanopia.
    var color: Color {
        switch self {
        case .functioning: return Color(red: 0.20, green: 0.39, blue: 0.55)   // blue
        case .pushing:     return Color(red: 0.48, green: 0.58, blue: 0.30)   // muted olive-green
        case .stopped:     return Color(red: 0.85, green: 0.55, blue: 0.13)   // amber-orange
        }
    }
}
