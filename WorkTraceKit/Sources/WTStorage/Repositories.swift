import Foundation
import GRDB
import WTCore

// Repositories expose intent-revealing operations over WTCore types. GRDB never
// leaks past this boundary.

public struct ProjectRepository: Sendable {
    let db: AppDatabase
    public init(_ db: AppDatabase) { self.db = db }

    @discardableResult
    public func save(_ project: Project) throws -> Project {
        try db.write { database in
            var p = project
            try p.save(database)
            return p
        }
    }

    public func all() throws -> [Project] {
        try db.read { database in
            try Project.order(Column("name")).fetchAll(database)
        }
    }

    public func delete(id: Int64) throws {
        _ = try db.write { database in
            try Project.deleteOne(database, key: id)
        }
    }
}

public struct TaskRepository: Sendable {
    let db: AppDatabase
    public init(_ db: AppDatabase) { self.db = db }

    @discardableResult
    public func save(_ task: WorkTask) throws -> WorkTask {
        try db.write { database in
            var t = task
            try t.save(database)
            return t
        }
    }

    public func all(includeArchived: Bool = false) throws -> [WorkTask] {
        try db.read { database in
            var request = WorkTask.order(Column("name"))
            if !includeArchived {
                request = request.filter(Column("archived") == false)
            }
            return try request.fetchAll(database)
        }
    }

    public func forProject(_ projectId: Int64) throws -> [WorkTask] {
        try db.read { database in
            try WorkTask.filter(Column("projectId") == projectId)
                .order(Column("name")).fetchAll(database)
        }
    }

    public func delete(id: Int64) throws {
        _ = try db.write { database in
            try WorkTask.deleteOne(database, key: id)
        }
    }
}

public struct SessionRepository: Sendable {
    let db: AppDatabase
    public init(_ db: AppDatabase) { self.db = db }

    @discardableResult
    public func save(_ session: Session) throws -> Session {
        try db.write { database in
            var s = session
            try s.save(database)
            return s
        }
    }

    /// Any session still running (used for crash recovery).
    public func openSession() throws -> Session? {
        try db.read { database in
            try Session.filter(Column("endAt") == nil)
                .order(Column("startAt").desc)
                .fetchOne(database)
        }
    }

    public func sessions(from start: Date, to end: Date) throws -> [Session] {
        try db.read { database in
            try Session
                .filter(Column("startAt") >= start && Column("startAt") < end)
                .order(Column("startAt"))
                .fetchAll(database)
        }
    }

    public func delete(id: Int64) throws {
        _ = try db.write { database in
            try Session.deleteOne(database, key: id)
        }
    }

    /// Deletes *closed* sessions that started before `date`. Open (still running)
    /// sessions are never purged. Returns the number of rows removed.
    @discardableResult
    public func deleteOlderThan(_ date: Date) throws -> Int {
        try db.write { database in
            try Session
                .filter(Column("startAt") < date && Column("endAt") != nil)
                .deleteAll(database)
        }
    }

    /// Oldest retained session start, if any (for retention diagnostics).
    public func earliestStart() throws -> Date? {
        try db.read { database in
            try Date.fetchOne(database, Session.select(min(Column("startAt"))))
        }
    }
}

public struct ActivityRepository: Sendable {
    let db: AppDatabase
    public init(_ db: AppDatabase) { self.db = db }

    @discardableResult
    public func save(_ entry: ActivityEntry) throws -> ActivityEntry {
        try db.write { database in
            var e = entry
            try e.save(database)
            return e
        }
    }

    public func entries(from start: Date, to end: Date) throws -> [ActivityEntry] {
        try db.read { database in
            try ActivityEntry
                .filter(Column("startAt") >= start && Column("startAt") < end)
                .order(Column("startAt"))
                .fetchAll(database)
        }
    }

    /// Deletes activity in a time range. Returns the number of rows removed.
    @discardableResult
    public func deleteRange(from start: Date, to end: Date) throws -> Int {
        try db.write { database in
            try ActivityEntry
                .filter(Column("startAt") >= start && Column("startAt") < end)
                .deleteAll(database)
        }
    }

    /// Deletes activity entries that started before `date`. Returns rows removed.
    @discardableResult
    public func deleteOlderThan(_ date: Date) throws -> Int {
        try db.write { database in
            try ActivityEntry
                .filter(Column("startAt") < date)
                .deleteAll(database)
        }
    }

    /// Total number of stored activity entries (for retention diagnostics).
    public func count() throws -> Int {
        try db.read { database in
            try ActivityEntry.fetchCount(database)
        }
    }

    /// Oldest retained activity start, if any.
    public func earliestStart() throws -> Date? {
        try db.read { database in
            try Date.fetchOne(database, ActivityEntry.select(min(Column("startAt"))))
        }
    }
}

public struct PreferencesRepository: Sendable {
    let db: AppDatabase
    public init(_ db: AppDatabase) { self.db = db }

    /// Loads the single preferences row, creating defaults on first launch.
    public func load() throws -> UserPreferences {
        try db.write { database in
            if let existing = try UserPreferences.fetchOne(database) {
                return existing
            }
            var prefs = UserPreferences()
            try prefs.save(database)
            return prefs
        }
    }

    @discardableResult
    public func save(_ prefs: UserPreferences) throws -> UserPreferences {
        try db.write { database in
            var p = prefs
            try p.save(database)
            return p
        }
    }
}

public struct PrivacyMaskRepository: Sendable {
    let db: AppDatabase
    public init(_ db: AppDatabase) { self.db = db }

    public func all() throws -> [PrivacyMask] {
        try db.read { database in
            try PrivacyMask.fetchAll(database)
        }
    }

    public func enabled() throws -> [PrivacyMask] {
        try db.read { database in
            try PrivacyMask.filter(Column("enabled") == true).fetchAll(database)
        }
    }

    @discardableResult
    public func save(_ mask: PrivacyMask) throws -> PrivacyMask {
        try db.write { database in
            var m = mask
            try m.save(database)
            return m
        }
    }

    public func delete(id: Int64) throws {
        _ = try db.write { database in
            try PrivacyMask.deleteOne(database, key: id)
        }
    }
}

/// Append-only writer for the audit trail.
public struct AuditLogWriter: Sendable {
    let db: AppDatabase
    public init(_ db: AppDatabase) { self.db = db }

    public func log(
        action: String,
        targetType: String? = nil,
        targetId: String? = nil,
        detailJSON: String? = nil
    ) throws {
        var entry = AuditLog(
            action: action,
            targetType: targetType,
            targetId: targetId,
            detailJSON: detailJSON
        )
        _ = try db.write { database in
            try entry.insert(database)
        }
    }

    public func recent(limit: Int = 100) throws -> [AuditLog] {
        try db.read { database in
            try AuditLog.order(Column("createdAt").desc).limit(limit).fetchAll(database)
        }
    }
}
