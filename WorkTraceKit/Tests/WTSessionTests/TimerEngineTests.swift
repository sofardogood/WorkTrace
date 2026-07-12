import XCTest
import WTCore
import WTStorage
@testable import WTSession

@MainActor
final class TimerEngineTests: XCTestCase {
    private func makeEngine() throws -> TimerEngine {
        let db = try AppDatabase(inMemory: true)
        return TimerEngine(sessions: SessionRepository(db), audit: AuditLogWriter(db))
    }

    func testStartStopLifecycle() throws {
        let engine = try makeEngine()
        XCTAssertEqual(engine.state, .idle)

        try engine.start(taskId: nil, memo: "work")
        XCTAssertTrue(engine.isRunning)
        XCTAssertNotNil(engine.currentSession)

        try engine.stop()
        XCTAssertEqual(engine.state, .idle)
    }

    func testPauseResumeCreatesNewSpan() throws {
        let db = try AppDatabase(inMemory: true)
        let task = try TaskRepository(db).save(WorkTask(name: "Design"))
        let engine = TimerEngine(sessions: SessionRepository(db), audit: AuditLogWriter(db))

        try engine.start(taskId: task.id)
        let firstId = engine.currentSession?.id

        try engine.pause()
        XCTAssertTrue(engine.isPaused)

        try engine.resume()
        XCTAssertTrue(engine.isRunning)
        XCTAssertNotEqual(engine.currentSession?.id, firstId)
        XCTAssertEqual(engine.currentSession?.taskId, task.id)
    }

    func testRecoverOpenSession() throws {
        let db = try AppDatabase(inMemory: true)
        let repo = SessionRepository(db)
        _ = try repo.save(Session(startAt: Date()))

        let engine = TimerEngine(sessions: repo, audit: AuditLogWriter(db))
        try engine.recoverOpenSession()
        XCTAssertTrue(engine.isRunning)
    }

    func testStartIsNoOpWhenAlreadyRunning() throws {
        let engine = try makeEngine()
        try engine.start(taskId: nil)
        let id = engine.currentSession?.id
        try engine.start(taskId: 99) // ignored
        XCTAssertEqual(engine.currentSession?.id, id)
        XCTAssertNil(engine.currentSession?.taskId)
    }

    func testUpdateMemoOnRunningSession() throws {
        let engine = try makeEngine()
        try engine.start(taskId: nil)
        try engine.updateMemo("in progress")
        XCTAssertEqual(engine.currentSession?.memo, "in progress")
    }

    func testStopWhenIdleIsHarmless() throws {
        let engine = try makeEngine()
        try engine.stop()
        XCTAssertEqual(engine.state, .idle)
    }

    func testPauseWhenIdleIsNoOp() throws {
        let engine = try makeEngine()
        try engine.pause()
        XCTAssertEqual(engine.state, .idle)
    }

    func testStopClosesOpenSession() throws {
        let db = try AppDatabase(inMemory: true)
        let repo = SessionRepository(db)
        let engine = TimerEngine(sessions: repo, audit: AuditLogWriter(db))
        try engine.start(taskId: nil)
        try engine.stop()
        XCTAssertNil(try repo.openSession())
    }
}
