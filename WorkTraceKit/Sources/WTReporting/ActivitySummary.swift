import Foundation
import WTCore

/// One aggregated bucket of activity time (e.g. all time in "Xcode", or all
/// time whose window title was "Inbox — Mail").
public struct ActivityTotal: Sendable, Equatable, Identifiable {
    /// The grouping value shown to the user (app name or window title). A `nil`
    /// underlying value is surfaced as an empty string and labelled by the UI.
    public let label: String
    public let total: TimeInterval
    /// Number of entries merged into this bucket.
    public let count: Int

    public var id: String { label }

    public init(label: String, total: TimeInterval, count: Int) {
        self.label = label
        self.total = total
        self.count = count
    }
}

/// One window/screen usage bucket for the "Windows and Screens" view: a readable
/// window title, the app it was most associated with, and total time. A masked
/// or omitted title collapses into the empty-string bucket (`isMasked == true`);
/// masked titles are NEVER reconstructed — the UI shows a generic indicator.
public struct WindowUsage: Sendable, Equatable, Identifiable {
    /// Readable window title; empty string means masked/omitted.
    public let title: String
    /// App that contributed the most time under this title, if known.
    public let appName: String?
    public let total: TimeInterval
    public let count: Int

    public var id: String { title }
    public var isMasked: Bool { title.isEmpty }

    public init(title: String, appName: String?, total: TimeInterval, count: Int) {
        self.title = title
        self.appName = appName
        self.total = total
        self.count = count
    }
}

/// Pure aggregation over a day's activity entries. Produces the "App Usage" and
/// "Window / Screen Usage" summaries, sorted by total time descending. Entries
/// whose grouping value is missing (unknown app, or a masked/omitted title) are
/// collected under a single bucket keyed by the empty string so the UI can label
/// it ("Unknown" / "Private").
public enum ActivitySummarizer {
    /// Total time per app name.
    public static func byApp(_ entries: [ActivityEntry]) -> [ActivityTotal] {
        aggregate(entries) { $0.appName }
    }

    /// Total time per readable window title. Masked entries (no title) fall into
    /// the empty-string bucket.
    public static func byWindowTitle(_ entries: [ActivityEntry]) -> [ActivityTotal] {
        aggregate(entries) { $0.windowTitle }
    }

    /// Total time per readable window title, each carrying the app that
    /// contributed the most time under that title (for the Windows view).
    public static func byWindow(_ entries: [ActivityEntry]) -> [WindowUsage] {
        var totals: [String: (total: TimeInterval, count: Int, apps: [String: TimeInterval])] = [:]
        for entry in entries {
            let title = entry.windowTitle ?? ""
            var bucket = totals[title] ?? (0, 0, [:])
            bucket.total += entry.duration
            bucket.count += 1
            if let app = entry.appName {
                bucket.apps[app, default: 0] += entry.duration
            }
            totals[title] = bucket
        }
        return totals.map { title, value in
            let topApp = value.apps.max { a, b in
                a.value != b.value ? a.value < b.value : a.key > b.key
            }?.key
            return WindowUsage(title: title, appName: topApp, total: value.total, count: value.count)
        }
        .sorted { $0.total != $1.total ? $0.total > $1.total : $0.title < $1.title }
    }

    private static func aggregate(
        _ entries: [ActivityEntry],
        key: (ActivityEntry) -> String?
    ) -> [ActivityTotal] {
        var totals: [String: (total: TimeInterval, count: Int)] = [:]
        for entry in entries {
            let bucket = key(entry) ?? ""
            let current = totals[bucket] ?? (0, 0)
            totals[bucket] = (current.total + entry.duration, current.count + 1)
        }
        return totals
            .map { ActivityTotal(label: $0.key, total: $0.value.total, count: $0.value.count) }
            // Largest first; break ties by label so ordering is stable.
            .sorted { $0.total != $1.total ? $0.total > $1.total : $0.label < $1.label }
    }
}
