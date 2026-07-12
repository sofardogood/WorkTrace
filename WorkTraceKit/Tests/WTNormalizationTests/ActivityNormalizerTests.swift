import XCTest
import WTCore
@testable import WTNormalization

final class ActivityNormalizerTests: XCTestCase {
    private func makeNormalizer(masks: [PrivacyMask] = [], gap: TimeInterval = 30) -> ActivityNormalizer {
        ActivityNormalizer(privacyGuard: PrivacyGuard(masks: masks), maxMergeGap: gap)
    }

    private func snap(_ app: String, at seconds: TimeInterval, base: Date) -> RawActivitySnapshot {
        RawActivitySnapshot(timestamp: base.addingTimeInterval(seconds), appName: app,
                            bundleId: "id.\(app)", windowTitle: "\(app) window")
    }

    func testContiguousIdenticalSnapshotsMergeIntoOneEntry() throws {
        let base = Date()
        let n = makeNormalizer()
        XCTAssertNil(n.ingest(snap("Xcode", at: 0, base: base)))
        XCTAssertNil(n.ingest(snap("Xcode", at: 5, base: base)))
        XCTAssertNil(n.ingest(snap("Xcode", at: 10, base: base)))

        let entry = try XCTUnwrap(n.flush())
        XCTAssertEqual(entry.duration, 10, accuracy: 0.001)
    }

    func testChangingActivityEmitsPreviousEntry() {
        let base = Date()
        let n = makeNormalizer()
        XCTAssertNil(n.ingest(snap("Xcode", at: 0, base: base)))
        let emitted = n.ingest(snap("Safari", at: 5, base: base))
        XCTAssertNotNil(emitted)
        XCTAssertEqual(emitted?.appName, "Xcode")
    }

    func testIdleFlushesPendingEntry() {
        let base = Date()
        let n = makeNormalizer()
        XCTAssertNil(n.ingest(snap("Xcode", at: 0, base: base)))
        let idle = RawActivitySnapshot(timestamp: base.addingTimeInterval(5), isIdle: true)
        let emitted = n.ingest(idle)
        XCTAssertEqual(emitted?.appName, "Xcode")
        // Idle itself is never recorded.
        XCTAssertNil(n.flush())
    }

    func testGapBeyondMaxMergeStartsNewEntry() {
        let base = Date()
        let n = makeNormalizer(gap: 30)
        XCTAssertNil(n.ingest(snap("Xcode", at: 0, base: base)))
        // 60s later, same app but past the merge gap → previous entry emitted.
        let emitted = n.ingest(snap("Xcode", at: 60, base: base))
        XCTAssertNotNil(emitted)
        XCTAssertEqual(emitted?.appName, "Xcode")
    }

    func testExcludedActivityIsNotRecorded() {
        let base = Date()
        let mask = PrivacyMask(targetType: .app, pattern: "Secret", action: .exclude)
        let n = makeNormalizer(masks: [mask])
        XCTAssertNil(n.ingest(snap("Secret", at: 0, base: base)))
        XCTAssertNil(n.flush())
    }
}
