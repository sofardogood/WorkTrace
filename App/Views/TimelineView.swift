import SwiftUI
import UniformTypeIdentifiers
import WTCore
import WTReporting
import WTSession

struct DailyTimelineView: View {
    @Environment(AppState.self) private var appState

    @State private var sessions: [Session] = []
    @State private var tasks: [WorkTask] = []
    @State private var projects: [Project] = []
    @State private var editingMemo: Session?
    @State private var memoDraft: String = ""
    @State private var reportText: String?
    @State private var splitting: Session?
    @State private var splitMinutes: Double = 1
    @State private var pendingMerge: MergePair?
    @State private var error: AppError?

    /// A pair of adjacent sessions awaiting merge confirmation.
    private struct MergePair: Identifiable {
        let earlier: Session
        let later: Session
        var id: Int64 { earlier.id ?? 0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if sessions.isEmpty {
                ContentUnavailableView("timeline.empty", systemImage: "calendar")
                    .frame(maxHeight: .infinity)
            } else {
                List {
                    ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                        row(session, next: index + 1 < sessions.count ? sessions[index + 1] : nil)
                    }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 480)
        .task { reload() }
        .sheet(item: $editingMemo) { session in
            memoEditor(session)
        }
        .sheet(item: $splitting) { session in
            splitEditor(session)
        }
        .sheet(isPresented: Binding(get: { reportText != nil }, set: { if !$0 { reportText = nil } })) {
            reportSheet
        }
        .confirmationDialog(
            "timeline.mergeConfirmTitle",
            isPresented: Binding(get: { pendingMerge != nil }, set: { if !$0 { pendingMerge = nil } }),
            titleVisibility: .visible,
            presenting: pendingMerge
        ) { pair in
            Button("timeline.mergeConfirmButton") { performMerge(pair) }
            Button("common.cancel", role: .cancel) { pendingMerge = nil }
        } message: { _ in
            Text("timeline.mergeConfirmBody")
        }
        .errorAlert($error)
    }

    private var header: some View {
        HStack {
            Text("timeline.today").font(.title2).bold()
            Spacer()
            Text("timeline.total") + Text(": \(DayHelpers.hms(totalDuration))")
            Button("timeline.generateReport", action: generateReport)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private func row(_ session: Session, next: Session?) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(taskName(session.taskId)).font(.headline)
                Text("\(DayHelpers.time(session.startAt)) – \(session.isOpen ? String(localized: "timeline.running") : DayHelpers.time(session.endAt))")
                    .font(.caption).foregroundStyle(.secondary)
                if let memo = session.memo, !memo.isEmpty {
                    Text(memo).font(.caption)
                }
            }
            Spacer()
            Text(DayHelpers.hms(session.duration)).monospacedDigit()

            Menu {
                Menu("timeline.reassign") {
                    Button("menu.noTask") { reassign(session, to: nil) }
                    ForEach(tasks) { task in
                        Button(task.name) { reassign(session, to: task.id) }
                    }
                }
                Button("timeline.editMemo") {
                    memoDraft = session.memo ?? ""
                    editingMemo = session
                }
                if session.endAt != nil, session.duration >= 120 {
                    Button("timeline.split") {
                        splitMinutes = (session.duration / 60 / 2).rounded()
                        splitting = session
                    }
                }
                if let next {
                    Button("timeline.mergeNext") {
                        pendingMerge = MergePair(earlier: session, later: next)
                    }
                }
                Button("timeline.delete", role: .destructive) { delete(session) }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.vertical, 4)
    }

    private func memoEditor(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("timeline.editMemo").font(.headline)
            TextEditor(text: $memoDraft).frame(height: 120).border(.quaternary)
            HStack {
                Spacer()
                Button("common.cancel") { editingMemo = nil }
                Button("common.save") {
                    var updated = session
                    updated.memo = memoDraft
                    _ = try? appState.sessions.save(updated)
                    editingMemo = nil
                    reload()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 360)
    }

    private func splitEditor(_ session: Session) -> some View {
        let totalMinutes = max(1, (session.duration / 60).rounded())
        return VStack(alignment: .leading, spacing: 12) {
            Text("timeline.splitTitle").font(.headline)
            Text("\(DayHelpers.time(session.startAt)) – \(DayHelpers.time(session.endAt))")
                .font(.caption).foregroundStyle(.secondary)
            Stepper(value: $splitMinutes, in: 1...(totalMinutes - 1), step: 1) {
                Text("timeline.splitAt") + Text(": \(Int(splitMinutes))")
            }
            HStack {
                Spacer()
                Button("common.cancel") { splitting = nil }
                Button("timeline.splitConfirm") { performSplit(session) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 360)
    }

    private var reportSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("timeline.generateReport").font(.headline)
            ScrollView {
                Text(reportText ?? "")
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack {
                Spacer()
                Button("common.done") { reportText = nil }.buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 460, height: 480)
    }

    // MARK: - Data

    private var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }

    private func reload() {
        let (start, end) = DayHelpers.dayBounds(for: Date())
        sessions = (try? appState.sessions.sessions(from: start, to: end)) ?? []
        tasks = (try? appState.tasks.all(includeArchived: true)) ?? []
        projects = (try? appState.projects.all()) ?? []
    }

    private func taskName(_ id: Int64?) -> String {
        guard let id, let t = tasks.first(where: { $0.id == id }) else {
            return String(localized: "menu.noTask")
        }
        return t.name
    }

    private func reassign(_ session: Session, to taskId: Int64?) {
        var updated = session
        updated.taskId = taskId
        _ = try? appState.sessions.save(updated)
        reload()
    }

    private func delete(_ session: Session) {
        guard let id = session.id else { return }
        try? appState.sessions.delete(id: id)
        try? appState.audit.log(action: AuditAction.sessionDeleted, targetType: "session", targetId: String(id))
        reload()
    }

    private func performSplit(_ session: Session) {
        defer { splitting = nil }
        let splitDate = session.startAt.addingTimeInterval(splitMinutes * 60)
        // The stepper is bounded to a valid range, so a nil result or a save
        // failure is unexpected; report it rather than silently doing nothing.
        guard let parts = SessionEditing.split(session, at: splitDate) else {
            error = .splitFailed
            return
        }
        do {
            _ = try appState.sessions.save(parts.left)
            _ = try appState.sessions.save(parts.right)
            try? appState.audit.log(action: AuditAction.sessionSplit, targetType: "session",
                                    targetId: session.id.map(String.init))
            reload()
        } catch {
            self.error = .splitFailed
        }
    }

    private func performMerge(_ pair: MergePair) {
        pendingMerge = nil
        guard let result = SessionEditing.merge([pair.earlier, pair.later]) else {
            error = .mergeFailed
            return
        }
        do {
            _ = try appState.sessions.save(result.merged)
            for id in result.deletedIds {
                try appState.sessions.delete(id: id)
            }
            try? appState.audit.log(action: AuditAction.sessionMerged, targetType: "session",
                                    targetId: result.merged.id.map(String.init))
            reload()
        } catch {
            self.error = .mergeFailed
        }
    }

    private func generateReport() {
        let input = DailyReportInput(
            date: Date(),
            sessions: sessions,
            taskNames: DayHelpers.taskNameMap(tasks),
            projectNames: DayHelpers.projectNameByTask(tasks, projects)
        )
        let language = appState.preferences.defaultReportLanguage
        reportText = MarkdownReportBuilder().buildDaily(input, language: language)
        try? appState.audit.log(action: AuditAction.reportGenerated, targetType: "daily")
    }
}
