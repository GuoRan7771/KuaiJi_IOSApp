//
//  PersonalLedgerHomeView.swift
//  KuaiJi
//

import SwiftUI

struct PersonalLedgerHomeView: View {
    @ObservedObject var viewModel: PersonalLedgerHomeViewModel
    var onCreateRecord: () -> Void
    var onShowArchive: () -> Void
    var onShowAllRecords: () -> Void
    var onShowAccounts: () -> Void
    var onShowStats: () -> Void
    var onShowExport: () -> Void
    var onOpenRecord: (PersonalRecordRowViewData) -> Void
    var onDeleteRecords: ([UUID]) async -> Void
    var onEditRecord: (PersonalRecordRowViewData) -> Void

    @State private var selection: Set<UUID> = []
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List(selection: $selection) {
                Section {
                    HStack {
                        Spacer()
                        Button(action: onShowArchive) {
                            Text(L.all.localized)
                                .foregroundStyle(Color.appLedgerContentText)
                        }
                    }
                    .padding(.horizontal)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    PersonalOverviewCard(selectedMonth: viewModel.selectedMonth,
                                         overview: viewModel.overview,
                                         canGoPrevious: viewModel.canGoToPreviousMonth,
                                         canGoNext: viewModel.canGoToNextMonth,
                                         onPrevious: { viewModel.changeMonth(by: -1) },
                                         onNext: { viewModel.changeMonth(by: 1) })
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                Section(header: TodayHeader(onShowAll: onShowAllRecords)) {
                    if viewModel.todayRecords.isEmpty {
                        Text(L.personalTodayEmpty.localized)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.appSecondaryText)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(viewModel.todayRecords) { record in
                            PersonalRecordRow(record: record,
                                              onTap: { onOpenRecord(record) },
                                              onEdit: { onEditRecord(record) },
                                              onDelete: { deleteRecords([record.id]) })
                            .listRowBackground(Color.clear)
                        }
                        .onDelete { indexSet in
                            let ids = indexSet.compactMap { viewModel.todayRecords[$0].id }
                            deleteRecords(ids)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button(action: onShowExport) {
                        Label(L.personalExportCSV.localized, systemImage: "square.and.arrow.up")
                    }
                    .tint(Color.appTextPrimary)
                    Button(action: onShowStats) {
                        Label(L.personalStatsTitle.localized, systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tint(Color.appTextPrimary)
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !selection.isEmpty {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label(L.delete.localized, systemImage: "trash")
                        }
                    }
                    Button(action: onShowAccounts) {
                        Label(L.personalAccountsManage.localized, systemImage: "creditcard")
                    }
                    .tint(Color.appTextPrimary)
                }
            }
            .alert(L.delete.localized, isPresented: $showingDeleteConfirmation) {
                Button(L.cancel.localized, role: .cancel) { }
                Button(L.delete.localized, role: .destructive) {
                    deleteRecords(Array(selection))
                }
            } message: {
                Text(L.personalDeleteConfirm.localized)
            }

            FloatingActionButton(systemImage: "plus", action: onCreateRecord)
                .padding(.trailing, 24)
                .padding(.bottom, 24)
        }
        .task { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
    }

    private func deleteRecords(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        Task {
            await onDeleteRecords(ids)
            selection.subtract(ids)
            await viewModel.refresh()
        }
    }
}

private struct TodayHeader: View {
    var onShowAll: () -> Void

    var body: some View {
        HStack {
            Text(L.personalTodayTitle.localized)
                .font(.headline)
            Spacer()
            Button(action: onShowAll) {
                Text(L.all.localized)
                    .foregroundStyle(Color.appLedgerContentText)
            }
        }
    }
}
