import Foundation

/// How a session came to exist. Kept stable — downstream features rely on it.
public enum SessionSource: String, Codable, Sendable, CaseIterable {
    case manual        // user pressed start
    case rule          // rule engine (later)
    case calendar      // calendar match (later)
    case aiClassified  // AI classifier (later)
}

/// Privacy level applied to an activity entry BEFORE it is written to disk.
public enum PrivacyLevel: String, Codable, Sendable, CaseIterable {
    case full         // full detail retained
    case maskedTitle  // window title hashed / omitted, app + domain kept
    case timeOnly     // only the time span is kept ("Private Activity")
    case excluded     // not recorded at all
}

public enum ProjectStatus: String, Codable, Sendable, CaseIterable {
    case active
    case onHold = "on_hold"
    case archived
}

public enum ReportType: String, Codable, Sendable, CaseIterable {
    case daily
    case weekly
}

public enum ExportFormat: String, Codable, Sendable, CaseIterable {
    case csv
    case markdown
    case pdf
}
