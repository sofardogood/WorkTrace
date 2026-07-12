import XCTest
import WTCore
@testable import WTStorage

final class RetentionCleanerTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func day(_ y: Int, _ m: Int, _ d: Int, _ hh: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hh))!
    }

    private func entry(on date: Date, app: String = "Xcode") -> ActivityEntry {
        ActivityEntry(startAt: date, endAt: date.addingTimeInterval(60), appName: app)
    }

    func testSevenDayCleanupKeepsWithinWindowAndPurgesOlder() throws {
        let db = try AppDatabase(inMemory: true)
        let activity = ActivityRepository(db)
        let sessions = SessionRepository(db)
        let now = day(2026, 7, 11)

        // Within window (07-05 … 07-11): kept.
        _ = try activity.save(entry(on: day(2026, 7, 11)))
        _ = try activity.save(entry(on: day(2026, 7, 5)))     // boundary day: kept
        // Outside window: purged.
        _ = try activity.save(entry(on: day(2026, 7, 4)))
        _ = try activity.save(entry(on: day(2026, 6, 30)))

        // Closed sessions, same split.
        _ = try sessions.save(Session(startAt: day(2026, 7, 6), endAt: day(2026, 7, 6, 13)))
        _ = try sessions.save(Session(startAt: day(2026, 7, 1), endAt: day(2026, 7, 1, 13)))

        let cleaner = RetentionCleaner(activity: activity, sessions: sessions)
        let result = try cleaner.apply(.sevenDays, now: now, calendar: calendar)

        XCTAssertEqual(result?.deletedActivityEntries, 2)
        XCTAssertEqual(result?.deletedSessions, 1)
        XCTAssertEqual(result?.totalDeleted, 3)

        let remaining = try activity.entries(from: .distantPast, to: .distantFuture)
        XCTAssertEqual(remaining.count, 2)
        XCTAssertTrue(remaining.allSatisfy { $0.startAt >= day(2026, 7, 5, 0) })
    }

    func testIndefiniteRetentionDeletesNothing() throws {
        let db = try AppDatabase(inMemory: true)
        let activity = ActivityRepository(db)
        let sessions = SessionRepository(db)
        _ = try activity.save(entry(on: day(2000, 1, 1)))

        let cleaner = RetentionCleaner(activity: activity, sessions: sessions)
        let result = try cleaner.apply(.indefinite, now: day(2026, 7, 11), calendar: calendar)

        XCTAssertNil(result)
        XCTAssertEqual(try activity.count(), 1)
    }

    func testOpenSessionsAreNeverPurged() throws {
        let db = try AppDatabase(inMemory: true)
        let sessions = SessionRepository(db)
        // Very old but still running (endAt nil): must survive.
        _ = try sessions.save(Session(startAt: day(2000, 1, 1), endAt: nil))

        let cleaner = RetentionCleaner(activity: ActivityRepository(db), sessions: sessions)
        _ = try cleaner.apply(.sevenDays, now: day(2026, 7, 11), calendar: calendar)

        XCTAssertNotNil(try sessions.openSession())
    }

    func testCleanupDoesNotDeleteProjectsTasksMasks() throws {
        let db = try AppDatabase(inMemory: true)
        let projects = ProjectRepository(db)
        let tasks = TaskRepository(db)
        let masks = PrivacyMaskRepository(db)
        let activity = ActivityRepository(db)

        let project = try projects.save(Project(name: "Acme"))
        _ = try tasks.save(WorkTask(projectId: project.id, name: "Design"))
        _ = try masks.save(PrivacyMask(targetType: .app, pattern: "1Password", action: .exclude))
        _ = try activity.save(entry(on: day(2000, 1, 1)))   // ancient, will be purged

        let cleaner = RetentionCleaner(activity: activity, sessions: SessionRepository(db))
        _ = try cleaner.apply(.sevenDays, now: day(2026, 7, 11), calendar: calendar)

        XCTAssertEqual(try projects.all().count, 1)
        XCTAssertEqual(try tasks.all().count, 1)
        XCTAssertEqual(try masks.all().count, 1)
        XCTAssertEqual(try activity.count(), 0)  // activity was purged
    }
}
