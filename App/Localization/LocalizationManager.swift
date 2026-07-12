import Foundation
import Observation
import WTCore

/// Controls the runtime UI language. Setting `language` updates `locale`, which
/// is injected into the SwiftUI environment so `Text("key")` re-resolves against
/// the chosen language immediately — no relaunch required.
@MainActor
@Observable
public final class LocalizationManager {
    public var language: AppLanguage {
        didSet { recomputeLocale() }
    }

    public private(set) var locale: Locale = .current

    public init(language: AppLanguage = .system) {
        self.language = language
        recomputeLocale()
    }

    private func recomputeLocale() {
        if let id = language.localeIdentifier {
            locale = Locale(identifier: id)
        } else {
            locale = .autoupdatingCurrent
        }
    }
}
