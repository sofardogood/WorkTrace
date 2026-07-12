import XCTest
import WTCore
@testable import WTReporting

final class CSVExporterTests: XCTestCase {
    private func row(memo: String? = nil, billable: Bool = true) -> SessionExportRow {
        let start = Date()
        let session = Session(startAt: start, endAt: start.addingTimeInterval(1800),
                              memo: memo, billable: billable)
        return SessionExportRow(session: session, taskName: "Design", projectName: "Acme")
    }

    func testHeaderRowInEnglish() {
        let csv = CSVExporter().export([], language: .english)
        XCTAssertTrue(csv.hasPrefix("Date,Start,End,Minutes,Task,Project,Billable,Memo"))
    }

    func testHeaderRowInJapanese() {
        let csv = CSVExporter().export([], language: .japanese)
        XCTAssertTrue(csv.contains("日付"))
    }

    func testMinutesAndBillableFlag() {
        let csv = CSVExporter().export([row(billable: true)], language: .english)
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        // 30-minute session, billable = 1.
        XCTAssertTrue(lines[1].contains(",30,"))
        XCTAssertTrue(lines[1].contains("Design"))
    }

    func testFieldsWithCommasAreQuoted() {
        let csv = CSVExporter().export([row(memo: "fixed bug, added test")], language: .english)
        XCTAssertTrue(csv.contains("\"fixed bug, added test\""))
    }

    func testEmbeddedQuotesAreDoubled() {
        let csv = CSVExporter().export([row(memo: "say \"hi\"")], language: .english)
        XCTAssertTrue(csv.contains("\"say \"\"hi\"\"\""))
    }
}
