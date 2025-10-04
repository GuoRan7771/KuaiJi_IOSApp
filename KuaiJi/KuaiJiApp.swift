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
                if appState.dataManager == nil {
                    let manager = PersistentDataManager(modelContext: sharedModelContainer.mainContext)
                    appState.dataManager = manager
                    
                    // 检查引导和设置状态
                    appState.checkOnboardingStatus()
                    
                    // 如果已完成设置，加载数据
                    if !appState.showOnboarding && !appState.showWelcomeGuide {
                        rootViewModel.setDataManager(manager)
                    }
                    
                    appState.isCheckingOnboarding = false
                }
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
    
    private let hasSeenWelcomeGuideKey = "hasSeenWelcomeGuide"
    
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
}
