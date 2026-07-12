import Foundation
import GRDB
import WTCore

// GRDB persistence is added via extensions so the WTCore models stay free of
// any storage-engine dependency. Column names match property names, so GRDB's
// Codable support handles encoding/decoding automatically.

extension Project: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "project"
    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension WorkTask: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "workTask"
    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension Session: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "session"
    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension ActivityEntry: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "activityEntry"
    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension UserPreferences: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "userPreferences"
    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension PrivacyMask: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "privacyMask"
    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}

extension AuditLog: FetchableRecord, MutablePersistableRecord {
    public static let databaseTableName = "auditLog"
    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
