import Foundation
import WTCore

/// Converts raw snapshots into privacy-masked `ActivityEntry` values, merging
/// consecutive identical activity into a single entry (dedup/compress).
///
/// Stateful: keep one instance for the lifetime of a capture session and feed it
/// snapshots in order. Returns entries that are ready to persist.
public final class ActivityNormalizer {
    private let guardian: PrivacyGuard
    /// Max gap before two identical snapshots are treated as separate entries.
    private let maxMergeGap: TimeInterval

    private var pending: ActivityEntry?
    private var pendingKey: String?

    public init(privacyGuard: PrivacyGuard, maxMergeGap: TimeInterval = 30) {
        self.guardian = privacyGuard
        self.maxMergeGap = maxMergeGap
    }

    /// Feed a snapshot. Returns a completed entry to persist, if the previous
    /// activity just ended. Call `flush()` to emit the final pending entry.
    public func ingest(_ snapshot: RawActivitySnapshot) -> ActivityEntry? {
        // Idle time is not recorded as an activity entry.
        guard !snapshot.isIdle else {
            return flush()
        }

        let decision = guardian.evaluate(snapshot)
        guard decision.level != .excluded else {
            return flush()
        }

        let key = mergeKey(for: snapshot, decision: decision)
        let now = snapshot.timestamp

        // Extend the pending entry if it's the same activity and contiguous.
        if var current = pending, pendingKey == key,
           now.timeIntervalSince(current.endAt) <= maxMergeGap {
            current.endAt = now
            pending = current
            return nil
        }

        // Otherwise emit the old entry and start a new one.
        let completed = flush()
        pending = makeEntry(snapshot: snapshot, decision: decision, at: now)
        pendingKey = key
        return completed
    }

    /// Emits and clears the pending entry (e.g. on stop or when idle begins).
    @discardableResult
    public func flush() -> ActivityEntry? {
        defer { pending = nil; pendingKey = nil }
        return pending
    }

    // MARK: - Building

    private func makeEntry(snapshot: RawActivitySnapshot, decision: PrivacyGuard.Decision, at now: Date) -> ActivityEntry {
        ActivityEntry(
            startAt: now,
            endAt: now,
            appName: decision.keepAppIdentity ? snapshot.appName : nil,
            bundleId: decision.keepAppIdentity ? snapshot.bundleId : nil,
            windowTitle: decision.windowTitle,
            urlDomain: decision.urlDomain,
            documentPathHash: decision.documentPathHash,
            privacyLevel: decision.level
        )
    }

    private func mergeKey(for snapshot: RawActivitySnapshot, decision: PrivacyGuard.Decision) -> String {
        switch decision.level {
        case .timeOnly:
            return "timeOnly"
        default:
            return [
                snapshot.bundleId ?? "",
                decision.windowTitle ?? "",
                decision.urlDomain ?? ""
            ].joined(separator: "|")
        }
    }
}
