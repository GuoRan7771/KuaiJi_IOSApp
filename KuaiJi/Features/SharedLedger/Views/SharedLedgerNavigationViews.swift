//
//  SharedLedgerNavigationViews.swift
//  KuaiJi
//

import SwiftUI

struct LedgerNavigator: View {
    @ObservedObject var rootViewModel: AppRootViewModel
    @ObservedObject var listViewModel: LedgerListScreenModel
    @ObservedObject var friendViewModel: FriendListScreenModel
    @EnvironmentObject var appState: AppState
    @State private var showingCreateLedger = false
    @State private var showingShareLedger = false
    @State private var quickActionLedger: LedgerSummaryViewData?
    @State private var path = NavigationPath()
    let onRequireLedgerTab: () -> Void

    var body: some View {
        NavigationStack(path: $path) {
            LedgerListView(viewModel: listViewModel)
                .navigationTitle(L.ledgersPageTitle.localized)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showingShareLedger = true }) {
                            Label(L.syncShareLedger.localized, systemImage: "antenna.radiowaves.left.and.right")
                        }
                        .tint(Color.appTextPrimary)
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        NavigationLink(destination: FriendListHost(viewModel: friendViewModel, rootViewModel: rootViewModel)) {
                            Label(L.tabFriends.localized, systemImage: "person.2")
                        }
                        .tint(Color.appTextPrimary)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingCreateLedger = true }) {
                            Label(L.ledgersNew.localized, systemImage: "plus")
                        }
                        .tint(Color.appTextPrimary)
                    }
                }
                .navigationDestination(for: LedgerSummaryViewData.self) { summary in
                    LedgerOverviewHost(rootViewModel: rootViewModel, summary: summary)
                }
                .sheet(isPresented: $showingCreateLedger) {
                    CreateLedgerSheet(viewModel: listViewModel)
                }
                .sheet(isPresented: $showingShareLedger) {
                    NearbyDevicesHost(rootViewModel: rootViewModel)
                }
                .sheet(item: $quickActionLedger) { ledger in
                    ExpenseFormHost(rootViewModel: rootViewModel, ledgerId: ledger.id)
                }
                .onChangeCompat(of: appState.quickActionTarget) {
                    handleQuickAction()
                }
                .onAppear {
                    activateSharedLandingIfNeeded()
                    // 处理首次出现前已设置的 Quick Action 情况
                    handleQuickAction()
                }
                .onChangeCompat(of: appState.sharedTabActivateAt) {
                    activateSharedLandingIfNeeded()
                }
        }
        .background(Color.appBackground)
    }
    
    private func handleQuickAction() {
        guard case .shared(let ledgerId) = appState.quickActionTarget else {
            return
        }

        guard let summary = rootViewModel.ledgerSummaries.first(where: { $0.id == ledgerId }) else {
            appState.quickActionTarget = nil
            return
        }

        appState.quickActionTarget = nil

        onRequireLedgerTab()
        var newPath = NavigationPath()
        newPath.append(summary)
        path = newPath

        DispatchQueue.main.async {
            quickActionLedger = summary
        }
    }

    private func activateSharedLandingIfNeeded() {
        switch appState.getSharedLandingPreference() {
        case .list:
            break
        case .ledger(let ledgerId):
            guard let summary = rootViewModel.ledgerSummaries.first(where: { $0.id == ledgerId }) else {
                return
            }
            // 重置路径并跳转到指定账本
            var newPath = NavigationPath()
            newPath.append(summary)
            path = newPath
        }
    }
}
