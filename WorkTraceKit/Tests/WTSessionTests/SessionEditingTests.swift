import XCTest
import WTCore
@testable import WTSession

final class SessionEditingTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func closedSession(id: Int64?, minutes: Double, taskId: Int64? = 5) -> Session {
        Session(id: id, taskId: taskId, startAt: start,
                endAt: start.addingTimeInterval(minutes * 60), memo: "work")
    }

    // MARK: Split

    func testSplitProducesTwoContiguousSpans() {
        let session = closedSession(id: 1, minutes: 60)
        let mid = start.addingTimeInterval(20 * 60)
        let parts = SessionEditing.split(session, at: mid)
        XCTAssertNotNil(parts)
        XCTAssertEqual(parts?.left.endAt, mid)
        XCTAssertEqual(parts?.right.startAt, mid)
        XCTAssertEqual(parts?.right.endAt, session.endAt)
        // Right is a new record (no id) but inherits task and memo.
        XCTAssertNil(parts?.right.id)
        XCTAssertEqual(parts?.right.taskId, 5)
        XCTAssertEqual(parts?.right.memo, "work")
    }

    func testSplitRejectsPointOutsideSpan() {
        let session = closedSession(id: 1, minutes: 60)
        XCTAssertNil(SessionEditing.split(session, at: start.addingTimeInterval(-60)))
        XCTAssertNil(SessionEditing.split(session, at: start.addingTimeInterval(3 * 3600)))
    }

    func testSplitRejectsOpenSession() {
        let open = Session(id: 1, startAt: start)
        XCTAssertNil(SessionEditing.split(open, at: start.addingTimeInterval(60)))
    }

    // MARK: Merge

    func testMergeExtendsToLatestEndAndDeletesRest() {
        let a = closedSession(id: 1, minutes: 30)
        let b = Session(id: 2, taskId: 9, startAt: start.addingTimeInterval(30 * 60),
                        endAt: start.addingTimeInterval(90 * 60))
        let result = SessionEditing.merge([b, a]) // out of order on purpose
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.merged.id, 1) // earliest kept
        XCTAssertEqual(result?.merged.taskId, 5)
        XCTAssertEqual(result?.merged.endAt, b.endAt)
        XCTAssertEqual(result?.deletedIds, [2])
    }

    func testMergeNeedsAtLeastTwo() {
        XCTAssertNil(SessionEditing.merge([closedSession(id: 1, minutes: 10)]))
    }

    func testMergeWithOpenSessionStaysOpen() {
        let a = closedSession(id: 1, minutes: 30)
        let open = Session(id: 2, startAt: start.addingTimeInterval(30 * 60))
        let result = SessionEditing.merge([a, open])
        XCTAssertNil(result?.merged.endAt)
    }
}
