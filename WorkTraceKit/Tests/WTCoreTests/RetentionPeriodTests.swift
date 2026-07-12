import XCTest
@testable import WTCore

final class RetentionPeriodTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ hh: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hh))!
    }

    func testDefaultIsSevenDays() {
        XCTAssertEqual(RetentionPeriod.default, .sevenDays)
        XCTAssertEqual(RetentionPeriod.default.days, 7)
    }

    func testDefaultPreferencesRetainSevenDays() {
        XCTAssertEqual(UserPreferences().retentionDays, 7)
        XCTAssertEqual(UserPreferences().retentionPeriod, .sevenDays)
    }

    func testIndefiniteHasNoCutoff() {
        XCTAssertNil(RetentionPeriod.indefinite.days)
        XCTAssertNil(RetentionPeriod.indefinite.cutoff(now: date(2026, 7, 11)))
    }

    func testSevenDayCutoffRetainsTodayPlusPreviousSix() {
        // On 2026-07-11, retaining 7 days keeps 07-05 … 07-11.
        // The cutoff is start of 2026-07-05; anything before it is purged.
        let cutoff = RetentionPeriod.sevenDays.cutoff(now: date(2026, 7, 11), calendar: calendar)
        XCTAssertEqual(cutoff, date(2026, 7, 5, 0))
    }

    func testDaysInitMapsBackToCases() {
        XCTAssertEqual(RetentionPeriod(days: 30), .thirtyDays)
        XCTAssertEqual(RetentionPeriod(days: nil), .indefinite)
        XCTAssertEqual(RetentionPeriod(days: 0), .indefinite)
        // Unknown positive counts fall back to the default.
        XCTAssertEqual(RetentionPeriod(days: 5), .sevenDays)
    }

    func testAllExpectedOptionsExist() {
        XCTAssertEqual(
            RetentionPeriod.allCases.map(\.rawValue).sorted(),
            [0, 7, 30, 90, 180, 365].sorted()
        )
    }
}
