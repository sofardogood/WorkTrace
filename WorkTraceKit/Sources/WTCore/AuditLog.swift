import Foundation

/// Record of security-relevant actions: deletions, exports, external sends,
/// AI generation. Required by the spec's auditability non-functional requirement.
public struct AuditLog: Codable, Sendable, Identifiable, Equatable {
    public var id: Int64?
    public var action: String
    public var targetType: String?
    public var targetId: String?
    public var createdAt: Date
    public var detailJSON: String?

    public init(
        id: Int64? = nil,
        action: String,
        targetType: String? = nil,
        targetId: String? = nil,
        createdAt: Date = Date(),
        detailJSON: String? = nil
    ) {
        self.id = id
        self.action = action
        self.targetType = targetType
        self.targetId = targetId
        self.createdAt = createdAt
        self.detailJSON = detailJSON
    }
}

/// Well-known audit action names.
public enum AuditAction {
    public static let sessionDeleted = "session.deleted"
    public static let sessionSplit = "session.split"
    public static let sessionMerged = "session.merged"
    public static let activityDeleted = "activity.deleted"
    public static let dataExported = "data.exported"
    public static let dataRestored = "data.restored"
    public static let backupCreated = "backup.created"
    public static let reportGenerated = "report.generated"
    public static let logsPurged = "logs.purged"
}
