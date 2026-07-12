import Foundation
import WTCore

/// Exports sessions to CSV with localized headers. Language of the column
/// headers is independent of the UI language.
public struct CSVExporter: Sendable {
    public init() {}

    public func export(_ rows: [SessionExportRow], language: ReportLanguage) -> String {
        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: language.rawValue)
        dateFmt.dateFormat = "yyyy-MM-dd"

        let timeFmt = DateFormatter()
        timeFmt.locale = Locale(identifier: language.rawValue)
        timeFmt.dateFormat = "HH:mm"

        var out = [csvLine(ReportStrings.csvHeader(language))]

        for row in rows {
            let s = row.session
            let minutes = Int((s.duration / 60).rounded())
            let fields: [String] = [
                dateFmt.string(from: s.startAt),
                timeFmt.string(from: s.startAt),
                s.endAt.map { timeFmt.string(from: $0) } ?? "",
                String(minutes),
                row.taskName ?? "",
                row.projectName ?? "",
                s.billable ? "1" : "0",
                s.memo ?? ""
            ]
            out.append(csvLine(fields))
        }
        return out.joined(separator: "\n")
    }

    private func csvLine(_ fields: [String]) -> String {
        fields.map(escape).joined(separator: ",")
    }

    private func escape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            let quoted = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(quoted)\""
        }
        return field
    }
}
