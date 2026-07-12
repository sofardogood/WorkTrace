import XCTest
import WTCore
@testable import WTReporting

final class ActivitySummarizerTests: XCTestCase {
    private func entry(
        app: String?,
        title: String?,
        minutes: Double,
        level: PrivacyLevel = .full
    ) -> ActivityEntry {
        let start = Date(timeIntervalSince1970: 0)
        return ActivityEntry(
            startAt: start,
            endAt: start.addingTimeInterval(minutes * 60),
            appName: app,
            windowTitle: title,
            privacyLevel: level
        )
    }

    func testByAppSumsDurationsPerApp() {
        let entries = [
            entry(app: "Xcode", title: "A.swift", minutes: 10),
            entry(app: "Xcode", title: "B.swift", minutes: 20),
            entry(app: "Safari", title: "Docs", minutes: 5),
        ]
        let totals = ActivitySummarizer.byApp(entries)
        XCTAssertEqual(totals.count, 2)
        let xcode = totals.first { $0.label == "Xcode" }
        XCTAssertEqual(xcode?.total, 30 * 60)
        XCTAssertEqual(xcode?.count, 2)
    }

    func testByAppSortsByTotalDescending() {
        let entries = [
            entry(app: "Safari", title: "Docs", minutes: 5),
            entry(app: "Xcode", title: "A.swift", minutes: 30),
        ]
        let totals = ActivitySummarizer.byApp(entries)
        XCTAssertEqual(totals.map(\.label), ["Xcode", "Safari"])
    }

    func testNilAppBucketsUnderEmptyLabel() {
        let entries = [
            entry(app: nil, title: "Untitled", minutes: 4),
            entry(app: nil, title: "Other", minutes: 6),
        ]
        let totals = ActivitySummarizer.byApp(entries)
        XCTAssertEqual(totals.count, 1)
        XCTAssertEqual(totals.first?.label, "")
        XCTAssertEqual(totals.first?.total, 10 * 60)
        XCTAssertEqual(totals.first?.count, 2)
    }

    func testByWindowTitleGroupsByTitle() {
        let entries = [
            entry(app: "Mail", title: "Inbox", minutes: 10),
            entry(app: "Mail", title: "Inbox", minutes: 5),
            entry(app: "Mail", title: "Sent", minutes: 3),
        ]
        let totals = ActivitySummarizer.byWindowTitle(entries)
        XCTAssertEqual(totals.count, 2)
        XCTAssertEqual(totals.first?.label, "Inbox")
        XCTAssertEqual(totals.first?.total, 15 * 60)
    }

    func testMaskedEntriesBucketUnderEmptyWindowLabel() {
        // Masked entries carry no readable title, so they collect under "".
        let entries = [
            entry(app: "Bank", title: nil, minutes: 8, level: .maskedTitle),
            entry(app: "Bank", title: nil, minutes: 2, level: .timeOnly),
        ]
        let totals = ActivitySummarizer.byWindowTitle(entries)
        XCTAssertEqual(totals.count, 1)
        XCTAssertEqual(totals.first?.label, "")
        XCTAssertEqual(totals.first?.total, 10 * 60)
    }

    func testEmptyInputYieldsNoTotals() {
        XCTAssertTrue(ActivitySummarizer.byApp([]).isEmpty)
        XCTAssertTrue(ActivitySummarizer.byWindowTitle([]).isEmpty)
    }

    // MARK: - byWindow (title + associated app)

    func testByWindowCarriesMostUsedApp() {
        let entries = [
            entry(app: "Chrome", title: "Docs", minutes: 5),
            entry(app: "Safari", title: "Docs", minutes: 20),  // more time → associated app
            entry(app: "Mail", title: "Inbox", minutes: 8),
        ]
        let windows = ActivitySummarizer.byWindow(entries)
        XCTAssertEqual(windows.first?.title, "Docs")
        XCTAssertEqual(windows.first?.total, 25 * 60)
        XCTAssertEqual(windows.first?.appName, "Safari")
        XCTAssertFalse(windows.first?.isMasked ?? true)
    }

    func testByWindowMarksMaskedBucket() {
        let entries = [
            entry(app: "Bank", title: nil, minutes: 10, level: .maskedTitle),
        ]
        let windows = ActivitySummarizer.byWindow(entries)
        XCTAssertEqual(windows.count, 1)
        XCTAssertTrue(windows.first?.isMasked ?? false)
        XCTAssertEqual(windows.first?.title, "")
    }

    // MARK: - ActivityFilter

    func testDefaultFilterIsNoOp() {
        let entries = [entry(app: "Xcode", title: "A", minutes: 1)]
        let filter = ActivityFilter()
        XCTAssertFalse(filter.isActive)
        XCTAssertEqual(filter.apply(entries).count, 1)
    }

    func testFilterByAppNameExactMatch() {
        let entries = [
            entry(app: "Xcode", title: "A", minutes: 1),
            entry(app: "Safari", title: "B", minutes: 1),
        ]
        let filter = ActivityFilter(appName: "Xcode")
        XCTAssertTrue(filter.isActive)
        XCTAssertEqual(filter.apply(entries).map(\.appName), ["Xcode"])
    }

    func testFilterByTitleSubstringCaseInsensitive() {
        let entries = [
            entry(app: "Mail", title: "Inbox — Work", minutes: 1),
            entry(app: "Mail", title: "Sent", minutes: 1),
            entry(app: "Bank", title: nil, minutes: 1, level: .maskedTitle),  // masked never matches
        ]
        let filter = ActivityFilter(titleQuery: "inbox")
        let result = filter.apply(entries)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.windowTitle, "Inbox — Work")
    }

    func testFilterMaskingModes() {
        let entries = [
            entry(app: "Xcode", title: "A", minutes: 1),
            entry(app: "Bank", title: nil, minutes: 1, level: .maskedTitle),
        ]
        XCTAssertEqual(ActivityFilter(masking: .readableOnly).apply(entries).count, 1)
        XCTAssertEqual(ActivityFilter(masking: .maskedOnly).apply(entries).count, 1)
        XCTAssertEqual(ActivityFilter(masking: .all).apply(entries).count, 2)
    }
}
