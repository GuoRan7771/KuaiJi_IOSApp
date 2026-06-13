//
//  PersonalLedgerViews.swift
//  KuaiJi
//
//  Simplified SwiftUI surfaces for the personal ledger module.
//

import Charts
import Combine
import SwiftUI
import UIKit

enum PersonalLedgerRoute: Hashable {
    case allRecords(Date)
    case allRecordsAll
    case accounts
    case stats
    case export
    case archive
    case recordDetail(PersonalRecordRowViewData)
}

struct PersonalLedgerNavigator: View {
    @ObservedObject var root: PersonalLedgerRootViewModel
    @StateObject private var homeViewModel: PersonalLedgerHomeViewModel
    @State private var path: [PersonalLedgerRoute] = []
    @State private var showingRecordForm = false
    @State private var recordToEdit: PersonalRecordRowViewData?
    @EnvironmentObject var appState: AppState

    init(root: PersonalLedgerRootViewModel) {
        self.root = root
        _homeViewModel = StateObject(wrappedValue: root.makeHomeViewModel())
    }

    var body: some View {
        NavigationStack(path: $path) {
            PersonalLedgerHomeView(viewModel: homeViewModel,
                                   onCreateRecord: {
                                       recordToEdit = nil
                                       showingRecordForm = true
                                   },
                                   onShowArchive: {
                                       homeViewModel.prepareArchive()
                                       path.append(.archive)
                                   },
                                   onShowAllRecords: {
                                       path.append(.allRecordsAll)
                                   },
                                   onShowAccounts: { path.append(.accounts) },
                                   onShowStats: { path.append(.stats) },
                                   onShowExport: { path.append(.export) },
                                   onOpenRecord: { path.append(.recordDetail($0)) },
                                   onDeleteRecords: { ids in
                                       do {
                                           try root.store.deleteTransactionsOrTransfers(ids: ids)
                                       } catch {
                                           // swallow for now
                                       }
                                   },
                                   onEditRecord: { record in
                                       recordToEdit = record
                                       showingRecordForm = true
                                   })
            .navigationDestination(for: PersonalLedgerRoute.self) { route in
                switch route {
                case .allRecords(let date):
                    PersonalAllRecordsView(root: root, viewModel: root.makeAllRecordsViewModel(anchorDate: date))
                case .allRecordsAll:
                    PersonalAllRecordsView(root: root, viewModel: root.makeAllRecordsViewModelForAll())
                case .accounts:
                    PersonalAccountsView(root: root, viewModel: root.makeAccountsViewModel())
                case .stats:
                    PersonalStatsView(viewModel: root.makeStatsViewModel())
                case .export:
                    PersonalCSVExportView(root: root, viewModel: root.makeCSVExportViewModel())
                case .archive:
                    PersonalMonthlyArchiveView(viewModel: homeViewModel,
                                               onSelect: { month in
                        withAnimation(.easeInOut) {
                            path.append(.allRecords(month.date))
                        }
                    })
                case .recordDetail(let record):
                    if record.isTransfer {
                        PersonalTransferDetailView(root: root, record: record) { transfer in
                            // 打开转账编辑界面
                            path.removeAll(where: { if case .recordDetail = $0 { return true } else { return false } })
                            // 以转账编辑表单弹出
                            showingRecordForm = false
                            // 打开独立的转账编辑表单
                            // 使用统一入口：转账表单 Host
                            // 这里通过导航到账户页的转账表单以复用 ViewModel 能力
                            // 直接打开专用的转账编辑 Sheet
                            PersonalTransferEditSheet.present(root: root, transferId: transfer.remoteId)
                        }
                    } else {
                        PersonalRecordDetailView(root: root,
                                                 record: record,
                                                 onEdit: { editable in
                                                     recordToEdit = editable
                                                     showingRecordForm = true
                                                 })
                    }
                }
            }
            .sheet(isPresented: $showingRecordForm) {
                PersonalRecordFormHost(root: root, existing: recordToEdit) {
                    showingRecordForm = false
                    Task { await homeViewModel.refresh() }
                }
            }
            .navigationTitle(L.personalHomeTitle.localized)
            .onChange(of: appState.quickActionTarget) { _, target in
                guard case .personal = target else { return }
                recordToEdit = nil
                showingRecordForm = true
                appState.quickActionTarget = nil
            }
        }
    }
}
