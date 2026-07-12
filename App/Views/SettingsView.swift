import SwiftUI
import AppKit
import UniformTypeIdentifiers
import WTCore
import WTObservation
import WTReporting
import WTStorage

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    @AppStorage("worktrace.hasOnboarded") private var hasOnboarded = false

    @State private var masks: [PrivacyMask] = []
    @State private var newPattern: String = ""
    @State private var newTarget: PrivacyMaskTargetType = .app
    @State private var newAction: PrivacyMaskAction = .exclude
    @State private var lastBackup: Date?
    @State private var pendingRestore: URL?
    @State private var error: AppError?
    @State private var retentionStatus: RetentionStatus?

    var body: some View {
        @Bindable var state = appState

        Form {
            // Language
            Section("settings.language") {
                Picker("settings.uiLanguage", selection: $state.preferences.defaultUILanguage) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(LocalizedStringKey(lang.displayNameKey)).tag(lang)
                    }
                }
                Picker("settings.reportLanguage", selection: $state.preferences.defaultReportLanguage) {
                    ForEach(ReportLanguage.allCases) { lang in
                        Text(LocalizedStringKey(lang.displayNameKey)).tag(lang)
                    }
                }
            }
            .onChange(of: state.preferences.defaultUILanguage) { applyPreferences() }
            .onChange(of: state.preferences.defaultReportLanguage) { applyPreferences() }

            // Capture
            Section("settings.capture") {
                Toggle("settings.captureEnabled", isOn: $state.preferences.activityCaptureEnabled)
                    .onChange(of: state.preferences.activityCaptureEnabled) { applyPreferencesAndRestart() }
                Stepper(value: $state.preferences.samplingIntervalSeconds, in: 3...60) {
                    Text("settings.samplingInterval") + Text(": \(state.preferences.samplingIntervalSeconds)")
                }
                .onChange(of: state.preferences.samplingIntervalSeconds) { applyPreferencesAndRestart() }
                Stepper(value: $state.preferences.idleThresholdSeconds, in: 30...600, step: 30) {
                    Text("settings.idleThreshold") + Text(": \(state.preferences.idleThresholdSeconds)")
                }
                .onChange(of: state.preferences.idleThresholdSeconds) { applyPreferences() }
            }

            // Retention — how long activity logs and manual-timer sessions are
            // kept before they are automatically purged.
            Section("settings.retention") {
                Picker("settings.retentionPeriod", selection: $state.preferences.retentionPeriod) {
                    ForEach(RetentionPeriod.allCases) { period in
                        Text(retentionLabel(period)).tag(period)
                    }
                }
                .onChange(of: state.preferences.retentionPeriod) { applyRetentionChange() }

                Text("settings.retentionHint").font(.caption).foregroundStyle(.secondary)

                if let status = retentionStatus {
                    LabeledContent("settings.retentionOldest") {
                        Text(status.oldestRetainedActivity
                                .map { $0.formatted(date: .abbreviated, time: .omitted) }
                             ?? String(localized: "settings.retentionNone"))
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("settings.retentionCount") {
                        Text("\(status.storedEntryCount)").foregroundStyle(.secondary)
                    }
                    LabeledContent("settings.retentionDbSize") {
                        Text(status.databaseSizeBytes.map(Self.formatBytes)
                             ?? String(localized: "settings.retentionNone"))
                            .foregroundStyle(.secondary)
                    }
                    LabeledContent("settings.retentionNextCleanup") {
                        Text(status.nextScheduledCleanup
                                .map { $0.formatted(date: .abbreviated, time: .shortened) }
                             ?? String(localized: "settings.retentionNever"))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Accessibility status
            Section("settings.accessibility") {
                Label {
                    Text(appState.accessibilityGranted ? "settings.accessibilityGranted" : "settings.accessibilityMissing")
                } icon: {
                    Image(systemName: appState.accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(appState.accessibilityGranted ? .green : .orange)
                }
                .font(.caption)
                if !appState.accessibilityGranted {
                    Button("settings.requestPermission") {
                        requestAccessibilityPermission()
                        appState.refreshAccessibility()
                    }
                }
            }

            // Privacy zones
            Section("settings.privacy") {
                Text("settings.privacyHint").font(.caption).foregroundStyle(.secondary)
                ForEach(masks) { mask in
                    HStack {
                        Text(mask.pattern)
                        Spacer()
                        Text(actionLabel(mask.action)).font(.caption).foregroundStyle(.secondary)
                        Button(role: .destructive) {
                            if let id = mask.id { try? appState.masksRepo.delete(id: id); reloadMasks() }
                        } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                    }
                }
                HStack {
                    Picker("", selection: $newTarget) {
                        Text("action.app").tag(PrivacyMaskTargetType.app)
                        Text("action.domain").tag(PrivacyMaskTargetType.urlDomain)
                    }
                    .labelsHidden().fixedSize()
                    TextField("settings.maskPattern", text: $newPattern)
                        .textFieldStyle(.roundedBorder)
                    Picker("", selection: $newAction) {
                        Text("action.exclude").tag(PrivacyMaskAction.exclude)
                        Text("action.maskTitle").tag(PrivacyMaskAction.maskTitle)
                        Text("action.timeOnly").tag(PrivacyMaskAction.timeOnly)
                    }
                    .labelsHidden().fixedSize()
                    Button("common.add", action: addMask)
                        .disabled(newPattern.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            // Data
            Section("settings.data") {
                Button("settings.exportCSV", action: exportTodayCSV)
            }

            // Backup
            Section("settings.backup") {
                Text("settings.backupHint").font(.caption).foregroundStyle(.secondary)
                LabeledContent("settings.lastBackup") {
                    Text(lastBackup.map { $0.formatted(date: .abbreviated, time: .shortened) }
                         ?? String(localized: "settings.lastBackupNone"))
                        .foregroundStyle(.secondary)
                }
                Button("settings.backupNow", action: backupNow)
                Button("settings.restoreBackup", action: chooseRestore)
            }

            // Help
            Section("settings.help") {
                Button("settings.showIntro") {
                    hasOnboarded = false
                    openWindow(id: "onboarding")
                }
            }

            // About — surfaces the exact build so QA notes and bug reports can
            // reference it. Selectable so the value can be copied into a report.
            Section("settings.about") {
                LabeledContent("settings.version") {
                    Text(Self.versionString).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 560)
        .task {
            reloadMasks()
            reloadBackups()
            refreshRetentionStatus()
            appState.refreshAccessibility()
        }
        .confirmationDialog(
            "settings.restoreConfirmTitle",
            isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }),
            titleVisibility: .visible,
            presenting: pendingRestore
        ) { _ in
            Button("settings.restoreConfirmButton", role: .destructive, action: performRestore)
            Button("common.cancel", role: .cancel) { pendingRestore = nil }
        } message: { url in
            // Name the exact file, then spell out that this replaces the live
            // database and quits the app so the restore loads on next launch.
            Text(url.lastPathComponent) + Text("\n\n") + Text("settings.restoreConfirmBody")
        }
        .errorAlert($error)
    }

    // MARK: - About

    /// "0.1.0 (1)" — marketing version and build number from the bundle.
    private static var versionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    // MARK: - Actions

    private func applyPreferences() {
        appState.savePreferences()
    }

    private func applyPreferencesAndRestart() {
        appState.savePreferences()
        appState.restartCaptureIfNeeded()
    }

    /// Persist the new retention window and apply it immediately so a shortened
    /// window purges old logs now rather than waiting for the next daily sweep.
    private func applyRetentionChange() {
        appState.savePreferences()
        appState.runRetentionCleanupIfNeeded(force: true)
        reloadBackups()
        refreshRetentionStatus()
    }

    private func refreshRetentionStatus() {
        retentionStatus = appState.retentionStatus()
    }

    private func retentionLabel(_ period: RetentionPeriod) -> LocalizedStringKey {
        switch period {
        case .sevenDays:    return "retention.7days"
        case .thirtyDays:   return "retention.30days"
        case .ninetyDays:   return "retention.90days"
        case .oneEightyDays: return "retention.180days"
        case .oneYear:      return "retention.1year"
        case .indefinite:   return "retention.indefinite"
        }
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    private func reloadMasks() {
        masks = (try? appState.masksRepo.all()) ?? []
    }

    private func reloadBackups() {
        lastBackup = (try? appState.backups.list())?.first?.createdAt
    }

    private func backupNow() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "sqlite") ?? .data]
        panel.nameFieldStringValue = "worktrace-backup.sqlite"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try appState.backups.backup(to: url)
            try? appState.audit.log(action: AuditAction.dataExported, targetType: "backup",
                                    targetId: url.lastPathComponent)
        } catch {
            self.error = .backupFailed
        }
    }

    private func chooseRestore() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType(filenameExtension: "sqlite") ?? .data]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.directoryURL = appState.backups.directory
        guard panel.runModal() == .OK, let url = panel.url else { return }
        pendingRestore = url
    }

    private func performRestore() {
        guard let url = pendingRestore else { return }
        pendingRestore = nil
        do {
            try appState.backups.restore(from: url)
            try? appState.audit.log(action: AuditAction.dataRestored, targetType: "backup",
                                    targetId: url.lastPathComponent)
            // The DB is already open; quit so the restored file loads on relaunch.
            NSApplication.shared.terminate(nil)
        } catch let error as BackupError {
            // A validation failure means the chosen file is not a usable backup;
            // the live database has not been touched. Surface exactly why.
            switch error {
            case .fileMissing:        self.error = .backupFileMissing
            case .notReadable:        self.error = .backupNotReadable
            case .notSQLite:          self.error = .backupNotSQLite
            case .notWorkTraceBackup: self.error = .backupNotWorkTrace
            case .noDatabaseFile:     self.error = .restoreFailed
            }
        } catch {
            self.error = .restoreFailed
        }
    }

    private func addMask() {
        let pattern = newPattern.trimmingCharacters(in: .whitespaces)
        guard !pattern.isEmpty else { return }
        _ = try? appState.masksRepo.save(
            PrivacyMask(targetType: newTarget, pattern: pattern, action: newAction)
        )
        newPattern = ""
        reloadMasks()
        appState.restartCaptureIfNeeded()
    }

    private func actionLabel(_ action: PrivacyMaskAction) -> LocalizedStringKey {
        switch action {
        case .exclude:   return "action.exclude"
        case .maskTitle: return "action.maskTitle"
        case .timeOnly:  return "action.timeOnly"
        }
    }

    private func exportTodayCSV() {
        let (start, end) = DayHelpers.dayBounds(for: Date())
        let sessions = (try? appState.sessions.sessions(from: start, to: end)) ?? []
        let tasks = (try? appState.tasks.all(includeArchived: true)) ?? []
        let projects = (try? appState.projects.all()) ?? []
        let taskNames = DayHelpers.taskNameMap(tasks)
        let projectNames = DayHelpers.projectNameByTask(tasks, projects)

        let rows = sessions.map { session in
            SessionExportRow(
                session: session,
                taskName: session.taskId.flatMap { taskNames[$0] },
                projectName: session.taskId.flatMap { projectNames[$0] }
            )
        }
        let csv = CSVExporter().export(rows, language: appState.preferences.defaultReportLanguage)

        let panel = NSSavePanel()
        panel.nameFieldStringValue = "worktrace-\(Int(start.timeIntervalSince1970)).csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            try? appState.audit.log(action: AuditAction.dataExported, targetType: "csv",
                                    targetId: url.lastPathComponent)
        } catch {
            self.error = .exportFailed
        }
    }
}
