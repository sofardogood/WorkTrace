import SwiftUI

@main
struct WorkTraceApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        // Menu-bar entry point (the app has no Dock icon / LSUIElement = true).
        MenuBarExtra {
            MenuBarView()
                .environment(appState)
                .environment(\.locale, appState.localization.locale)
                .task { appState.bootstrap() }
        } label: {
            Image(systemName: appState.timer.isRunning ? "record.circle" : "clock")
        }
        .menuBarExtraStyle(.window)

        // Primary screen: the automatically captured activity timeline.
        Window(String(localized: "window.activity"), id: "activity") {
            ActivityTimelineView()
                .environment(appState)
                .environment(\.locale, appState.localization.locale)
        }
        .defaultSize(width: 620, height: 680)

        Window(String(localized: "window.timeline"), id: "timeline") {
            DailyTimelineView()
                .environment(appState)
                .environment(\.locale, appState.localization.locale)
        }
        .defaultSize(width: 560, height: 640)

        Window(String(localized: "window.tasks"), id: "tasks") {
            TasksView()
                .environment(appState)
                .environment(\.locale, appState.localization.locale)
        }
        .defaultSize(width: 520, height: 560)

        Window(String(localized: "window.settings"), id: "settings") {
            SettingsView()
                .environment(appState)
                .environment(\.locale, appState.localization.locale)
        }
        .defaultSize(width: 520, height: 640)

        Window(String(localized: "window.onboarding"), id: "onboarding") {
            OnboardingView()
                .environment(appState)
                .environment(\.locale, appState.localization.locale)
        }
        .defaultSize(width: 520, height: 460)
        .windowResizability(.contentSize)
    }
}
