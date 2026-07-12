import Foundation
import Observation
import AppKit
import WTCore
import WTStorage
import WTObservation
import WTNormalization
import WTSession

/// Composition root. Owns the database, repositories, timer engine and the
/// observation→normalization→storage pipeline, and exposes them to the UI.
///
/// This is the ONLY place the layers are wired together; each layer stays
/// unaware of the others beyond its declared dependencies.
@MainActor
@Observable
public final class AppState {
    // Storage
    public let database: AppDatabase
    public let projects: ProjectRepository
    public let tasks: TaskRepository
    public let sessions: SessionRepository
    public let activity: ActivityRepository
    public let preferencesRepo: PreferencesRepository
    public let masksRepo: PrivacyMaskRepository
    public let audit: AuditLogWriter
    public let backups: BackupManager

    // Engines / services
    public let timer: TimerEngine
    public let localization: LocalizationManager
    public let retention: RetentionCleaner

    // Live state
    public var preferences: UserPreferences
    public var accessibilityGranted: Bool = false
    /// Result of the most recent automatic retention cleanup, for the UI.
    public var lastCleanupResult: RetentionResult?

    private let observer: WorkspaceActivityObserver
    private var normalizer: ActivityNormalizer?
    private var activationObserver: (any NSObjectProtocol)?

    public init() {
        let db = try! AppDatabase(path: Self.databasePath())
        self.database = db
        self.projects = ProjectRepository(db)
        self.tasks = TaskRepository(db)
        self.sessions = SessionRepository(db)
        self.activity = ActivityRepository(db)
        self.preferencesRepo = PreferencesRepository(db)
        self.masksRepo = PrivacyMaskRepository(db)
        self.audit = AuditLogWriter(db)
        self.backups = BackupManager(database: db, directory: Self.backupDirectory())

        let prefs = (try? preferencesRepo.load()) ?? UserPreferences()
        self.preferences = prefs

        self.timer = TimerEngine(sessions: sessions, audit: audit)
        self.retention = RetentionCleaner(activity: activity, sessions: sessions)
        self.localization = LocalizationManager(language: prefs.defaultUILanguage)
        self.observer = WorkspaceActivityObserver(
            interval: TimeInterval(prefs.samplingIntervalSeconds),
            idleThreshold: TimeInterval(prefs.idleThresholdSeconds)
        )
    }

    // MARK: - Lifecycle

    /// Call once on launch.
    public func bootstrap() {
        try? timer.recoverOpenSession()
        refreshAccessibility()
        observeActivation()
        // Local, once-a-day snapshot so recorded work survives DB corruption.
        try? backups.automaticBackupIfNeeded()
        runRetentionCleanupIfNeeded()
        if preferences.activityCaptureEnabled {
            startCapture()
        }
    }

    // MARK: - Retention

    /// Enforces the configured retention window (default 7 days). Runs at most
    /// once per calendar day. A fresh backup is guaranteed BEFORE any deletion,
    /// and the outcome is written to the audit log. Only activity entries and
    /// closed manual-timer sessions are purged — projects, tasks, settings,
    /// privacy masks and audit history are always kept.
    public func runRetentionCleanupIfNeeded(now: Date = Date(), calendar: Calendar = .current, force: Bool = false) {
        let period = preferences.retentionPeriod
        guard period != .indefinite else { return }

        // Skip if we already cleaned up today, unless the caller forces a sweep
        // (e.g. the user just shortened the retention window in Settings).
        if !force,
           let last = preferences.lastCleanupAt,
           calendar.isDate(last, inSameDayAs: now) {
            return
        }

        // Guarantee a snapshot exists before we delete anything.
        try? backups.automaticBackupIfNeeded(now: now, calendar: calendar)

        guard let result = try? retention.apply(period, now: now, calendar: calendar) else {
            // Nothing to do (or the period has no cutoff); still record that we ran.
            preferences.lastCleanupAt = now
            savePreferences()
            return
        }

        lastCleanupResult = result
        preferences.lastCleanupAt = now
        savePreferences()

        let detail = """
        {"cutoff":"\(ISO8601DateFormatter().string(from: result.cutoff))",\
        "deletedActivityEntries":\(result.deletedActivityEntries),\
        "deletedSessions":\(result.deletedSessions),\
        "totalDeleted":\(result.totalDeleted),\
        "retentionDays":\(period.days ?? 0)}
        """
        try? audit.log(action: "retention.cleanup", detailJSON: detail)
    }

    /// Diagnostics for the Settings screen: what is retained, how much, and when
    /// the next automatic cleanup will occur.
    public func retentionStatus(now: Date = Date(), calendar: Calendar = .current) -> RetentionStatus {
        let period = preferences.retentionPeriod
        let oldestActivity = try? activity.earliestStart()
        let entryCount = (try? activity.count()) ?? 0
        let dbSize = databaseSizeBytes()
        let latestBackup = (try? backups.list())?.first?.createdAt
        let nextCleanup: Date? = {
            guard period != .indefinite else { return nil }
            if let last = preferences.lastCleanupAt {
                // Already ran today → next chance is start of tomorrow.
                if calendar.isDate(last, inSameDayAs: now) {
                    let startTomorrow = calendar.date(
                        byAdding: .day, value: 1, to: calendar.startOfDay(for: now)
                    )
                    return startTomorrow
                }
            }
            return now   // due now / on next launch
        }()
        return RetentionStatus(
            period: period,
            oldestRetainedActivity: oldestActivity,
            storedEntryCount: entryCount,
            databaseSizeBytes: dbSize,
            latestBackupAt: latestBackup,
            nextScheduledCleanup: nextCleanup
        )
    }

    private func databaseSizeBytes() -> Int64? {
        guard let path = database.path else { return nil }
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return (attrs?[.size] as? NSNumber)?.int64Value
    }

    public func refreshAccessibility() {
        accessibilityGranted = hasAccessibilityPermission()
    }

    /// The Accessibility grant is toggled in System Settings while WorkTrace is
    /// already running, so re-check whenever the app is brought back to the
    /// front. This keeps the permission state (and onboarding UI) accurate
    /// without a relaunch.
    private func observeActivation() {
        guard activationObserver == nil else { return }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshAccessibility() }
        }
    }

    // MARK: - Capture pipeline

    public func startCapture() {
        let masks = (try? masksRepo.enabled()) ?? []
        let normalizer = ActivityNormalizer(privacyGuard: PrivacyGuard(masks: masks))
        self.normalizer = normalizer

        observer.start { [weak self] snapshot in
            // PrivacyGuard runs inside `ingest`, BEFORE we ever persist.
            guard let self, let entry = normalizer.ingest(snapshot) else { return }
            _ = try? self.activity.save(entry)
        }
    }

    public func stopCapture() {
        observer.stop()
        if let entry = normalizer?.flush() {
            _ = try? activity.save(entry)
        }
        normalizer = nil
    }

    /// Rebuilds the capture pipeline (e.g. after masks or interval change).
    public func restartCaptureIfNeeded() {
        stopCapture()
        if preferences.activityCaptureEnabled {
            startCapture()
        }
    }

    // MARK: - Preferences

    public func savePreferences() {
        preferences = (try? preferencesRepo.save(preferences)) ?? preferences
        localization.language = preferences.defaultUILanguage
    }

    // MARK: - Paths

    private static func supportDirectory() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("WorkTrace", isDirectory: true)
        try? fm.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static func databasePath() -> String {
        supportDirectory().appendingPathComponent("worktrace.sqlite").path
    }

    private static func backupDirectory() -> URL {
        supportDirectory().appendingPathComponent("Backups", isDirectory: true)
    }
}
