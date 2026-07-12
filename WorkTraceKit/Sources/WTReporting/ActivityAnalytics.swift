import Foundation
import WTCore

/// Aggregate statistics for one set of activity entries (typically one day).
public struct ActivityStats: Sendable, Equatable {
    /// Recorded (active) work time; idle gaps and any excluded app are removed.
    public let activeTotal: TimeInterval
    /// Time spent idle: gaps between activity of at least the idle threshold.
    public let idleTotal: TimeInterval
    /// Number of times the foreground app changed between work entries.
    public let appSwitches: Int
    public let topApp: ActivityTotal?
    public let topWindow: ActivityTotal?
    /// Number of work entries counted (after exclusion).
    public let entryCount: Int

    public static let empty = ActivityStats(
        activeTotal: 0, idleTotal: 0, appSwitches: 0,
        topApp: nil, topWindow: nil, entryCount: 0
    )

    public init(
        activeTotal: TimeInterval,
        idleTotal: TimeInterval,
        appSwitches: Int,
        topApp: ActivityTotal?,
        topWindow: ActivityTotal?,
        entryCount: Int
    ) {
        self.activeTotal = activeTotal
        self.idleTotal = idleTotal
        self.appSwitches = appSwitches
        self.topApp = topApp
        self.topWindow = topWindow
        self.entryCount = entryCount
    }
}

/// One calendar day's worth of activity, keyed by its start-of-day date.
public struct DayActivity: Sendable, Equatable, Identifiable {
    public let date: Date            // start of day
    public let stats: ActivityStats
    public var id: Date { date }

    public init(date: Date, stats: ActivityStats) {
        self.date = date
        self.stats = stats
    }
}

/// A multi-day (e.g. 7-day) summary for the Trends / Overview views.
public struct PeriodSummary: Sendable, Equatable {
    public let days: [DayActivity]          // ascending, one per calendar day
    public let activeTotal: TimeInterval
    public let idleTotal: TimeInterval
    public let dailyAverageActive: TimeInterval
    public let mostUsedApp: ActivityTotal?
    public let mostUsedWindow: ActivityTotal?
    public let totalAppSwitches: Int

    public init(
        days: [DayActivity],
        activeTotal: TimeInterval,
        idleTotal: TimeInterval,
        dailyAverageActive: TimeInterval,
        mostUsedApp: ActivityTotal?,
        mostUsedWindow: ActivityTotal?,
        totalAppSwitches: Int
    ) {
        self.days = days
        self.activeTotal = activeTotal
        self.idleTotal = idleTotal
        self.dailyAverageActive = dailyAverageActive
        self.mostUsedApp = mostUsedApp
        self.mostUsedWindow = mostUsedWindow
        self.totalAppSwitches = totalAppSwitches
    }
}

/// An idle gap between two activity entries.
public struct IdleGap: Sendable, Equatable {
    public let start: Date
    public let end: Date
    public var duration: TimeInterval { end.timeIntervalSince(start) }
    public init(start: Date, end: Date) { self.start = start; self.end = end }
}

/// Pure, deterministic analytics used by the Activity screen's purpose-based
/// views (Overview / Applications / Windows / Timeline / Trends). All idle,
/// active, switch and ranking maths lives here so it can be unit-tested without
/// any SwiftUI. `excludingBundleId` removes WorkTrace's own foreground time from
/// work totals/rankings while idle is still measured across all entries.
public enum ActivityAnalytics {
    /// Idle gaps of at least `idleThreshold` between consecutive entries.
    public static func idleGaps(_ entries: [ActivityEntry], idleThreshold: TimeInterval) -> [IdleGap] {
        let sorted = entries.sorted { $0.startAt < $1.startAt }
        var gaps: [IdleGap] = []
        var previousEnd: Date?
        for entry in sorted {
            if let previousEnd, entry.startAt.timeIntervalSince(previousEnd) >= idleThreshold {
                gaps.append(IdleGap(start: previousEnd, end: entry.startAt))
            }
            previousEnd = entry.endAt
        }
        return gaps
    }

    /// Aggregate stats for a set of entries.
    public static func stats(
        for entries: [ActivityEntry],
        idleThreshold: TimeInterval,
        excludingBundleId: String? = nil
    ) -> ActivityStats {
        let sorted = entries.sorted { $0.startAt < $1.startAt }
        // Idle spans all entries (including any excluded app) so the timeline is honest.
        let idle = idleGaps(sorted, idleThreshold: idleThreshold).reduce(0) { $0 + $1.duration }

        let work = excludingBundleId.map { id in sorted.filter { $0.bundleId != id } } ?? sorted
        let active = work.reduce(0) { $0 + $1.duration }

        var switches = 0
        var previousApp: String?
        for entry in work {
            let app = entry.appName ?? ""
            if let previousApp, previousApp != app { switches += 1 }
            previousApp = app
        }

        return ActivityStats(
            activeTotal: active,
            idleTotal: idle,
            appSwitches: switches,
            topApp: ActivitySummarizer.byApp(work).first,
            topWindow: ActivitySummarizer.byWindowTitle(work).first,
            entryCount: work.count
        )
    }

    /// Builds a `dayCount`-day summary ending on the calendar day of `now`.
    public static func period(
        entries: [ActivityEntry],
        days dayCount: Int,
        endingOn now: Date = Date(),
        idleThreshold: TimeInterval,
        excludingBundleId: String? = nil,
        calendar: Calendar = .current
    ) -> PeriodSummary {
        let startToday = calendar.startOfDay(for: now)
        var days: [DayActivity] = []
        for offset in stride(from: dayCount - 1, through: 0, by: -1) {
            let dayStart = calendar.date(byAdding: .day, value: -offset, to: startToday) ?? startToday
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let dayEntries = entries.filter { $0.startAt >= dayStart && $0.startAt < dayEnd }
            days.append(DayActivity(
                date: dayStart,
                stats: stats(for: dayEntries, idleThreshold: idleThreshold, excludingBundleId: excludingBundleId)
            ))
        }

        let periodStart = calendar.date(byAdding: .day, value: -(dayCount - 1), to: startToday) ?? startToday
        let periodEnd = calendar.date(byAdding: .day, value: 1, to: startToday) ?? startToday
        let inRange = entries.filter { $0.startAt >= periodStart && $0.startAt < periodEnd }
        let work = excludingBundleId.map { id in inRange.filter { $0.bundleId != id } } ?? inRange

        let activeTotal = days.reduce(0) { $0 + $1.stats.activeTotal }
        let idleTotal = days.reduce(0) { $0 + $1.stats.idleTotal }
        let avg = dayCount > 0 ? activeTotal / Double(dayCount) : 0

        return PeriodSummary(
            days: days,
            activeTotal: activeTotal,
            idleTotal: idleTotal,
            dailyAverageActive: avg,
            mostUsedApp: ActivitySummarizer.byApp(work).first,
            mostUsedWindow: ActivitySummarizer.byWindowTitle(work).first,
            totalAppSwitches: days.reduce(0) { $0 + $1.stats.appSwitches }
        )
    }
}
