import Foundation

enum CSVExporter {
    /// Produce CSV with columns: scheduled_at, responded_at, severity, severity_label,
    /// status, categories, activity.
    /// - `severity` is the integer 1–7 (empty for missed/pending).
    /// - `severity_label` is the zone keyword (functioning / pushing / stopped),
    ///   derived from the integer at export time. Empty for missed/pending.
    /// - Categories are semicolon-separated within the field.
    /// - Dates are ISO 8601. Line endings are CRLF for maximum compatibility (Excel etc).
    static func makeCSV(entries: [FatigueEntry]) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        var lines = ["scheduled_at,responded_at,severity,severity_label,status,categories,activity"]
        
        let sorted = entries.sorted { $0.scheduledAt < $1.scheduledAt }
        
        for entry in sorted {
            let scheduledAt = formatter.string(from: entry.scheduledAt)
            let respondedAt = entry.respondedAt.map { formatter.string(from: $0) } ?? ""
            let severity = entry.severity.map(String.init) ?? ""
            let severityLabel = entry.severity.map { SeverityZone.from(severity: $0).csvLabel } ?? ""
            let status = entry.status.rawValue
            let categories = escapeCSV(entry.categories.joined(separator: ";"))
            let activity = escapeCSV(entry.activity)
            
            lines.append("\(scheduledAt),\(respondedAt),\(severity),\(severityLabel),\(status),\(categories),\(activity)")
        }
        
        return lines.joined(separator: "\r\n") + "\r\n"
    }
    
    private static func escapeCSV(_ field: String) -> String {
        let needsQuoting = field.contains(",")
            || field.contains("\"")
            || field.contains("\n")
            || field.contains("\r")
        
        if needsQuoting {
            let normalised = field
                .replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
            let escaped = normalised.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}
