#if os(iOS)
import Foundation

extension AppModel {
    /// Execute any actions queued by App Intents while the app was suspended.
    /// Call when the app becomes active.
    @discardableResult
    func drainPendingIntents() -> Bool {
        var shouldSyncHealth = false
        for item in PendingIntents.drain() {
            switch item.action {
            case .markMoment: markMoment(at: item.date ?? Date())
            case .syncHealth: shouldSyncHealth = true
            }
        }
        return shouldSyncHealth
    }
}
#endif
