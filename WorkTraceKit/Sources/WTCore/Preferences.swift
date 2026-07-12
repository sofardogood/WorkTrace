import Foundation

/// Single-user preferences (one row in the MVP). Language fields are first-class
/// so bilingual behavior is data-driven, not hard-coded.
public struct UserPreferences: Codable, Sendable, Equatable {
    public var id: Int64?
    public var defaultUILanguage: AppLanguage
    public var defaultReportLanguage: ReportLanguage
    public var timezone: String
    public var locale: String
    public var currency: String
    /// Seconds of no input before the user is considered idle.
    public var idleThresholdSeconds: Int
    /// How often activity is sampled (spec target: 3–10s).
    public var samplingIntervalSeconds: Int
    /// Master switch for background activity capture.
    public var activityCaptureEnabled: Bool
    /// How many calendar days of activity/sessions to retain. `nil` == keep
    /// indefinitely. Defaults to a rolling 7 days.
    public var retentionDays: Int?
    /// When automatic retention cleanup last ran, so it runs at most once a day.
    public var lastCleanupAt: Date?

    public init(
        id: Int64? = nil,
        defaultUILanguage: AppLanguage = .system,
        defaultReportLanguage: ReportLanguage = .japanese,
        timezone: String = TimeZone.current.identifier,
        locale: String = Locale.current.identifier,
        currency: String = "JPY",
        idleThresholdSeconds: Int = 120,
        samplingIntervalSeconds: Int = 5,
        activityCaptureEnabled: Bool = true,
        retentionDays: Int? = RetentionPeriod.default.rawValue,
        lastCleanupAt: Date? = nil
    ) {
        self.id = id
        self.defaultUILanguage = defaultUILanguage
        self.defaultReportLanguage = defaultReportLanguage
        self.timezone = timezone
        self.locale = locale
        self.currency = currency
        self.idleThresholdSeconds = idleThresholdSeconds
        self.samplingIntervalSeconds = samplingIntervalSeconds
        self.activityCaptureEnabled = activityCaptureEnabled
        self.retentionDays = retentionDays
        self.lastCleanupAt = lastCleanupAt
    }

    /// The retention period as a typed value.
    public var retentionPeriod: RetentionPeriod {
        get { RetentionPeriod(days: retentionDays) }
        set { retentionDays = newValue.days }
    }
}
