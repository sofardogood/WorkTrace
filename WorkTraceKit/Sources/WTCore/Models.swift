import Foundation

// MARK: - Project

/// A client / engagement. Billing-related fields are optional and unused by the
/// MVP UI, but modeled now so profit tracking can be added without a migration.
public struct Project: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var id: Int64?
    public var name: String
    public var clientName: String?
    public var budgetHours: Double?
    public var contractAmount: Double?
    public var hourlyRate: Double?
    public var status: ProjectStatus
    public var createdAt: Date

    public init(
        id: Int64? = nil,
        name: String,
        clientName: String? = nil,
        budgetHours: Double? = nil,
        contractAmount: Double? = nil,
        hourlyRate: Double? = nil,
        status: ProjectStatus = .active,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.clientName = clientName
        self.budgetHours = budgetHours
        self.contractAmount = contractAmount
        self.hourlyRate = hourlyRate
        self.status = status
        self.createdAt = createdAt
    }
}

// MARK: - WorkTask

/// A unit of work under a project. Named `WorkTask` to avoid colliding with
/// Swift Concurrency's `Task`.
public struct WorkTask: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var id: Int64?
    public var projectId: Int64?
    public var name: String
    public var billable: Bool
    public var defaultRate: Double?
    public var colorHex: String?
    public var archived: Bool
    public var createdAt: Date

    public init(
        id: Int64? = nil,
        projectId: Int64? = nil,
        name: String,
        billable: Bool = true,
        defaultRate: Double? = nil,
        colorHex: String? = nil,
        archived: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.projectId = projectId
        self.name = name
        self.billable = billable
        self.defaultRate = defaultRate
        self.colorHex = colorHex
        self.archived = archived
        self.createdAt = createdAt
    }
}

// MARK: - Session

/// A span of work time confirmed as a business record. This is the core,
/// stable unit that reports, insights and billing all read from.
public struct Session: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var id: Int64?
    public var taskId: Int64?
    public var startAt: Date
    public var endAt: Date?
    public var source: SessionSource
    public var confidence: Double?
    public var memo: String?
    public var billable: Bool
    public var rate: Double?
    public var reportVisible: Bool
    public var createdAt: Date

    public init(
        id: Int64? = nil,
        taskId: Int64? = nil,
        startAt: Date,
        endAt: Date? = nil,
        source: SessionSource = .manual,
        confidence: Double? = nil,
        memo: String? = nil,
        billable: Bool = true,
        rate: Double? = nil,
        reportVisible: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.taskId = taskId
        self.startAt = startAt
        self.endAt = endAt
        self.source = source
        self.confidence = confidence
        self.memo = memo
        self.billable = billable
        self.rate = rate
        self.reportVisible = reportVisible
        self.createdAt = createdAt
    }

    /// Elapsed time. Uses `Date()` while the session is still open.
    public var duration: TimeInterval {
        (endAt ?? Date()).timeIntervalSince(startAt)
    }

    public var isOpen: Bool { endAt == nil }
}

// MARK: - ActivityEntry

/// A compressed, privacy-masked slice of observed activity. `PrivacyGuard`
/// decides how much is kept BEFORE this is ever persisted: at `.full` the
/// readable window title is retained; masked levels drop it to `nil`. All data
/// stays in the local database and is never transmitted.
public struct ActivityEntry: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var id: Int64?
    public var startAt: Date
    public var endAt: Date
    public var appName: String?
    public var bundleId: String?
    /// Readable active-window title. Present only for `.full` entries; `nil`
    /// whenever a privacy mask applies (maskTitle / timeOnly / exclude).
    public var windowTitle: String?
    public var urlDomain: String?
    public var documentPathHash: String?
    public var privacyLevel: PrivacyLevel

    public init(
        id: Int64? = nil,
        startAt: Date,
        endAt: Date,
        appName: String? = nil,
        bundleId: String? = nil,
        windowTitle: String? = nil,
        urlDomain: String? = nil,
        documentPathHash: String? = nil,
        privacyLevel: PrivacyLevel = .full
    ) {
        self.id = id
        self.startAt = startAt
        self.endAt = endAt
        self.appName = appName
        self.bundleId = bundleId
        self.windowTitle = windowTitle
        self.urlDomain = urlDomain
        self.documentPathHash = documentPathHash
        self.privacyLevel = privacyLevel
    }

    public var duration: TimeInterval { endAt.timeIntervalSince(startAt) }

    /// True when a privacy rule reduced what was recorded for this entry.
    public var isMasked: Bool { privacyLevel != .full }
}
