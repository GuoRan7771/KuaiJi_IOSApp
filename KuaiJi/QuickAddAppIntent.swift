import AppIntents

// iOS 18 项目，AppIntent 和 AppShortcutsProvider 已完全支持
struct QuickAddExpenseIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add Expense"
    static var description = IntentDescription("Open the quick add expense form for your default ledger in KuaiJi.")
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        ShortcutBridge.requestQuickAdd()
        return .result()
    }
}

struct KuaiJiAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .orange

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QuickAddExpenseIntent(),
            phrases: [
                "\(.applicationName) quick add",
                "\(.applicationName) log expense",
                "在 \(.applicationName) 记一笔"
            ],
            shortTitle: "Quick Add",
            systemImageName: "plus.circle.fill"
        )
    }
}
