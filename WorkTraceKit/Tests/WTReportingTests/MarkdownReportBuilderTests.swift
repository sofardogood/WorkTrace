import XCTest
import WTCore
@testable import WTReporting

final class MarkdownReportBuilderTests: XCTestCase {
    private func makeInput(sessions: [Session], taskNames: [Int64: String] = [:]) -> DailyReportInput {
        DailyReportInput(date: Date(), sessions: sessions, taskNames: taskNames, projectNames: [:])
    }

    func testEmptyDayProducesPlaceholder() {
        let md = MarkdownReportBuilder().buildDaily(makeInput(sessions: []), language: .english)
        XCTAssertTrue(md.contains("Daily Work Report"))
        XCTAssertTrue(md.contains("to be filled in"))
    }

    func testJapaneseTitleUsed() {
        let md = MarkdownReportBuilder().buildDaily(makeInput(sessions: []), language: .japanese)
        XCTAssertTrue(md.contains("業務日報"))
    }

    func testSessionsGroupedByTaskWithTotal() {
        let start = Date()
        let s1 = Session(id: 1, taskId: 10, startAt: start, endAt: start.addingTimeInterval(3600))
        let s2 = Session(id: 2, taskId: 10, startAt: start.addingTimeInterval(3600),
                         endAt: start.addingTimeInterval(5400))
        let input = makeInput(sessions: [s1, s2], taskNames: [10: "Design"])
        let md = MarkdownReportBuilder().buildDaily(input, language: .english)
        XCTAssertTrue(md.contains("Design"))
        // 60 + 30 minutes = 1h 30m total.
        XCTAssertTrue(md.contains("1h 30m"))
    }

    func testHiddenSessionsExcluded() {
        let start = Date()
        var hidden = Session(id: 1, taskId: 10, startAt: start, endAt: start.addingTimeInterval(3600))
        hidden.reportVisible = false
        let input = makeInput(sessions: [hidden], taskNames: [10: "Secret"])
        let md = MarkdownReportBuilder().buildDaily(input, language: .english)
        XCTAssertFalse(md.contains("Secret"))
    }
}
