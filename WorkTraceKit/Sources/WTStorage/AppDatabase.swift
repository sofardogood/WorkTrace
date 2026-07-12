import Foundation
import GRDB
import WTCore

/// Owns the SQLite connection and schema. Uses a `DatabasePool` so WAL mode is
/// enabled (better concurrency, crash resilience). GRDB is confined to this
/// module; callers only ever see `WTCore` types, so the storage engine (and a
/// future SQLCipher encryption option) can change without touching the app.
public final class AppDatabase: Sendable {
    public let writer: any DatabaseWriter

    /// On-disk location of the database, or `nil` for an in-memory database.
    public let path: String?

    /// - Parameter path: file path for the SQLite database.
    public init(path: String) throws {
        var config = Configuration()
        config.foreignKeysEnabled = true
        // NOTE: a future encryption option (SQLCipher) is wired in here via
        // `config.prepareDatabase { db in try db.usePassphrase(...) }`.
        let pool = try DatabasePool(path: path, configuration: config)
        self.writer = pool
        self.path = path
        try Self.migrator.migrate(pool)
    }

    /// In-memory database for tests.
    public init(inMemory: Bool) throws {
        precondition(inMemory)
        let queue = try DatabaseQueue()
        self.writer = queue
        self.path = nil
        try Self.migrator.migrate(queue)
    }

    public func read<T>(_ block: (Database) throws -> T) throws -> T {
        try writer.read(block)
    }

    public func write<T>(_ block: (Database) throws -> T) throws -> T {
        try writer.write(block)
    }
}
