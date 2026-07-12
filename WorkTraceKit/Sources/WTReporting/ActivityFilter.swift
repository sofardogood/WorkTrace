import Foundation
import WTCore

/// Pure, testable filter applied to activity entries before they reach any
/// chart or list. Every field is optional/opt-in so an all-default filter is a
/// no-op (`isActive == false`). Masked titles are matched only by their masked
/// state — the filter never reconstructs a hidden title.
public struct ActivityFilter: Sendable, Equatable {
    /// Restrict to a single app name (exact match).
    public var appName: String?
    /// Case-insensitive substring match on the readable window title. Masked
    /// entries (no title) never match a non-empty query.
    public var titleQuery: String?

    public enum Masking: Sendable, Equatable, CaseIterable {
        case all, maskedOnly, readableOnly
    }
    public var masking: Masking

    public init(appName: String? = nil, titleQuery: String? = nil, masking: Masking = .all) {
        self.appName = appName
        self.titleQuery = titleQuery
        self.masking = masking
    }

    /// True when any constraint is set, so the UI can show a "reset" affordance.
    public var isActive: Bool {
        appName != nil
            || !(titleQuery ?? "").trimmingCharacters(in: .whitespaces).isEmpty
            || masking != .all
    }

    public func apply(_ entries: [ActivityEntry]) -> [ActivityEntry] {
        let query = (titleQuery ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        return entries.filter { entry in
            if let appName, entry.appName != appName { return false }

            let masked = (entry.windowTitle ?? "").isEmpty
            switch masking {
            case .all: break
            case .maskedOnly: if !masked { return false }
            case .readableOnly: if masked { return false }
            }

            if !query.isEmpty {
                guard let title = entry.windowTitle, title.lowercased().contains(query) else {
                    return false
                }
            }
            return true
        }
    }
}
