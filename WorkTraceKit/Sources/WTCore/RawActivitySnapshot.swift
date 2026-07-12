import Foundation

/// A single raw observation from the OS, produced by the observation layer.
///
/// This value carries UNMASKED, potentially sensitive strings (window titles,
/// URLs, file paths). It must pass through `PrivacyGuard` and be converted to an
/// `ActivityEntry` before anything is written to disk. It is intentionally NOT
/// `Codable` — it should never be serialized or persisted directly.
public struct RawActivitySnapshot: Sendable, Equatable {
    public var timestamp: Date
    public var appName: String?
    public var bundleId: String?
    public var windowTitle: String?
    public var url: String?
    public var documentPath: String?
    public var isIdle: Bool

    public init(
        timestamp: Date = Date(),
        appName: String? = nil,
        bundleId: String? = nil,
        windowTitle: String? = nil,
        url: String? = nil,
        documentPath: String? = nil,
        isIdle: Bool = false
    ) {
        self.timestamp = timestamp
        self.appName = appName
        self.bundleId = bundleId
        self.windowTitle = windowTitle
        self.url = url
        self.documentPath = documentPath
        self.isIdle = isIdle
    }
}
