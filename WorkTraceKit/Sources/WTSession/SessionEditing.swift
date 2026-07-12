import Foundation
import WTCore

/// Pure, storage-free operations for manually correcting recorded sessions.
/// Keeping these as value transforms makes them easy to test and lets the view
/// layer decide how to persist the results (insert / update / delete).
public enum SessionEditing {

    /// Splits a closed session at `date` into two contiguous sessions.
    ///
    /// - Returns: the shortened original (now ending at `date`) and a new
    ///   session covering `date`→original end, or `nil` if the session is still
    ///   open or `date` is not strictly inside the session's span.
    public static func split(_ session: Session, at date: Date) -> (left: Session, right: Session)? {
        guard let end = session.endAt else { return nil }
        guard date > session.startAt, date < end else { return nil }

        var left = session
        left.endAt = date

        // The right span is a brand-new record: drop the id so it inserts, and
        // carry over the classification the user already set on the original.
        let right = Session(
            taskId: session.taskId,
            startAt: date,
            endAt: end,
            source: session.source,
            confidence: session.confidence,
            memo: session.memo,
            billable: session.billable,
            rate: session.rate,
            reportVisible: session.reportVisible
        )
        return (left, right)
    }

    /// Merges two or more sessions into a single span.
    ///
    /// The earliest session (by start) is kept and extended to the latest end;
    /// its task, memo and billing flags win. The others should be deleted by the
    /// caller. Returns the merged session and the ids to delete, or `nil` if
    /// fewer than two sessions are supplied.
    public static func merge(_ sessions: [Session]) -> (merged: Session, deletedIds: [Int64])? {
        guard sessions.count >= 2 else { return nil }
        let ordered = sessions.sorted { $0.startAt < $1.startAt }
        var merged = ordered[0]

        // Latest known end wins; an open session keeps the merged span open.
        let anyOpen = ordered.contains { $0.endAt == nil }
        if anyOpen {
            merged.endAt = nil
        } else {
            merged.endAt = ordered.compactMap(\.endAt).max()
        }

        let deletedIds = ordered.dropFirst().compactMap(\.id)
        return (merged, deletedIds)
    }
}
