import Foundation

/// UI display language. `system` follows the OS setting.
public enum AppLanguage: String, Codable, Sendable, CaseIterable, Identifiable {
    case system
    case japanese = "ja"
    case english = "en"

    public var id: String { rawValue }

    /// Locale identifier to force, or `nil` to follow the system.
    public var localeIdentifier: String? {
        switch self {
        case .system:   return nil
        case .japanese: return "ja"
        case .english:  return "en"
        }
    }

    /// Localization key for a human-readable name.
    public var displayNameKey: String {
        switch self {
        case .system:   return "language.system"
        case .japanese: return "language.japanese"
        case .english:  return "language.english"
        }
    }
}

/// Output language for reports and exports. Independent of the UI language,
/// so a Japanese UI can still emit an English client report from the same data.
public enum ReportLanguage: String, Codable, Sendable, CaseIterable, Identifiable {
    case japanese = "ja"
    case english = "en"

    public var id: String { rawValue }

    public var displayNameKey: String {
        switch self {
        case .japanese: return "language.japanese"
        case .english:  return "language.english"
        }
    }
}
