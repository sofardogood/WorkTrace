import Foundation
import WTCore

// This module defines ONLY the abstractions and no-op defaults for the AI
// features described in the spec (classification, report generation, insights,
// natural-language search). No LLM is integrated in the MVP.
//
// Later, a local model (default per the local-first philosophy) or a cloud model
// is dropped in behind these protocols without changing any caller.

// MARK: - Classification

public struct ClassificationContext: Sendable {
    public let recentTaskIds: [Int64]
    public init(recentTaskIds: [Int64] = []) {
        self.recentTaskIds = recentTaskIds
    }
}

public struct ClassificationResult: Sendable {
    public let suggestedTaskId: Int64?
    public let confidence: Double
    public let reason: String
    public let alternatives: [Int64]
    public init(suggestedTaskId: Int64?, confidence: Double, reason: String, alternatives: [Int64] = []) {
        self.suggestedTaskId = suggestedTaskId
        self.confidence = confidence
        self.reason = reason
        self.alternatives = alternatives
    }
}

public protocol ActivityClassifying: Sendable {
    /// Returns a suggestion, or `nil` if the activity can't be classified.
    /// Low-confidence results must never be auto-applied by callers.
    func classify(_ entry: ActivityEntry, context: ClassificationContext) async throws -> ClassificationResult?
}

// MARK: - Report generation

public struct ReportContext: Sendable {
    public let sessions: [Session]
    public let language: ReportLanguage
    /// Deterministic draft (from WTReporting) the AI may refine. Provided so the
    /// no-op implementation can simply pass it through.
    public let deterministicDraft: String
    public init(sessions: [Session], language: ReportLanguage, deterministicDraft: String) {
        self.sessions = sessions
        self.language = language
        self.deterministicDraft = deterministicDraft
    }
}

public struct GeneratedReport: Sendable {
    public let markdown: String
    /// Session ids used as evidence, so the UI can link back to them.
    public let sourceSessionIds: [Int64]
    public init(markdown: String, sourceSessionIds: [Int64]) {
        self.markdown = markdown
        self.sourceSessionIds = sourceSessionIds
    }
}

public protocol ReportGenerating: Sendable {
    func generateReport(_ context: ReportContext) async throws -> GeneratedReport
}

// MARK: - Insights & NL query (interfaces only for now)

public struct Insight: Sendable, Identifiable {
    public let id: UUID
    public let type: String
    public let severity: Int
    public let title: String
    public let body: String
    public init(id: UUID = UUID(), type: String, severity: Int, title: String, body: String) {
        self.id = id
        self.type = type
        self.severity = severity
        self.title = title
        self.body = body
    }
}

public protocol InsightGenerating: Sendable {
    func insights(for sessions: [Session]) async throws -> [Insight]
}

public struct NLQueryAnswer: Sendable {
    public let answer: String
    public let sourceSessionIds: [Int64]
    public let language: ReportLanguage
    public init(answer: String, sourceSessionIds: [Int64], language: ReportLanguage) {
        self.answer = answer
        self.sourceSessionIds = sourceSessionIds
        self.language = language
    }
}

public protocol NaturalLanguageQuerying: Sendable {
    func answer(_ question: String) async throws -> NLQueryAnswer
}
