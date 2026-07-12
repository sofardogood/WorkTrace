import Foundation
import WTCore

/// Small view-model helpers shared by the timeline and report actions.
enum DayHelpers {
    static func dayBounds(for date: Date, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return (start, end)
    }

    static func taskNameMap(_ tasks: [WorkTask]) -> [Int64: String] {
        Dictionary(uniqueKeysWithValues: tasks.compactMap { task in
            task.id.map { ($0, task.name) }
        })
    }

    static func projectNameByTask(_ tasks: [WorkTask], _ projects: [Project]) -> [Int64: String] {
        let projectName = Dictionary(uniqueKeysWithValues: projects.compactMap { p in
            p.id.map { ($0, p.name) }
        })
        var result: [Int64: String] = [:]
        for task in tasks {
            guard let tid = task.id, let pid = task.projectId, let name = projectName[pid] else { continue }
            result[tid] = name
        }
        return result
    }

    static func hms(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600, m = (total % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    /// Locale-aware, human-readable duration that keeps seconds visible for short
    /// spans so sub-minute activity no longer collapses to "0m". Delegates to the
    /// unit-tested `DurationFormat.short`. Produces e.g. "42s" / "42秒",
    /// "3m 15s" / "3分15秒", "1h 24m" / "1時間24分".
    static func duration(_ seconds: TimeInterval, locale: Locale = .current) -> String {
        DurationFormat.short(seconds, locale: locale)
    }

    static func time(_ date: Date?) -> String {
        guard let date else { return "…" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
}
