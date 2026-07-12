import XCTest
import WTCore
@testable import WTReporting

final class ActivityAnalyticsTests: XCTestCase {
    private var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func at(_ y: Int, _ m: Int, _ d: Int, _ hh: Int, _ mm: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hh, minute: mm))!
    }

    private func entry(_ start: Date, minutes: Double, app: String?, title: String? = nil,
                       bundle: String? = nil) -> ActivityEntry {
        ActivityEntry(startAt: start, endAt: start.addingTimeInterval(minutes * 60),
                      appName: app, bundleId: bundle, windowTitle: title)
    }

    // MARK: - Idle

    func testIdleGapsDetectedBeyondThreshold() {
        let entries = [
            entry(at(2026, 7, 11, 9, 0), minutes: 10, app: "Xcode"),   // ends 9:10
            entry(at(2026, 7, 11, 9, 30), minutes: 5, app: "Safari"),  // 20-min gap
        ]
        let gaps = ActivityAnalytics.idleGaps(entries, idleThreshold: 120)
        XCTAssertEqual(gaps.count, 1)
        XCTAssertEqual(gaps.first?.duration, 20 * 60)
    }

    func testShortGapBelowThresholdIsNotIdle() {
        let entries = [
            entry(at(2026, 7, 11, 9, 0), minutes: 10, app: "Xcode"),   // ends 9:10
            entry(at(2026, 7, 11, 9, 11), minutes: 5, app: "Safari"),  // 1-min gap
        ]
        XCTAssertTrue(ActivityAnalytics.idleGaps(entries, idleThreshold: 120).isEmpty)
    }

    // MARK: - Stats

    func testStatsActiveIdleSwitchesAndTops() {
        let entries = [
            entry(at(2026, 7, 11, 9, 0), minutes: 30, app: "Xcode", title: "A.swift"),
            entry(at(2026, 7, 11, 9, 40), minutes: 10, app: "Safari", title: "Docs"), // 10-min idle before
            entry(at(2026, 7, 11, 9, 50), minutes: 20, app: "Xcode", title: "B.swift"),
        ]
        let stats = ActivityAnalytics.stats(for: entries, idleThreshold: 120)
        XCTAssertEqual(stats.activeTotal, 60 * 60)
        XCTAssertEqual(stats.idleTotal, 10 * 60)
        XCTAssertEqual(stats.appSwitches, 2)          // Xcode→Safari→Xcode
        XCTAssertEqual(stats.topApp?.label, "Xcode")  // 50 min total
        XCTAssertEqual(stats.entryCount, 3)
    }

    func testStatsExcludesWorkTraceFromWorkTotalsButNotIdle() {
        let entries = [
            entry(at(2026, 7, 11, 9, 0), minutes: 30, app: "Xcode", bundle: "com.apple.dt.Xcode"),
            entry(at(2026, 7, 11, 9, 40), minutes: 5, app: "WorkTrace", bundle: "com.worktrace.app"),
        ]
        let stats = ActivityAnalytics.stats(for: entries, idleThreshold: 120,
                                            excludingBundleId: "com.worktrace.app")
        XCTAssertEqual(stats.activeTotal, 30 * 60)     // WorkTrace's 5 min excluded
        XCTAssertEqual(stats.idleTotal, 10 * 60)       // idle still measured across all
        XCTAssertEqual(stats.topApp?.label, "Xcode")
        XCTAssertEqual(stats.entryCount, 1)
    }

    // MARK: - Period (7-day)

    func testSevenDayPeriodHasOneBucketPerDayAscending() {
        let entries = [
            entry(at(2026, 7, 11, 9, 0), minutes: 60, app: "Xcode"),
            entry(at(2026, 7, 9, 9, 0), minutes: 30, app: "Safari"),
            entry(at(2026, 7, 5, 9, 0), minutes: 15, app: "Mail"),
        ]
        let period = ActivityAnalytics.period(
            entries: entries, days: 7, endingOn: at(2026, 7, 11, 12),
            idleThreshold: 120, calendar: calendar
        )
        XCTAssertEqual(period.days.count, 7)
        XCTAssertEqual(period.days.first?.date, calendar.startOfDay(for: at(2026, 7, 5, 0)))
        XCTAssertEqual(period.days.last?.date, calendar.startOfDay(for: at(2026, 7, 11, 0)))
        XCTAssertEqual(period.activeTotal, (60 + 30 + 15) * 60)
        XCTAssertEqual(period.dailyAverageActive, Double(105 * 60) / 7.0, accuracy: 0.5)
        XCTAssertEqual(period.mostUsedApp?.label, "Xcode")
        XCTAssertEqual(period.totalAppSwitches, 0)  // one app per day, no intraday switches
    }

    func testPeriodExcludesEntriesOutsideWindow() {
        let entries = [
            entry(at(2026, 7, 11, 9, 0), minutes: 60, app: "Xcode"),
            entry(at(2026, 6, 1, 9, 0), minutes: 999, app: "Old"),   // far outside 7-day window
        ]
        let period = ActivityAnalytics.period(
            entries: entries, days: 7, endingOn: at(2026, 7, 11, 12),
            idleThreshold: 120, calendar: calendar
        )
        XCTAssertEqual(period.activeTotal, 60 * 60)
        XCTAssertEqual(period.mostUsedApp?.label, "Xcode")
    }
}
