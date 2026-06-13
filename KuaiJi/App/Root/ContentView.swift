//
//  ContentView.swift
//  KuaiJi
//
//  Main tab shell and shared ledger navigation views.
//

import SwiftUI
import UIKit
import SwiftData

struct ContentView: View {
    @ObservedObject var viewModel: AppRootViewModel
    @ObservedObject var personalLedgerRoot: PersonalLedgerRootViewModel
    @StateObject private var listViewModel: LedgerListScreenModel
    @StateObject private var friendViewModel: FriendListScreenModel
    @StateObject private var settingsViewModel: SettingsScreenModel
    @EnvironmentObject var appState: AppState
    @AppStorage("theme") private var theme = "default"

    private enum RootTab: Hashable { case personal, ledgers, settings }
    @State private var selectedTab: RootTab = .personal
    @State private var path = NavigationPath()
    private let switchToLedgersTab: () -> Void

    init(viewModel: AppRootViewModel, personalLedgerRoot: PersonalLedgerRootViewModel, switchToLedgersTab: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.personalLedgerRoot = personalLedgerRoot
        self.switchToLedgersTab = switchToLedgersTab
        _listViewModel = StateObject(wrappedValue: viewModel.makeLedgerListViewModel())
        _friendViewModel = StateObject(wrappedValue: viewModel.makeFriendListViewModel())
        _settingsViewModel = StateObject(wrappedValue: viewModel.makeSettingsViewModel())
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            if appState.showPersonalLedgerTab {
                PersonalLedgerNavigator(root: personalLedgerRoot)
                    .environmentObject(viewModel)
                    .tabItem { Label(L.tabPersonalLedger.localized, systemImage: "wallet.pass") }
                    .tag(RootTab.personal)
            }

            if appState.showSharedLedgerTab {
                LedgerNavigator(rootViewModel: viewModel,
                                listViewModel: listViewModel,
                                friendViewModel: friendViewModel,
                                onRequireLedgerTab: { selectedTab = .ledgers })
                    .tabItem { Label(L.tabLedgers.localized, systemImage: "list.bullet") }
                    .tag(RootTab.ledgers)
            }

            SettingsNavigator(viewModel: settingsViewModel, rootViewModel: viewModel, personalLedgerRoot: personalLedgerRoot)
                .tabItem { Label(L.tabSettings.localized, systemImage: "gearshape") }
                .tag(RootTab.settings)
        }
        .id(theme) // Force full rebuild when theme changes to update all colors
        .onChangeCompat(of: appState.showPersonalLedgerTab) { ensureValidSelectedTab() }
        .onChangeCompat(of: appState.showSharedLedgerTab) { ensureValidSelectedTab() }
        .onChangeCompat(of: appState.quickActionTarget) {
            handleGlobalQuickAction()
        }
        .onChangeCompat(of: appState.settingsDeepLink) {
            handleSettingsDeepLinkTabSwitch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPersonalTemplates)) { _ in
            selectedTab = .settings
        }
        .onChangeCompat(of: selectedTab) {
            if selectedTab == .ledgers {
                appState.requestSharedTabLandingActivation()
            }
        }
        .onAppear {
            handleSettingsDeepLinkTabSwitch()
        }
        .tint(Color.appTextPrimary)
        .background(Color.appBackground.ignoresSafeArea())
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func ensureValidSelectedTab() {
        // 如果当前选中的 tab 已被隐藏，切换到第一个可见 tab
        switch selectedTab {
        case .personal:
            if !appState.showPersonalLedgerTab {
                selectedTab = appState.showSharedLedgerTab ? .ledgers : .settings
            }
        case .ledgers:
            if !appState.showSharedLedgerTab {
                selectedTab = appState.showPersonalLedgerTab ? .personal : .settings
            }
        case .settings:
            // 永远可用，无需处理
            break
        }
    }

    private func handleGlobalQuickAction() {
        guard case .shared = appState.quickActionTarget else { return }
        selectedTab = .ledgers
    }

    private func handleSettingsDeepLinkTabSwitch() {
        if appState.settingsDeepLink != nil {
            selectedTab = .settings
        }
    }

    // MARK: - App Version Helper
    private func versionString() -> String {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String) ?? ""
        let build = (info?["CFBundleVersion"] as? String) ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }
}

#Preview {
    let schema = Schema([
        UserProfile.self,
        Ledger.self,
        Membership.self,
        Expense.self,
        ExpenseParticipant.self,
        BalanceSnapshot.self,
        TransferPlan.self,
        AuditLog.self,
        PersonalCategoryDefinition.self,
        PersonalAccount.self,
        PersonalTransaction.self,
        AccountTransfer.self,
        PersonalRecordTemplate.self,
        PersonalPreferences.self
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    do {
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let personalRoot = PersonalLedgerRootViewModel(modelContext: container.mainContext, defaultCurrency: .cny)
        return ContentView(viewModel: AppRootViewModel(), personalLedgerRoot: personalRoot)
            .modelContainer(container)
    } catch {
        let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        if let container = try? ModelContainer(for: schema, configurations: [fallbackConfig]) {
            let personalRoot = PersonalLedgerRootViewModel(modelContext: container.mainContext, defaultCurrency: .cny)
            return ContentView(viewModel: AppRootViewModel(), personalLedgerRoot: personalRoot)
                .modelContainer(container)
        }
        return Text("Preview init failed: \(error.localizedDescription)")
    }
}
