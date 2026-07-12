import XCTest
@testable import WTCore

final class DurationFormatTests: XCTestCase {
    private let en = Locale(identifier: "en_US")
    private let ja = Locale(identifier: "ja_JP")

    func testSecondsUnderOneMinute() {
        XCTAssertEqual(DurationFormat.short(42, locale: en), "42s")
        XCTAssertEqual(DurationFormat.short(42, locale: ja), "42秒")
    }

    func testMinutesAndSeconds() {
        XCTAssertEqual(DurationFormat.short(195, locale: en), "3m 15s")
        XCTAssertEqual(DurationFormat.short(195, locale: ja), "3分15秒")
    }

    func testWholeMinutesDropSeconds() {
        XCTAssertEqual(DurationFormat.short(180, locale: en), "3m")
        XCTAssertEqual(DurationFormat.short(180, locale: ja), "3分")
    }

    func testHoursAndMinutes() {
        // 1h 24m == 5040s
        XCTAssertEqual(DurationFormat.short(5040, locale: en), "1h 24m")
        XCTAssertEqual(DurationFormat.short(5040, locale: ja), "1時間24分")
    }

    func testWholeHoursDropMinutes() {
        XCTAssertEqual(DurationFormat.short(3600, locale: en), "1h")
        XCTAssertEqual(DurationFormat.short(3600, locale: ja), "1時間")
    }

    func testZeroAndNegativeClampToSeconds() {
        XCTAssertEqual(DurationFormat.short(0, locale: en), "0s")
        XCTAssertEqual(DurationFormat.short(-5, locale: ja), "0秒")
    }

    func testRoundsToNearestSecond() {
        XCTAssertEqual(DurationFormat.short(59.6, locale: en), "1m")
    }
}
