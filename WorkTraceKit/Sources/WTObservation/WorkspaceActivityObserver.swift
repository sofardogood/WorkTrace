import Foundation
import WTCore
#if canImport(AppKit)
import AppKit
import ApplicationServices
import CoreGraphics

/// Real macOS observer. Samples the frontmost app, focused window title (via the
/// Accessibility API) and system idle time on a timer.
///
/// Window-title capture requires Accessibility permission; when it is not
/// granted the title is simply `nil` and the rest still works. No screenshots,
/// no keystrokes — only the metadata the spec allows.
public final class WorkspaceActivityObserver: ActivityObserving {
    private var timer: Timer?
    private let interval: TimeInterval
    private let idleThreshold: TimeInterval

    public private(set) var isRunning = false

    public init(interval: TimeInterval = 5, idleThreshold: TimeInterval = 120) {
        self.interval = interval
        self.idleThreshold = idleThreshold
    }

    public func start(onSnapshot: @escaping (RawActivitySnapshot) -> Void) {
        stop()
        isRunning = true
        // Emit one immediately, then on the interval.
        onSnapshot(capture())
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            onSnapshot(self.capture())
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

    // MARK: - Capture

    private func capture() -> RawActivitySnapshot {
        let idleSeconds = systemIdleSeconds()
        let isIdle = idleSeconds >= idleThreshold

        guard let app = NSWorkspace.shared.frontmostApplication else {
            return RawActivitySnapshot(isIdle: isIdle)
        }

        return RawActivitySnapshot(
            appName: app.localizedName,
            bundleId: app.bundleIdentifier,
            windowTitle: focusedWindowTitle(pid: app.processIdentifier),
            isIdle: isIdle
        )
    }

    /// Focused window title via the Accessibility API. Returns `nil` if the
    /// permission is not granted.
    private func focusedWindowTitle(pid: pid_t) -> String? {
        let appElement = AXUIElementCreateApplication(pid)
        var windowRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement, kAXFocusedWindowAttribute as CFString, &windowRef
        ) == .success, let windowRef else { return nil }

        let window = windowRef as! AXUIElement
        var titleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            window, kAXTitleAttribute as CFString, &titleRef
        ) == .success else { return nil }

        let title = titleRef as? String
        return (title?.isEmpty == false) ? title : nil
    }

    private func systemIdleSeconds() -> TimeInterval {
        let anyInput = CGEventType(rawValue: ~0)!
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }
}

/// Whether the app currently has Accessibility (AX) permission. The UI uses this
/// to explain why window-title capture may be unavailable.
public func hasAccessibilityPermission() -> Bool {
    AXIsProcessTrusted()
}

/// Asks the system to prompt the user for Accessibility permission. If it is
/// already granted this returns `true` without prompting. The OS shows its own
/// dialog and deep-links to System Settings; the grant only takes effect after
/// the user toggles it there, so callers should re-check `hasAccessibilityPermission()`.
@discardableResult
public func requestAccessibilityPermission() -> Bool {
    let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    return AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
}
#endif
