import Foundation
import WTCore

/// Outcome of a retention sweep, surfaced to the audit log and Settings UI.
public struct RetentionResult: Sendable, Equatable {
    /// Entries starting before this instant were purged.
    public let cutoff: Date
    public let deletedActivityEntries: Int
    public let deletedSessions: Int

    public var totalDeleted: Int { deletedActivityEntries + deletedSessions }

    public init(cutoff: Date, deletedActivityEntries: Int, deletedSessions: Int) {
        self.cutoff = cutoff
        self.deletedActivityEntries = deletedActivityEntries
        self.deletedSessions = deletedSessions
    }
}

/// Read-only snapshot of the current retention state, for the Settings screen:
/// what is kept, how much is stored, and when the next sweep will run.
public struct RetentionStatus: Sendable, Equatable {
    public let period: RetentionPeriod
    /// Start time of the oldest activity entry still stored, or nil when empty.
    public let oldestRetainedActivity: Date?
    public let storedEntryCount: Int
    public let databaseSizeBytes: Int64?
    public let latestBackupAt: Date?
    /// When the next automatic cleanup is expected, or nil for indefinite retention.
    public let nextScheduledCleanup: Date?

    public init(
        period: RetentionPeriod,
        oldestRetainedActivity: Date?,
        storedEntryCount: Int,
        databaseSizeBytes: Int64?,
        latestBackupAt: Date?,
        nextScheduledCleanup: Date?
    ) {
        self.period = period
        self.oldestRetainedActivity = oldestRetainedActivity
        self.storedEntryCount = storedEntryCount
        self.databaseSizeBytes = databaseSizeBytes
        self.latestBackupAt = latestBackupAt
        self.nextScheduledCleanup = nextScheduledCleanup
    }
}

/// Applies the retention policy by purging activity entries and closed manual
/// timer sessions older than the cutoff. It deliberately touches ONLY those two
/// tables — projects, tasks, preferences, privacy rules and the audit log are
/// never deleted here.
public struct RetentionCleaner: Sendable {
    private let activity: ActivityRepository
    private let sessions: SessionRepository

    public init(activity: ActivityRepository, sessions: SessionRepository) {
        self.activity = activity
        self.sessions = sessions
    }

    /// Purges everything that started before `cutoff`. Callers compute the cutoff
    /// from `RetentionPeriod.cutoff(now:)`.
    @discardableResult
    public func clean(olderThan cutoff: Date) throws -> RetentionResult {
        let entries = try activity.deleteOlderThan(cutoff)
        let closed = try sessions.deleteOlderThan(cutoff)
        return RetentionResult(
            cutoff: cutoff,
            deletedActivityEntries: entries,
            deletedSessions: closed
        )
    }

    /// Applies a retention period, if it is finite. Returns `nil` for the
    /// indefinite period (nothing purged).
    @discardableResult
    public func apply(_ period: RetentionPeriod, now: Date = Date(), calendar: Calendar = .current) throws -> RetentionResult? {
        guard let cutoff = period.cutoff(now: now, calendar: calendar) else { return nil }
        return try clean(olderThan: cutoff)
    }
}
