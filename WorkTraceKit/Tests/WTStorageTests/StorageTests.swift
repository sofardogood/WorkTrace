import XCTest
import WTCore
@testable import WTStorage

final class StorageTests: XCTestCase {
    private func makeDB() throws -> AppDatabase {
        try AppDatabase(inMemory: true)
    }

    func testSaveAndFetchProject() throws {
        let db = try makeDB()
        let repo = ProjectRepository(db)
        let saved = try repo.save(Project(name: "Acme"))
        XCTAssertNotNil(saved.id)
        XCTAssertEqual(try repo.all().count, 1)
    }

    func testSessionRoundTripAndOpenSession() throws {
        let db = try makeDB()
        let repo = SessionRepository(db)
        let open = try repo.save(Session(startAt: Date()))
        XCTAssertNotNil(open.id)
        XCTAssertNotNil(try repo.openSession())

        var closed = open
        closed.endAt = Date()
        _ = try repo.save(closed)
        XCTAssertNil(try repo.openSession())
    }

    func testPreferencesCreatedOnFirstLoad() throws {
        let db = try makeDB()
        let repo = PreferencesRepository(db)
        let prefs = try repo.load()
        XCTAssertNotNil(prefs.id)
        // Second load returns the same row, not a new one.
        let again = try repo.load()
        XCTAssertEqual(prefs.id, again.id)
    }

    func testPreferencesPersistLanguageAcrossReload() throws {
        let db = try makeDB()
        let repo = PreferencesRepository(db)
        var prefs = try repo.load()
        prefs.defaultUILanguage = .japanese
        prefs.defaultReportLanguage = .english
        _ = try repo.save(prefs)

        let reloaded = try repo.load()
        XCTAssertEqual(reloaded.defaultUILanguage, .japanese)
        XCTAssertEqual(reloaded.defaultReportLanguage, .english)
    }

    func testAuditLogAppend() throws {
        let db = try makeDB()
        let writer = AuditLogWriter(db)
        try writer.log(action: AuditAction.dataExported, targetType: "csv")
        XCTAssertEqual(try writer.recent().count, 1)
    }
}
