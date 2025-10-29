//
//  KuaiJiApp.swift
//  KuaiJi
//
//  Created by Guo on 01/10/2025.
//

import SwiftUI
import SwiftData
import Combine

private enum QuickActionType: String {
    case quickAddExpense = "com.kuaiji.quickAddExpense"
}

private enum DeepLinkParser {
    static let scheme = "kuaiji"

    static func quickAction(for url: URL) -> QuickActionType? {
        guard url.scheme?.lowercased() == scheme else { return nil }
        let candidate = (url.host ?? url.pathComponents.dropFirst().first)?.lowercased()
        switch candidate {
        case "quickaddexpense", "quick-add-expense":
            return .quickAddExpense
        default:
            return nil
        }
    }
}

@main
struct KuaiJiApp: App {
    @StateObject private var rootViewModel = AppRootViewModel()
    @StateObject private var appState = AppState()
    @StateObject private var personalLedgerRoot: PersonalLedgerRootViewModel
    @StateObject private var celebration = CelebrationManager.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        let container = sharedModelContainer
        _personalLedgerRoot = StateObject(wrappedValue: PersonalLedgerRootViewModel(modelContext: container.mainContext, defaultCurrency: .cny))
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            Ledger.self,
            Membership.self,
            Expense.self,
            ExpenseParticipant.self,
            BalanceSnapshot.self,
            TransferPlan.self,
            AuditLog.self,
            PersonalAccount.self,
            PersonalTransaction.self,
            AccountTransfer.self,
            PersonalPreferences.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            #if DEBUG
            preconditionFailure("Could not create ModelContainer: \(error)")
            #else
            // Fallback to in-memory container to keep app usable
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let container = try? ModelContainer(for: schema, configurations: [fallbackConfig]) {
                return container
            }
            fatalError("Could not create either persistent or in-memory ModelContainer: \(error)")
            #endif
        }
    }()

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isCheckingOnboarding {
                    // 显示加载状态
                    ProgressView()
                } else if appState.showWelcomeGuide {
                    // 显示欢迎引导页面
                    WelcomeGuideView {
                        appState.completeWelcomeGuide()
                    }
                } else if appState.showOnboarding {
                    // 显示首次设置界面
                    OnboardingView { name, emoji, currency in
                        // 完成设置
                        if let manager = appState.dataManager {
                            manager.completeOnboarding(name: name, emoji: emoji, currency: currency)
                            rootViewModel.setDataManager(manager)
                            appState.showOnboarding = false
                        }
                    }
                } else {
                    // 显示主界面
                    ContentView(viewModel: rootViewModel, personalLedgerRoot: personalLedgerRoot)
                        .environmentObject(appState)
                        .overlay(
                            CelebrationOverlay(manager: celebration)
                        )
                }
            }
            .onAppear {
                KeyboardDismissInstaller.installIfNeeded()
                // 设置 AppDelegate 的 appState 引用
                AppDelegate.appState = appState
                
                if appState.dataManager == nil {
                    let manager = PersistentDataManager(modelContext: sharedModelContainer.mainContext)
                    appState.dataManager = manager
                    rootViewModel.bind(appState: appState)
                    
                    // 检查引导和设置状态
                    appState.checkOnboardingStatus()
                    
                    // 如果已完成设置，加载数据
                    if !appState.showOnboarding && !appState.showWelcomeGuide {
                        rootViewModel.setDataManager(manager)
                        if let currency = manager.currentUser?.currency {
                            try? personalLedgerRoot.store.updatePreferences { prefs in
                                prefs.primaryDisplayCurrency = currency
                            }
                        }
                        // 刷新 Quick Actions
                        appState.refreshQuickActions()
                    }
                    
                    appState.isCheckingOnboarding = false
                }
                
                // 处理启动时的 Quick Action（如果有）
                if let shortcutItem = appDelegate.launchShortcutItem {
                    debugLog("📲 处理启动时的 Quick Action")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        appState.handleQuickAction(shortcutItem.type)
                    }
                }
                
                // 启动时检查快捷指令触发
                appState.processPendingShortcutTriggers()
            }
            .background(Color.appBackground)
            .onOpenURL { url in
                if let action = DeepLinkParser.quickAction(for: url) {
                    debugLog("🔗 通过 URL Scheme 收到动作:", action.rawValue)
                    ShortcutBridge.requestQuickAdd()
                    appState.processPendingShortcutTriggers()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                appState.processPendingShortcutTriggers()
            }
            .alert(isPresented: Binding(get: { (appState.iapAlertMessage?.isEmpty == false) && !appState.isSupportSheetVisible }, set: { _ in appState.iapAlertTitle = nil; appState.iapAlertMessage = nil })) {
                Alert(title: Text(appState.iapAlertTitle ?? L.supportPurchaseTitle.localized),
                      message: Text(appState.iapAlertMessage ?? ""),
                      dismissButton: .default(Text(L.ok.localized)))
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - App State
enum QuickActionTarget: Equatable {
    case shared(UUID)
    case personal
}

enum SharedLandingPreference: Equatable {
    case list
    case ledger(UUID)
}

@MainActor
class AppState: ObservableObject {
    @Published var dataManager: PersistentDataManager?
    @Published var showOnboarding: Bool
    @Published var showWelcomeGuide: Bool
    @Published var isCheckingOnboarding: Bool
    @Published var quickActionTarget: QuickActionTarget?
    @Published var showSharedLedgerTab: Bool {
        didSet { UserDefaults.standard.set(showSharedLedgerTab, forKey: showSharedLedgerKey) }
    }
    @Published var showPersonalLedgerTab: Bool {
        didSet { UserDefaults.standard.set(showPersonalLedgerTab, forKey: showPersonalLedgerKey) }
    }
    // 当选择共享账本 Tab 时触发，用于根据偏好进行页面导航
    @Published var sharedTabActivateAt: Date?
    // Global IAP alert
    @Published var iapAlertTitle: String?
    @Published var iapAlertMessage: String?
    @Published var isSupportSheetVisible: Bool = false
    
    private let hasSeenWelcomeGuideKey = "hasSeenWelcomeGuide"
    private let defaultLedgerIdKey = "defaultLedgerIdForQuickAction"
    private let defaultQuickActionKey = "defaultQuickActionTarget"
    private let showSharedLedgerKey = "showSharedLedgerTab"
    private let showPersonalLedgerKey = "showPersonalLedgerTab"
    private let sharedLandingPrefKey = "sharedLandingPref"
    
    init() {
        dataManager = nil
        showOnboarding = false
        showWelcomeGuide = false
        isCheckingOnboarding = true
        quickActionTarget = nil
        let defaults = UserDefaults.standard
        defaults.register(defaults: [
            showSharedLedgerKey: true,
            showPersonalLedgerKey: true
        ])
        showSharedLedgerTab = defaults.bool(forKey: showSharedLedgerKey)
        showPersonalLedgerTab = defaults.bool(forKey: showPersonalLedgerKey)
    }

    // MARK: - 共享账本默认页面偏好

    func getSharedLandingPreference() -> SharedLandingPreference {
        let stored = UserDefaults.standard.string(forKey: sharedLandingPrefKey) ?? "list"
        if stored == "list" { return .list }
        if let id = UUID(uuidString: stored) { return .ledger(id) }
        return .list
    }

    func setSharedLandingPreference(_ pref: SharedLandingPreference) {
        let defaults = UserDefaults.standard
        switch pref {
        case .list:
            defaults.set("list", forKey: sharedLandingPrefKey)
        case .ledger(let id):
            defaults.set(id.uuidString, forKey: sharedLandingPrefKey)
        }
        objectWillChange.send()
    }

    /// 请求在切换到共享账本标签时，根据偏好导航到指定页面
    func requestSharedTabLandingActivation() {
        sharedTabActivateAt = Date()
    }
    
    func checkOnboardingStatus() {
        if let manager = dataManager {
            let hasCompletedOnboarding = manager.hasCompletedOnboarding()
            let hasSeenGuide = UserDefaults.standard.bool(forKey: hasSeenWelcomeGuideKey)
            
            if !hasCompletedOnboarding && !hasSeenGuide {
                // 未完成设置且未看过引导 -> 显示引导
                showWelcomeGuide = true
            } else if !hasCompletedOnboarding {
                // 未完成设置但看过引导 -> 直接显示设置页面
                showOnboarding = true
            }
        }
    }
    
    func completeWelcomeGuide() {
        UserDefaults.standard.set(true, forKey: hasSeenWelcomeGuideKey)
        showWelcomeGuide = false
        showOnboarding = true
    }
    
    // MARK: - Quick Action 支持
    
    /// 获取 Quick Action 目标
    func getQuickActionTarget() -> QuickActionTarget? {
        let defaults = UserDefaults.standard
        if let stored = defaults.string(forKey: defaultQuickActionKey), !stored.isEmpty {
            if stored == "personal" {
                return .personal
            }
            if let uuid = UUID(uuidString: stored) {
                return .shared(uuid)
            }
        }
        // 向后兼容旧版本仅存储共享账本 ID 的情况
        if let legacy = defaults.string(forKey: defaultLedgerIdKey), let uuid = UUID(uuidString: legacy) {
            return .shared(uuid)
        }
        return nil
    }
    
    /// 设置 Quick Action 目标
    func setQuickActionTarget(_ target: QuickActionTarget?) {
        let defaults = UserDefaults.standard
        switch target {
        case .shared(let ledgerId):
            defaults.set(ledgerId.uuidString, forKey: defaultQuickActionKey)
            defaults.set(ledgerId.uuidString, forKey: defaultLedgerIdKey)
            debugLog("✅ 默认账本已设置:", ledgerId.uuidString)
            updateQuickActions()
        case .personal:
            defaults.set("personal", forKey: defaultQuickActionKey)
            defaults.removeObject(forKey: defaultLedgerIdKey)
            debugLog("✅ 默认账本已设置为个人账本")
            updateQuickActions()
        case .none:
            defaults.removeObject(forKey: defaultQuickActionKey)
            defaults.removeObject(forKey: defaultLedgerIdKey)
            debugLog("✅ 默认账本已清除")
            clearQuickActions()
        }
        objectWillChange.send()
    }
    
    /// 处理 Quick Action
    func handleQuickAction(_ type: String) {
        debugLog("🚀 收到 Quick Action:", type)
        if type == QuickActionType.quickAddExpense.rawValue {
            let target = getQuickActionTarget()
            debugLog("📱 设置 quickActionTarget:", String(describing: target))
            quickActionTarget = target
        }
    }

    /// 处理来自快捷指令的挂起请求
    func processPendingShortcutTriggers() {
        if ShortcutBridge.consumeQuickAddRequest() {
            debugLog("🔐 收到快捷指令 Quick Add 请求")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.handleQuickAction(QuickActionType.quickAddExpense.rawValue)
            }
        }
    }
    
    /// 更新动态 Quick Actions
    private func updateQuickActions() {
        guard let target = getQuickActionTarget() else {
            debugLog("⚠️ 未设置默认账本")
            clearQuickActions()
            return
        }

        var subtitle = ""

        switch target {
        case .shared(let ledgerId):
            guard let manager = dataManager else {
                debugLog("⚠️ DataManager 未初始化")
                clearQuickActions()
                return
            }

            guard let ledger = manager.allLedgers.first(where: { $0.remoteId == ledgerId }) else {
                debugLog("⚠️ 找不到账本:", ledgerId.uuidString)
                let available = manager.allLedgers.map { "\($0.name) (\($0.remoteId.uuidString))" }.joined(separator: ", ")
                debugLog("📋 可用账本:", available)
                clearQuickActions()
                return
            }

            subtitle = ledger.name
        case .personal:
            subtitle = L.quickActionPersonalSubtitle.localized
        }

        let quickAddAction = UIApplicationShortcutItem(
            type: QuickActionType.quickAddExpense.rawValue,
            localizedTitle: L.quickActionAddExpense.localized,
            localizedSubtitle: subtitle,
            icon: UIApplicationShortcutIcon(systemImageName: "plus.circle.fill")
        )

        UIApplication.shared.shortcutItems = [quickAddAction]
        debugLog("✅ Quick Action 已更新:", subtitle)
    }
    
    /// 清除 Quick Actions
    private func clearQuickActions() {
        UIApplication.shared.shortcutItems = []
    }
    
    /// 当数据加载后刷新 Quick Actions
    func refreshQuickActions() {
        if getQuickActionTarget() != nil {
            updateQuickActions()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    static var appState: AppState?
    var launchShortcutItem: UIApplicationShortcutItem?
    
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // 保存启动时的 Quick Action，稍后在 onAppear 中处理
        if let shortcutItem = options.shortcutItem {
            debugLog("💾 保存启动时的 Quick Action:", shortcutItem.type)
            launchShortcutItem = shortcutItem
        }
        
        let configuration = UISceneConfiguration(
            name: connectingSceneSession.configuration.name,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        debugLog("🎬 应用运行中收到 Quick Action:", shortcutItem.type)
        Task { @MainActor in
            if let appState = AppDelegate.appState {
                // 延迟一下确保UI已经准备好
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    appState.handleQuickAction(shortcutItem.type)
                    completionHandler(true)
                }
            } else {
                debugLog("❌ appState 未初始化")
                completionHandler(false)
            }
        }
    }
}
