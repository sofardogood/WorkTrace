import SwiftUI
import WTCore

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    @AppStorage("worktrace.hasOnboarded") private var hasOnboarded = false

    @State private var tasks: [WorkTask] = []
    @State private var selectedTaskId: Int64?
    @State private var memo: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            autoCaptureStatus

            Divider()

            Text("menu.manualTimer")
                .font(.caption).foregroundStyle(.secondary)

            switch appState.timer.state {
            case .idle:
                idleControls
            case .running(let session):
                runningControls(session)
            case .paused:
                pausedControls
            }

            Divider()

            // Primary action: the automatic activity timeline.
            Button {
                open("activity")
            } label: {
                Label("menu.openActivity", systemImage: "chart.bar.doc.horizontal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            // Secondary: manual timeline, optional tasks/projects, settings.
            VStack(spacing: 6) {
                Button("menu.openTimeline") { open("timeline") }
                Button("menu.openTasks") { open("tasks") }
                Button("menu.openSettings") { open("settings") }
            }
            .buttonStyle(.plain)

            Divider()

            Button("menu.quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 300)
        .task {
            reload()
            if !hasOnboarded {
                open("onboarding")
            }
        }
    }

    /// Opens a window scene and brings the app forward. In an accessory
    /// (`LSUIElement`) app, `openWindow` alone leaves the new window behind the
    /// frontmost app, so it must be paired with an explicit activation.
    private func open(_ id: String) {
        openWindow(id: id)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private var header: some View {
        HStack {
            Text("app.name").font(.headline)
            Spacer()
            if appState.timer.isRunning {
                Image(systemName: "record.circle").foregroundStyle(.red)
            }
        }
    }

    /// Always-visible automatic-capture state, kept distinct from the manual
    /// timer so "manual timer stopped" is not mistaken for "nothing is recorded".
    private var autoCaptureStatus: some View {
        let on = appState.preferences.activityCaptureEnabled
        return Label(
            on ? "menu.autoCaptureOn" : "menu.autoCaptureOff",
            systemImage: on ? "record.circle.fill" : "pause.circle"
        )
        .font(.caption)
        .foregroundStyle(on ? .green : .secondary)
    }

    // MARK: - Idle

    private var idleControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("menu.idle").foregroundStyle(.secondary).font(.caption)

            Picker("menu.selectTask", selection: $selectedTaskId) {
                Text("menu.noTask").tag(Int64?.none)
                ForEach(tasks) { task in
                    Text(task.name).tag(Int64?.some(task.id ?? -1))
                }
            }
            .labelsHidden()

            TextField("menu.quickMemo", text: $memo)
                .textFieldStyle(.roundedBorder)

            Button {
                try? appState.timer.start(taskId: selectedTaskId, memo: memo.isEmpty ? nil : memo)
                memo = ""
            } label: {
                Label("menu.start", systemImage: "play.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Running

    private func runningControls(_ session: Session) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(taskName(for: session.taskId)).font(.headline)

            // Live elapsed time, updated each second.
            TimelineView(.periodic(from: .now, by: 1)) { _ in
                Text(elapsedString(since: session.startAt))
                    .font(.system(.title2, design: .monospaced))
            }

            HStack {
                Button {
                    try? appState.timer.pause()
                } label: {
                    Label("menu.pause", systemImage: "pause.fill").frame(maxWidth: .infinity)
                }
                Button(role: .destructive) {
                    try? appState.timer.stop()
                } label: {
                    Label("menu.stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Paused

    private var pausedControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("menu.paused").foregroundStyle(.secondary)
            HStack {
                Button {
                    try? appState.timer.resume()
                } label: {
                    Label("menu.resume", systemImage: "play.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button(role: .destructive) {
                    try? appState.timer.stop()
                } label: {
                    Label("menu.stop", systemImage: "stop.fill").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Helpers

    private func reload() {
        tasks = (try? appState.tasks.all()) ?? []
    }

    private func taskName(for id: Int64?) -> String {
        guard let id, let task = tasks.first(where: { $0.id == id }) else {
            return String(localized: "menu.noTask")
        }
        return task.name
    }

    private func elapsedString(since start: Date) -> String {
        let total = Int(Date().timeIntervalSince(start))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
