import Foundation
import WTCore

/// Deterministic (non-AI) daily-report generator. This is the MVP report path.
/// An LLM implementation can later replace/augment this behind `WTAI`'s
/// `ReportGenerating` protocol without changing callers.
public struct MarkdownReportBuilder: Sendable {
    public init() {}

    public func buildDaily(_ input: DailyReportInput, language: ReportLanguage) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: language.rawValue)
        df.dateStyle = .full
        df.timeStyle = .none

        let visible = input.sessions.filter { $0.reportVisible }
        var lines: [String] = []

        lines.append("# \(ReportStrings.dailyTitle(language)) — \(df.string(from: input.date))")
        lines.append("")

        // Work done, grouped by task.
        lines.append("## \(ReportStrings.sectionWorkDone(language))")
        let grouped = Dictionary(grouping: visible, by: { $0.taskId })
        let total = visible.reduce(0.0) { $0 + $1.duration }

        if grouped.isEmpty {
            lines.append("- \(ReportStrings.placeholder(language))")
        } else {
            for (taskId, group) in grouped.sorted(by: { totalDuration($0.value) > totalDuration($1.value) }) {
                let name = taskId.flatMap { input.taskNames[$0] } ?? ReportStrings.noTask(language)
                let sum = totalDuration(group)
                var line = "- **\(name)** — \(DurationFormat.short(sum))"
                if let taskId, let project = input.projectNames[taskId] {
                    line += " _(\(project))_"
                }
                lines.append(line)
                for session in group where !(session.memo ?? "").isEmpty {
                    lines.append("    - \(session.memo!)")
                }
            }
        }
        lines.append("")
        lines.append("**\(ReportStrings.totalLabel(language))**: \(DurationFormat.short(total))")
        lines.append("")

        // Remaining sections are placeholders the user fills in (facts vs.
        // opinion stay separated per the spec until AI generation is added).
        for section in [
            ReportStrings.sectionResults(language),
            ReportStrings.sectionIssues(language),
            ReportStrings.sectionPlan(language),
            ReportStrings.sectionQuestions(language)
        ] {
            lines.append("## \(section)")
            lines.append("- \(ReportStrings.placeholder(language))")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    private func totalDuration(_ sessions: [Session]) -> TimeInterval {
        sessions.reduce(0.0) { $0 + $1.duration }
    }
}
