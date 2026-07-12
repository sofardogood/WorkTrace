import Foundation
import GRDB

extension AppDatabase {
    /// Schema migrations. Column names match the Swift property names so GRDB's
    /// Codable persistence maps them automatically.
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        // During development, wipe and rebuild if a migration changes.
        migrator.eraseDatabaseOnSchemaChange = true
        #endif

        migrator.registerMigration("v1_mvp_schema") { db in
            try db.create(table: "project") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("clientName", .text)
                t.column("budgetHours", .double)
                t.column("contractAmount", .double)
                t.column("hourlyRate", .double)
                t.column("status", .text).notNull().defaults(to: "active")
                t.column("createdAt", .datetime).notNull()
            }

            try db.create(table: "workTask") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("projectId", .integer)
                    .references("project", onDelete: .setNull)
                t.column("name", .text).notNull()
                t.column("billable", .boolean).notNull().defaults(to: true)
                t.column("defaultRate", .double)
                t.column("colorHex", .text)
                t.column("archived", .boolean).notNull().defaults(to: false)
                t.column("createdAt", .datetime).notNull()
            }

            try db.create(table: "session") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("taskId", .integer)
                    .references("workTask", onDelete: .setNull)
                t.column("startAt", .datetime).notNull().indexed()
                t.column("endAt", .datetime)
                t.column("source", .text).notNull().defaults(to: "manual")
                t.column("confidence", .double)
                t.column("memo", .text)
                t.column("billable", .boolean).notNull().defaults(to: true)
                t.column("rate", .double)
                t.column("reportVisible", .boolean).notNull().defaults(to: true)
                t.column("createdAt", .datetime).notNull()
            }

            try db.create(table: "activityEntry") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("startAt", .datetime).notNull().indexed()
                t.column("endAt", .datetime).notNull()
                t.column("appName", .text)
                t.column("bundleId", .text)
                t.column("windowTitle", .text)
                t.column("urlDomain", .text)
                t.column("documentPathHash", .text)
                t.column("privacyLevel", .text).notNull().defaults(to: "full")
            }

            try db.create(table: "userPreferences") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("defaultUILanguage", .text).notNull().defaults(to: "system")
                t.column("defaultReportLanguage", .text).notNull().defaults(to: "ja")
                t.column("timezone", .text).notNull()
                t.column("locale", .text).notNull()
                t.column("currency", .text).notNull().defaults(to: "JPY")
                t.column("idleThresholdSeconds", .integer).notNull().defaults(to: 120)
                t.column("samplingIntervalSeconds", .integer).notNull().defaults(to: 5)
                t.column("activityCaptureEnabled", .boolean).notNull().defaults(to: true)
            }

            try db.create(table: "privacyMask") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("targetType", .text).notNull()
                t.column("pattern", .text).notNull()
                t.column("action", .text).notNull()
                t.column("enabled", .boolean).notNull().defaults(to: true)
            }

            try db.create(table: "auditLog") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("action", .text).notNull()
                t.column("targetType", .text)
                t.column("targetId", .text)
                t.column("createdAt", .datetime).notNull().indexed()
                t.column("detailJSON", .text)
            }
        }

        // Retention: how long activity/sessions are kept, and when cleanup last ran.
        migrator.registerMigration("v2_retention") { db in
            try db.alter(table: "userPreferences") { t in
                t.add(column: "retentionDays", .integer).defaults(to: 7)
                t.add(column: "lastCleanupAt", .datetime)
            }
        }

        return migrator
    }
}
