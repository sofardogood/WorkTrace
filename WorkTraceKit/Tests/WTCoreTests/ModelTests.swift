import XCTest
@testable import WTCore

final class ModelTests: XCTestCase {
    func testSessionDurationForOpenSessionIsPositive() {
        let session = Session(startAt: Date().addingTimeInterval(-60))
        XCTAssertTrue(session.isOpen)
        XCTAssertGreaterThan(session.duration, 59)
    }

    func testSessionDurationUsesEndWhenClosed() {
        let start = Date()
        let session = Session(startAt: start, endAt: start.addingTimeInterval(120))
        XCTAssertFalse(session.isOpen)
        XCTAssertEqual(session.duration, 120, accuracy: 0.001)
    }

    func testAppLanguageLocaleIdentifier() {
        XCTAssertNil(AppLanguage.system.localeIdentifier)
        XCTAssertEqual(AppLanguage.japanese.localeIdentifier, "ja")
        XCTAssertEqual(AppLanguage.english.localeIdentifier, "en")
    }
}
