import Foundation

enum ShortcutBridge {
    private static let quickAddKey = "com.kuaiji.shortcut.pendingQuickAdd"

    static func requestQuickAdd() {
        UserDefaults.standard.set(true, forKey: quickAddKey)
    }

    @discardableResult
    static func consumeQuickAddRequest() -> Bool {
        let defaults = UserDefaults.standard
        let pending = defaults.bool(forKey: quickAddKey)
        if pending {
            defaults.set(false, forKey: quickAddKey)
        }
        return pending
    }
}
