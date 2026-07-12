import Foundation
import WTCore

/// Input for a daily report: the day's sessions plus lookups to resolve names.
public struct DailyReportInput: Sendable {
    public let date: Date
    public let sessions: [Session]
    public let taskNames: [Int64: String]
    public let projectNames: [Int64: String]

    public init(
        date: Date,
        sessions: [Session],
        taskNames: [Int64: String],
        projectNames: [Int64: String]
    ) {
        self.date = date
        self.sessions = sessions
        self.taskNames = taskNames
        self.projectNames = projectNames
    }
}

/// A row for CSV export. Keeps the exporter independent of storage.
public struct SessionExportRow: Sendable {
    public let session: Session
    public let taskName: String?
    public let projectName: String?

    public init(session: Session, taskName: String?, projectName: String?) {
        self.session = session
        self.taskName = taskName
        self.projectName = projectName
    }
}

enum DurationFormat {
    /// "1h 23m" / "23m".
    static func short(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}
