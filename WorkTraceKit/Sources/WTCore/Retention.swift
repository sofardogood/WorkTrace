import Foundation

/// How long automatically-captured activity and manual timer sessions are kept
/// before being purged. Local-first: purging frees disk and limits how far back
/// any observation can be reconstructed. The default is a rolling 7 calendar
/// days (today plus the previous 6).
public enum RetentionPeriod: Int, Codable, Sendable, CaseIterable, Identifiable {
    case sevenDays = 7
    case thirtyDays = 30
    case ninetyDays = 90
    case oneEightyDays = 180
    case oneYear = 365
    case indefinite = 0   // 0 == keep everything

    public var id: Int { rawValue }

    /// The product default: a rolling week.
    public static let `default`: RetentionPeriod = .sevenDays

    /// Number of calendar days retained, or `nil` when kept indefinitely.
    public var days: Int? { self == .indefinite ? nil : rawValue }

    /// Maps a stored day count (nil / non-positive == indefinite) back to a case.
    public init(days: Int?) {
        guard let days, days > 0 else { self = .indefinite; return }
        self = RetentionPeriod(rawValue: days) ?? .default
    }

    /// Start-of-day cutoff: entries starting before this are outside the window.
    /// For a 7-day period this retains today plus the previous 6 calendar days.
    /// Returns `nil` when the period is indefinite (nothing is ever purged).
    public func cutoff(now: Date = Date(), calendar: Calendar = .current) -> Date? {
        guard let days else { return nil }
        let startToday = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -(days - 1), to: startToday) ?? startToday
    }
}
