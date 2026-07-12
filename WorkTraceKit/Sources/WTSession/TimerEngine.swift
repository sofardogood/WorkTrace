import Foundation
import Observation
import WTCore
import WTStorage

/// State of the manual timer.
public enum TimerState: Equatable, Sendable {
    case idle
    case running(session: Session)
    case paused(taskId: Int64?, memo: String?)
}

/// Manual timer state machine. Persists each work span as a `Session` so the
/// timeline shows real, editable records and crashes never lose the current
/// span. Pause/resume is modeled as ending the current span and starting a new
/// one for the same task, which keeps the `Session` model simple and honest.
@MainActor
@Observable
public final class TimerEngine {
    public private(set) var state: TimerState = .idle

    private let sessions: SessionRepository
    private let audit: AuditLogWriter

    public init(sessions: SessionRepository, audit: AuditLogWriter) {
        self.sessions = sessions
        self.audit = audit
    }

    public var currentSession: Session? {
        if case .running(let session) = state { return session }
        return nil
    }

    public var isRunning: Bool {
        if case .running = state { return true }
        return false
    }

    public var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }

    /// Starts a new span for the given task. No-op if already running.
    public func start(taskId: Int64?, memo: String? = nil) throws {
        if case .running = state { return }
        var session = Session(
            taskId: taskId,
            startAt: Date(),
            source: .manual,
            memo: memo
        )
        session = try sessions.save(session)
        state = .running(session: session)
    }

    /// Ends the current span but remembers the task, so it can be resumed.
    public func pause() throws {
        guard case .running(var session) = state else { return }
        session.endAt = Date()
        session = try sessions.save(session)
        state = .paused(taskId: session.taskId, memo: session.memo)
    }

    public func resume() throws {
        guard case .paused(let taskId, let memo) = state else { return }
        state = .idle
        try start(taskId: taskId, memo: memo)
    }

    /// Ends the current span and returns to idle.
    public func stop() throws {
        if case .running(var session) = state {
            session.endAt = Date()
            _ = try sessions.save(session)
        }
        state = .idle
    }

    /// Updates the memo on the running span.
    public func updateMemo(_ memo: String) throws {
        guard case .running(var session) = state else { return }
        session.memo = memo
        session = try sessions.save(session)
        state = .running(session: session)
    }

    /// Call on launch: if a session was left open by a crash, re-attach to it
    /// instead of losing the time.
    public func recoverOpenSession() throws {
        guard case .idle = state else { return }
        if let open = try sessions.openSession() {
            state = .running(session: open)
        }
    }
}
