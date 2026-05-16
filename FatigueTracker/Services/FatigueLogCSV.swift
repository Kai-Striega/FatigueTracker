import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct FatigueLogCSV: Transferable {
    let csv: String
    let filename: String

    @MainActor
    init(entries: [FatigueEntry]) {
        self.csv = CSVExporter.makeCSV(entries: entries)
        self.filename = "fatigue-log-\(Date().formatted(.iso8601.year().month().day())).csv"
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .commaSeparatedText) { value in
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(value.filename)
            try value.csv.write(to: url, atomically: true, encoding: .utf8)
            return SentTransferredFile(url)
        }
        .suggestedFileName { $0.filename }
    }
}
