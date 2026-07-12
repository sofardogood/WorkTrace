import SwiftUI
import WTObservation

/// First-run onboarding. Explains, in the user's language, what WorkTrace
/// observes, that everything stays on this Mac, and the privacy protections in
/// place — then lets the user grant Accessibility permission. Shown once; can be
/// re-opened from Settings.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    /// Set to true when onboarding has been completed at least once.
    @AppStorage("worktrace.hasOnboarded") private var hasOnboarded = false

    @State private var page = 0

    private let pageCount = 5

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                tracking.tag(1)
                storage.tag(2)
                privacy.tag(3)
                permission.tag(4)
            }
            .tabViewStyle(.automatic)

            Divider()
            controls
        }
        .frame(width: 520, height: 460)
        .task { appState.refreshAccessibility() }
    }

    // MARK: - Pages

    private var welcome: some View {
        page(
            icon: "clock.badge.checkmark",
            title: "onboarding.welcome.title",
            body: "onboarding.welcome.body"
        )
    }

    private var tracking: some View {
        page(
            icon: "rectangle.on.rectangle",
            title: "onboarding.tracking.title",
            body: "onboarding.tracking.body"
        )
    }

    private var storage: some View {
        page(
            icon: "internaldrive",
            title: "onboarding.storage.title",
            body: "onboarding.storage.body"
        )
    }

    private var privacy: some View {
        page(
            icon: "lock.shield",
            title: "onboarding.privacy.title",
            body: "onboarding.privacy.body"
        )
    }

    private var permission: some View {
        VStack(spacing: 16) {
            Image(systemName: "hand.raised.circle")
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text("onboarding.permission.title").font(.title2).bold()
            Text("onboarding.permission.body")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if appState.accessibilityGranted {
                Label("onboarding.permission.granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("onboarding.permission.grant") {
                    requestAccessibilityPermission()
                    // The grant takes effect after the user toggles it in System
                    // Settings; re-check when the app becomes active again.
                    appState.refreshAccessibility()
                }
                .buttonStyle(.borderedProminent)
                Text("onboarding.permission.optional")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func page(icon: String, title: LocalizedStringKey, body: LocalizedStringKey) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text(title).font(.title2).bold()
            Text(body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Controls

    private var controls: some View {
        HStack {
            Button("onboarding.skip") { finish() }
                .buttonStyle(.plain)

            Spacer()

            PageDots(count: pageCount, index: page)

            Spacer()

            if page > 0 {
                Button("onboarding.back") { page -= 1 }
            }
            if page < pageCount - 1 {
                Button("onboarding.next") { page += 1 }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("onboarding.done") { finish() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }

    private func finish() {
        hasOnboarded = true
        dismiss()
    }
}

private struct PageDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(i == index ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
    }
}
