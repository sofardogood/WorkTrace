import XCTest
import WTCore
@testable import WTNormalization

final class PrivacyGuardTests: XCTestCase {
    private func snapshot(
        app: String? = "Xcode",
        bundle: String? = "com.apple.dt.Xcode",
        title: String? = "MyFile.swift",
        url: String? = nil
    ) -> RawActivitySnapshot {
        RawActivitySnapshot(appName: app, bundleId: bundle, windowTitle: title, url: url)
    }

    func testNoMasksKeepsFullDetailAndReadableTitle() {
        let guardian = PrivacyGuard(masks: [])
        let decision = guardian.evaluate(snapshot())
        XCTAssertEqual(decision.level, .full)
        XCTAssertTrue(decision.keepAppIdentity)
        // At full detail the readable window title is retained (local-only).
        XCTAssertEqual(decision.windowTitle, "MyFile.swift")
    }

    func testExcludeMaskDropsEverything() {
        let mask = PrivacyMask(targetType: .app, pattern: "Xcode", action: .exclude)
        let decision = PrivacyGuard(masks: [mask]).evaluate(snapshot())
        XCTAssertEqual(decision.level, .excluded)
        XCTAssertFalse(decision.keepAppIdentity)
        XCTAssertNil(decision.windowTitle)
    }

    func testMaskTitleKeepsAppButDropsTitle() {
        let mask = PrivacyMask(targetType: .app, pattern: "Xcode", action: .maskTitle)
        let decision = PrivacyGuard(masks: [mask]).evaluate(snapshot())
        XCTAssertEqual(decision.level, .maskedTitle)
        XCTAssertTrue(decision.keepAppIdentity)
        // The title is dropped entirely, even though the app is kept.
        XCTAssertNil(decision.windowTitle)
    }

    func testTimeOnlyDropsIdentity() {
        let mask = PrivacyMask(targetType: .app, pattern: "Xcode", action: .timeOnly)
        let decision = PrivacyGuard(masks: [mask]).evaluate(snapshot())
        XCTAssertEqual(decision.level, .timeOnly)
        XCTAssertFalse(decision.keepAppIdentity)
    }

    func testMostRestrictiveMaskWins() {
        let masks = [
            PrivacyMask(targetType: .app, pattern: "Xcode", action: .maskTitle),
            PrivacyMask(targetType: .app, pattern: "Xcode", action: .exclude),
        ]
        let decision = PrivacyGuard(masks: masks).evaluate(snapshot())
        XCTAssertEqual(decision.level, .excluded)
    }

    func testDisabledMaskIsIgnored() {
        let mask = PrivacyMask(targetType: .app, pattern: "Xcode", action: .exclude, enabled: false)
        let decision = PrivacyGuard(masks: [mask]).evaluate(snapshot())
        XCTAssertEqual(decision.level, .full)
    }

    func testDomainMaskMatchesURLHost() {
        let mask = PrivacyMask(targetType: .urlDomain, pattern: "bank.example", action: .exclude)
        let snap = snapshot(app: "Safari", bundle: "com.apple.Safari", title: "Account",
                            url: "https://bank.example.com/account")
        let decision = PrivacyGuard(masks: [mask]).evaluate(snap)
        XCTAssertEqual(decision.level, .excluded)
    }

    func testDomainExtractedForFullDecision() {
        let snap = snapshot(app: "Safari", bundle: "com.apple.Safari", title: "News",
                            url: "https://news.example.com/story")
        let decision = PrivacyGuard(masks: []).evaluate(snap)
        XCTAssertEqual(decision.urlDomain, "news.example.com")
    }
}
