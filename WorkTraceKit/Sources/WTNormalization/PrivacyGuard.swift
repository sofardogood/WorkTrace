import Foundation
import CryptoKit
import WTCore

/// Applies the user's privacy masks to a raw snapshot and decides how much may
/// be recorded. This is the single choke point that must run BEFORE any activity
/// is written to disk — raw window titles / URLs never reach storage.
public struct PrivacyGuard: Sendable {
    private let masks: [PrivacyMask]

    public init(masks: [PrivacyMask]) {
        self.masks = masks.filter(\.enabled)
    }

    /// The privacy decision for a snapshot.
    public struct Decision: Sendable, Equatable {
        public var level: PrivacyLevel
        /// Readable window title, retained only at `.full`; `nil` when masked.
        public var windowTitle: String?
        public var urlDomain: String?
        public var documentPathHash: String?
        public var keepAppIdentity: Bool
    }

    public func evaluate(_ snapshot: RawActivitySnapshot) -> Decision {
        let action = matchedAction(for: snapshot)

        switch action {
        case .exclude:
            return Decision(level: .excluded, windowTitle: nil, urlDomain: nil,
                            documentPathHash: nil, keepAppIdentity: false)

        case .timeOnly:
            return Decision(level: .timeOnly, windowTitle: nil, urlDomain: nil,
                            documentPathHash: nil, keepAppIdentity: false)

        case .maskTitle:
            return Decision(
                level: .maskedTitle,
                windowTitle: nil, // title dropped; app + domain kept
                urlDomain: Self.domain(from: snapshot.url),
                documentPathHash: nil,
                keepAppIdentity: true
            )

        case nil:
            return Decision(
                level: .full,
                windowTitle: snapshot.windowTitle, // readable, local-only
                urlDomain: Self.domain(from: snapshot.url),
                documentPathHash: Self.hash(snapshot.documentPath),
                keepAppIdentity: true
            )
        }
    }

    // MARK: - Matching

    private func matchedAction(for snapshot: RawActivitySnapshot) -> PrivacyMaskAction? {
        // Most restrictive action wins.
        var result: PrivacyMaskAction?
        for mask in masks where matches(mask, snapshot) {
            result = moreRestrictive(result, mask.action)
        }
        return result
    }

    private func matches(_ mask: PrivacyMask, _ snapshot: RawActivitySnapshot) -> Bool {
        let needle = mask.pattern.lowercased()
        guard !needle.isEmpty else { return false }
        switch mask.targetType {
        case .app:
            let name = (snapshot.appName ?? "").lowercased()
            let bundle = (snapshot.bundleId ?? "").lowercased()
            return name.contains(needle) || bundle.contains(needle)
        case .urlDomain:
            return (Self.domain(from: snapshot.url) ?? "").lowercased().contains(needle)
        case .windowTitle:
            return (snapshot.windowTitle ?? "").lowercased().contains(needle)
        case .timeRange:
            return false // time-range masks handled by the scheduler, not here
        }
    }

    private func moreRestrictive(_ a: PrivacyMaskAction?, _ b: PrivacyMaskAction) -> PrivacyMaskAction {
        func rank(_ x: PrivacyMaskAction?) -> Int {
            switch x {
            case .none:      return 0
            case .maskTitle: return 1
            case .timeOnly:  return 2
            case .exclude:   return 3
            }
        }
        return rank(a) >= rank(b) ? (a ?? b) : b
    }

    // MARK: - Helpers

    static func hash(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func domain(from urlString: String?) -> String? {
        guard let urlString, !urlString.isEmpty else { return nil }
        if let host = URLComponents(string: urlString)?.host { return host }
        return nil
    }
}
