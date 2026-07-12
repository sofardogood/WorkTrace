import Foundation
import WTCore

/// Emits raw activity snapshots. Implementations are swappable (real AppKit
/// observer, or a fake for tests / previews).
public protocol ActivityObserving: AnyObject {
    /// Starts sampling. `onSnapshot` is called on the main thread.
    func start(onSnapshot: @escaping (RawActivitySnapshot) -> Void)
    func stop()
    var isRunning: Bool { get }
}
