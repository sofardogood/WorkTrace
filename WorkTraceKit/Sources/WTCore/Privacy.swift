import Foundation

public enum PrivacyMaskTargetType: String, Codable, Sendable, CaseIterable {
    case app
    case urlDomain = "url_domain"
    case windowTitle = "window_title"
    case timeRange = "time_range"
}

public enum PrivacyMaskAction: String, Codable, Sendable, CaseIterable {
    case exclude    // do not record at all
    case maskTitle  // keep app/domain, drop/hash the window title
    case timeOnly   // keep only the time span
}

/// A user-configured rule that limits or masks what gets recorded.
public struct PrivacyMask: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var id: Int64?
    public var targetType: PrivacyMaskTargetType
    /// Pattern to match (app name / bundle id / domain / title substring).
    public var pattern: String
    public var action: PrivacyMaskAction
    public var enabled: Bool

    public init(
        id: Int64? = nil,
        targetType: PrivacyMaskTargetType,
        pattern: String,
        action: PrivacyMaskAction,
        enabled: Bool = true
    ) {
        self.id = id
        self.targetType = targetType
        self.pattern = pattern
        self.action = action
        self.enabled = enabled
    }
}

/// Default sensitive-category patterns offered to the user during onboarding.
/// NOT auto-enabled — the user opts in. Presented as suggested masks.
public enum DefaultPrivacyCandidates {
    public static let suggestedAppPatterns: [String] = [
        "1Password", "Bitwarden", "KeePassXC",   // password managers
        "Banking", "銀行",                          // banking
        "Messages", "メッセージ", "Mail", "メール"    // private comms
    ]

    public static let suggestedDomainPatterns: [String] = [
        "bank", "paypal", "1password.com", "mail.google.com"
    ]
}
