import XCTest
import WTCore
import GRDB
@testable import WTStorage

final class MigrationAndBackupTests: XCTestCase {

    // MARK: - Migrations

    func testAllModelsPersistAfterMigration() throws {
        let db = try AppDatabase(inMemory: true)

        let project = try ProjectRepository(db).save(Project(name: "Acme"))
        let task = try TaskRepository(db).save(WorkTask(projectId: project.id, name: "Design"))
        let session = try SessionRepository(db).save(
            Session(taskId: task.id, startAt: Date(), endAt: Date().addingTimeInterval(60))
        )
        let entry = try ActivityRepository(db).save(
            ActivityEntry(startAt: Date(), endAt: Date().addingTimeInterval(30), appName: "Xcode")
        )
        let mask = try PrivacyMaskRepository(db).save(
            PrivacyMask(targetType: .app, pattern: "1Password", action: .exclude)
        )

        XCTAssertNotNil(project.id)
        XCTAssertNotNil(task.id)
        XCTAssertNotNil(session.id)
        XCTAssertNotNil(entry.id)
        XCTAssertNotNil(mask.id)
    }

    func testForeignKeySetNullOnTaskDelete() throws {
        let db = try AppDatabase(inMemory: true)
        let tasks = TaskRepository(db)
        let sessions = SessionRepository(db)

        let task = try tasks.save(WorkTask(name: "Temp"))
        _ = try sessions.save(Session(taskId: task.id, startAt: Date(), endAt: Date()))
        try tasks.delete(id: task.id!)

        let (start, end) = (Date.distantPast, Date.distantFuture)
        let remaining = try sessions.sessions(from: start, to: end)
        XCTAssertEqual(remaining.count, 1)
        XCTAssertNil(remaining.first?.taskId) // FK set to null, session preserved
    }

    // MARK: - Backup

    private func tempDir() throws -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wt-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func testBackupProducesReadableCopy() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let dbPath = dir.appendingPathComponent("live.sqlite").path
        let db = try AppDatabase(path: dbPath)
        _ = try ProjectRepository(db).save(Project(name: "Acme"))

        let backupURL = dir.appendingPathComponent("copy.sqlite")
        let manager = BackupManager(database: db, directory: dir.appendingPathComponent("Backups"))
        try manager.backup(to: backupURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: backupURL.path))

        let restored = try AppDatabase(path: backupURL.path)
        XCTAssertEqual(try ProjectRepository(restored).all().count, 1)
    }

    func testAutomaticBackupOncePerDay() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let db = try AppDatabase(path: dir.appendingPathComponent("live.sqlite").path)
        let manager = BackupManager(database: db, directory: dir.appendingPathComponent("Backups"))

        let first = try manager.automaticBackupIfNeeded()
        XCTAssertNotNil(first)
        // Same day → no new backup.
        let second = try manager.automaticBackupIfNeeded()
        XCTAssertNil(second)
        XCTAssertEqual(try manager.list().count, 1)
    }

    func testAutomaticBackupPrunesOldFiles() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let backupDir = dir.appendingPathComponent("Backups")
        let db = try AppDatabase(path: dir.appendingPathComponent("live.sqlite").path)
        let manager = BackupManager(database: db, directory: backupDir, keep: 2)

        let cal = Calendar.current
        // Three backups on three different days; only 2 should remain.
        for offset in [-2, -1, 0] {
            let day = cal.date(byAdding: .day, value: offset, to: Date())!
            _ = try manager.automaticBackupIfNeeded(now: day)
        }
        XCTAssertEqual(try manager.list().count, 2)
    }

    // MARK: - Validation

    func testValidateAcceptsRealBackup() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let db = try AppDatabase(path: dir.appendingPathComponent("live.sqlite").path)
        let backupURL = dir.appendingPathComponent("good.sqlite")
        let manager = BackupManager(database: db, directory: dir)
        try manager.backup(to: backupURL)

        XCTAssertNoThrow(try manager.validate(at: backupURL))
    }

    func testValidateRejectsMissingFile() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let db = try AppDatabase(path: dir.appendingPathComponent("live.sqlite").path)
        let manager = BackupManager(database: db, directory: dir)
        let missing = dir.appendingPathComponent("nope.sqlite")

        XCTAssertThrowsError(try manager.validate(at: missing)) { error in
            XCTAssertEqual(error as? BackupError, .fileMissing)
        }
    }

    func testValidateRejectsNonSQLiteFile() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let db = try AppDatabase(path: dir.appendingPathComponent("live.sqlite").path)
        let manager = BackupManager(database: db, directory: dir)
        let junk = dir.appendingPathComponent("junk.sqlite")
        try Data("not a database".utf8).write(to: junk)

        XCTAssertThrowsError(try manager.validate(at: junk)) { error in
            XCTAssertEqual(error as? BackupError, .notSQLite)
        }
    }

    func testValidateRejectsForeignSQLiteDatabase() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // A valid SQLite file that lacks WorkTrace's schema.
        let foreign = dir.appendingPathComponent("foreign.sqlite")
        let other = try DatabaseQueue(path: foreign.path)
        try other.write { db in
            try db.execute(sql: "CREATE TABLE unrelated(id INTEGER PRIMARY KEY)")
        }

        let db = try AppDatabase(path: dir.appendingPathComponent("live.sqlite").path)
        let manager = BackupManager(database: db, directory: dir)

        XCTAssertThrowsError(try manager.validate(at: foreign)) { error in
            XCTAssertEqual(error as? BackupError, .notWorkTraceBackup)
        }
    }

    func testRestoreValidatesBeforeReplacing() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Live db has real data that must survive a failed restore.
        let livePath = dir.appendingPathComponent("live.sqlite").path
        let live = try AppDatabase(path: livePath)
        _ = try ProjectRepository(live).save(Project(name: "Keep"))

        let junk = dir.appendingPathComponent("junk.sqlite")
        try Data("not a database".utf8).write(to: junk)

        let manager = BackupManager(database: live, directory: dir)
        XCTAssertThrowsError(try manager.restore(from: junk)) { error in
            XCTAssertEqual(error as? BackupError, .notSQLite)
        }

        // Live data untouched.
        let reopened = try AppDatabase(path: livePath)
        XCTAssertEqual(try ProjectRepository(reopened).all().map(\.name), ["Keep"])
    }

    func testRestoreReplacesLiveDatabase() throws {
        let dir = try tempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        // Backup a db that has one project.
        let sourcePath = dir.appendingPathComponent("source.sqlite").path
        let source = try AppDatabase(path: sourcePath)
        _ = try ProjectRepository(source).save(Project(name: "FromBackup"))
        let backupURL = dir.appendingPathComponent("snapshot.sqlite")
        try BackupManager(database: source, directory: dir).backup(to: backupURL)

        // A separate, empty live db.
        let livePath = dir.appendingPathComponent("live.sqlite").path
        let live = try AppDatabase(path: livePath)
        XCTAssertEqual(try ProjectRepository(live).all().count, 0)

        try BackupManager(database: live, directory: dir).restore(from: backupURL)

        // Reopen the live path after restore.
        let reopened = try AppDatabase(path: livePath)
        let names = try ProjectRepository(reopened).all().map(\.name)
        XCTAssertEqual(names, ["FromBackup"])
    }
}
