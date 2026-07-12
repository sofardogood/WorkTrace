import Foundation
import GRDB

/// Local-first backup for the SQLite database. Backups are plain single-file
/// SQLite databases produced with `VACUUM INTO`, which captures a consistent
/// snapshot (including any WAL contents) without stopping the app. Nothing
/// leaves this Mac — a backup is just another file the user controls.
public struct BackupManager: Sendable {
    public struct BackupFile: Sendable, Identifiable, Equatable {
        public let url: URL
        public let createdAt: Date
        public var id: URL { url }
    }

    let database: AppDatabase
    /// Directory that holds automatic backups.
    public let directory: URL
    /// How many automatic backups to keep before pruning the oldest.
    public let keep: Int

    public init(database: AppDatabase, directory: URL, keep: Int = 7) {
        self.database = database
        self.directory = directory
        self.keep = keep
    }

    /// Writes a consistent snapshot of the database to `url`.
    public func backup(to url: URL) throws {
        // VACUUM INTO cannot run inside a transaction, so use a transaction-free
        // write. The destination path is embedded as an escaped string literal
        // because SQLite does not bind parameters in a VACUUM statement.
        let escaped = url.path.replacingOccurrences(of: "'", with: "''")
        try database.writer.writeWithoutTransaction { db in
            try db.execute(sql: "VACUUM INTO '\(escaped)'")
        }
    }

    /// Makes a dated automatic backup if the newest one is not from today, then
    /// prunes old backups. Returns the URL written, or `nil` if today's backup
    /// already exists. Safe to call on every launch.
    @discardableResult
    public func automaticBackupIfNeeded(now: Date = Date(), calendar: Calendar = .current) throws -> URL? {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if let latest = try list().first,
           calendar.isDate(latest.createdAt, inSameDayAs: now) {
            return nil
        }

        let url = directory.appendingPathComponent("worktrace-\(Self.stamp(now)).sqlite")
        try backup(to: url)
        try prune()
        return url
    }

    /// Existing automatic backups, newest first.
    public func list() throws -> [BackupFile] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { return [] }
        let urls = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ).filter { $0.pathExtension == "sqlite" }

        return urls.map { url in
            let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate ?? .distantPast
            return BackupFile(url: url, createdAt: date)
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    /// Checks that `url` points to a readable file that is a valid SQLite
    /// database containing WorkTrace's schema. Throws a specific `BackupError`
    /// describing the first problem found. Call this before `restore(from:)`.
    public func validate(at url: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { throw BackupError.fileMissing }
        guard fm.isReadableFile(atPath: url.path) else { throw BackupError.notReadable }

        // SQLite files begin with a fixed 16-byte magic header.
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            throw BackupError.notReadable
        }
        defer { try? handle.close() }
        let header = (try? handle.read(upToCount: 16)) ?? Data()
        guard header.elementsEqual(Array("SQLite format 3\u{0}".utf8)) else {
            throw BackupError.notSQLite
        }

        // Open read-only and confirm it looks like a WorkTrace database. Any
        // GRDB error here (corruption, encryption, etc.) also fails validation.
        do {
            var config = Configuration()
            config.readonly = true
            let queue = try DatabaseQueue(path: url.path, configuration: config)
            let looksRight = try queue.read { db in
                try db.tableExists("session") && db.tableExists("userPreferences")
            }
            guard looksRight else { throw BackupError.notWorkTraceBackup }
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.notSQLite
        }
    }

    /// Restores a backup by copying it over the live database file. This must be
    /// done while the database is not open, so the caller is expected to quit the
    /// app immediately afterwards; the restored data loads on next launch.
    public func restore(from url: URL) throws {
        try validate(at: url)
        guard let path = database.path else {
            throw BackupError.noDatabaseFile
        }
        let dest = URL(fileURLWithPath: path)
        let fm = FileManager.default
        // Remove the WAL/SHM sidecars so the restored file is authoritative.
        for suffix in ["", "-wal", "-shm"] {
            let side = URL(fileURLWithPath: path + suffix)
            if fm.fileExists(atPath: side.path) {
                try fm.removeItem(at: side)
            }
        }
        try fm.copyItem(at: url, to: dest)
    }

    private func prune() throws {
        let backups = try list()
        guard backups.count > keep else { return }
        for stale in backups[keep...] {
            try? FileManager.default.removeItem(at: stale.url)
        }
    }

    private static func stamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: date)
    }
}

public enum BackupError: Error, Equatable {
    case noDatabaseFile
    case fileMissing
    case notReadable
    case notSQLite
    case notWorkTraceBackup
}
