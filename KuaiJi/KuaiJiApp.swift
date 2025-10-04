//
//  KuaiJiApp.swift
//  KuaiJi
//
//  Created by Guo on 01/10/2025.
//

import SwiftUI
import SwiftData
import Combine

@main
struct KuaiJiApp: App {
    @StateObject private var rootViewModel = AppRootViewModel()
    @StateObject private var appState = AppState()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            UserProfile.self,
            Ledger.self,
            Membership.self,
            Expense.self,
            ExpenseParticipant.self,
            BalanceSnapshot.self,
            TransferPlan.self,
            AuditLog.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
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
                    ContentView(viewModel: rootViewModel)
                        .environmentObject(appState)
                }
            }
            .onAppear {
                // 设置 AppDelegate 的 appState 引用
                AppDelegate.appState = appState
                
                if appState.dataManager == nil {
                    let manager = PersistentDataManager(modelContext: sharedModelContainer.mainContext)
                    appState.dataManager = manager
                    
                    // 检查引导和设置状态
                    appState.checkOnboardingStatus()
                    
                    // 如果已完成设置，加载数据
                    if !appState.showOnboarding && !appState.showWelcomeGuide {
                        rootViewModel.setDataManager(manager)
                        // 刷新 Quick Actions
                        appState.refreshQuickActions()
                    }
                    
                    appState.isCheckingOnboarding = false
                }
                
                // 处理启动时的 Quick Action（如果有）
                if let shortcutItem = appDelegate.launchShortcutItem {
                    print("📲 处理启动时的 Quick Action")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        appState.handleQuickAction(shortcutItem.type)
                    }
                }
            }
            .onOpenURL { url in
                // 处理自定义 URL Scheme（如果需要）
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - App State
@MainActor
class AppState: ObservableObject {
    @Published var dataManager: PersistentDataManager?
    @Published var showOnboarding = false
    @Published var showWelcomeGuide = false
    @Published var isCheckingOnboarding = true
    @Published var quickActionLedgerId: UUID?  // Quick Action 触发时要打开的账本ID
    
    private let hasSeenWelcomeGuideKey = "hasSeenWelcomeGuide"
    private let defaultLedgerIdKey = "defaultLedgerIdForQuickAction"
    
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
    
    /// 获取默认账本ID
    func getDefaultLedgerId() -> UUID? {
        guard let uuidString = UserDefaults.standard.string(forKey: defaultLedgerIdKey),
              let uuid = UUID(uuidString: uuidString) else {
            return nil
        }
        return uuid
    }
    
    /// 设置默认账本ID
    func setDefaultLedgerId(_ ledgerId: UUID?) {
        if let ledgerId = ledgerId {
            UserDefaults.standard.set(ledgerId.uuidString, forKey: defaultLedgerIdKey)
            print("✅ 默认账本已设置: \(ledgerId.uuidString)")
            updateQuickActions()
        } else {
            UserDefaults.standard.removeObject(forKey: defaultLedgerIdKey)
            print("✅ 默认账本已清除")
            clearQuickActions()
        }
        // 触发 UI 更新
        objectWillChange.send()
    }
    
    /// 处理 Quick Action
    func handleQuickAction(_ type: String) {
        print("🚀 收到 Quick Action: \(type)")
        if type == "com.kuaiji.quickAddExpense" {
            let ledgerId = getDefaultLedgerId()
            print("📱 设置 quickActionLedgerId: \(ledgerId?.uuidString ?? "nil")")
            quickActionLedgerId = ledgerId
        }
    }
    
    /// 更新动态 Quick Actions
    private func updateQuickActions() {
        guard let ledgerId = getDefaultLedgerId() else {
            print("⚠️ 未设置默认账本ID")
            clearQuickActions()
            return
        }
        
        guard let manager = dataManager else {
            print("⚠️ DataManager 未初始化")
            clearQuickActions()
            return
        }
        
        guard let ledger = manager.allLedgers.first(where: { $0.remoteId == ledgerId }) else {
            print("⚠️ 找不到账本: \(ledgerId.uuidString)")
            print("📋 可用账本: \(manager.allLedgers.map { "\($0.name) (\($0.remoteId.uuidString))" }.joined(separator: ", "))")
            clearQuickActions()
            return
        }
        
        let quickAddAction = UIApplicationShortcutItem(
            type: "com.kuaiji.quickAddExpense",
            localizedTitle: L.quickActionAddExpense.localized,
            localizedSubtitle: ledger.name,
            icon: UIApplicationShortcutIcon(systemImageName: "plus.circle.fill")
        )
        
        UIApplication.shared.shortcutItems = [quickAddAction]
        print("✅ Quick Action 已更新: \(ledger.name)")
    }
    
    /// 清除 Quick Actions
    private func clearQuickActions() {
        UIApplication.shared.shortcutItems = []
    }
    
    /// 当数据加载后刷新 Quick Actions
    func refreshQuickActions() {
        if getDefaultLedgerId() != nil {
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
            print("💾 保存启动时的 Quick Action: \(shortcutItem.type)")
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
        print("🎬 应用运行中收到 Quick Action: \(shortcutItem.type)")
        Task { @MainActor in
            if let appState = AppDelegate.appState {
                // 延迟一下确保UI已经准备好
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    appState.handleQuickAction(shortcutItem.type)
                    completionHandler(true)
                }
            } else {
                print("❌ appState 未初始化")
                completionHandler(false)
            }
        }
    }
}
