import Foundation
import WTCore

// Default, offline, no-op implementations used by the MVP. They are deliberately
// "dumb": no network, no model. They exist so the app can depend on the AI
// protocols today and swap in a real provider later with zero caller changes.

public struct NoopActivityClassifier: ActivityClassifying {
    public init() {}
    public func classify(_ entry: ActivityEntry, context: ClassificationContext) async throws -> ClassificationResult? {
        nil // no suggestion in the MVP
    }
}

/// Returns the deterministic draft unchanged. This lets the report UI call the
/// `ReportGenerating` seam now while the actual text comes from WTReporting.
public struct PassthroughReportGenerator: ReportGenerating {
    public init() {}
    public func generateReport(_ context: ReportContext) async throws -> GeneratedReport {
        GeneratedReport(
            markdown: context.deterministicDraft,
            sourceSessionIds: context.sessions.compactMap(\.id)
        )
    }
}

public struct NoopInsightGenerator: InsightGenerating {
    public init() {}
    public func insights(for sessions: [Session]) async throws -> [Insight] {
        []
    }
}

public struct NoopNaturalLanguageQuery: NaturalLanguageQuerying {
    public init() {}
    public func answer(_ question: String) async throws -> NLQueryAnswer {
        NLQueryAnswer(answer: "", sourceSessionIds: [], language: .japanese)
    }
}
