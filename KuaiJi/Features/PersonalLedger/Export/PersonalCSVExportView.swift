//
//  PersonalCSVExportView.swift
//  KuaiJi
//
//  Personal ledger CSV export UI and share bridge.
//

import SwiftUI
import UIKit

private enum ShareSheet {
    static func present(url: URL) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        root.present(controller, animated: true)
    }
}

// MARK: - Personal CSV Export UI

struct PersonalCSVExportView: View {
    @ObservedObject var root: PersonalLedgerRootViewModel
    @StateObject var viewModel: PersonalCSVExportViewModel
    @State private var showingRecordForm = false
    @State private var editingRecord: PersonalRecordRowViewData?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PersonalCSVExportContent(viewModel: viewModel, store: root.store, onEdit: { record in
                editingRecord = record
            })
            FloatingActionButton(systemImage: "plus") {
                showingRecordForm = true
            }
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
        .navigationTitle(L.personalExportCSV.localized)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingRecordForm) {
            PersonalRecordFormHost(root: root, existing: nil) {
                showingRecordForm = false
                Task { await viewModel.refresh() }
            }
        }
        .sheet(item: $editingRecord) { record in
            PersonalRecordFormHost(root: root, existing: record) {
                editingRecord = nil
                Task { await viewModel.refresh() }
            }
        }
    }
}

private struct PersonalCSVExportContent: View {
    @ObservedObject var viewModel: PersonalCSVExportViewModel
    let store: PersonalLedgerStore
    var onEdit: (PersonalRecordRowViewData) -> Void

    var body: some View {
        List {
            Section(header: Text(L.personalFilterTitle.localized)) {
                Picker(L.personalStatsPeriod.localized, selection: $viewModel.periodMode) {
                    Text(L.personalStatsMonth.localized).tag(PersonalCSVExportViewModel.PeriodMode.month)
                    Text(L.personalStatsQuarter.localized).tag(PersonalCSVExportViewModel.PeriodMode.quarter)
                    Text(L.personalStatsYear.localized).tag(PersonalCSVExportViewModel.PeriodMode.year)
                    Text(L.personalFilterTitle.localized).tag(PersonalCSVExportViewModel.PeriodMode.range)
                }
                .pickerStyle(.segmented)

                if viewModel.periodMode == .range {
                    DatePicker(L.personalFilterFrom.localized, selection: $viewModel.fromDate, displayedComponents: .date)
                    DatePicker(L.personalExportUntil.localized, selection: $viewModel.toDate, displayedComponents: .date)
                } else {
                    HStack(spacing: 8) {
                        Text(L.personalExportUntil.localized)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $viewModel.anchorDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(L.personalAccountsList.localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.activeAccounts) { account in
                                let selected = viewModel.selectedAccountIds.contains(account.remoteId)
                                Button(action: {
                                    if selected { viewModel.selectedAccountIds.remove(account.remoteId) }
                                    else { viewModel.selectedAccountIds.insert(account.remoteId) }
                                }) {
                                    Text(account.name)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Color.appBrand.opacity(0.2) : Color.appSurfaceAlt))
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(L.personalPrimaryCurrency.localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(Set(store.activeAccounts.map { $0.currency })).sorted { $0.rawValue < $1.rawValue }, id: \.self) { code in
                                let selected = viewModel.selectedCurrencies.contains(code)
                                Button(action: {
                                    if selected { viewModel.selectedCurrencies.remove(code) }
                                    else { viewModel.selectedCurrencies.insert(code) }
                                }) {
                                    Text(code.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Color.appBrand.opacity(0.2) : Color.appSurfaceAlt))
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section(header: Text(L.personalAccountsSummary.localized)) {
                let selectedIds = viewModel.selectedAccountIds
                let accounts = store.activeAccounts.filter { selectedIds.isEmpty || selectedIds.contains($0.remoteId) }
                if accounts.isEmpty {
                    Text(L.recordsEmpty.localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(accounts) { account in
                        HStack {
                            Text(account.name)
                                .font(.footnote)
                            Spacer()
                            Text(AmountFormatter.string(minorUnits: account.balanceMinorUnits,
                                                        currency: account.currency,
                                                        locale: Locale.current))
                                .font(.footnote)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section(header: Text(L.personalAllRecordsTitle.localized)) {
                if viewModel.records.isEmpty {
                    Text(L.recordsEmpty.localized)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.records) { record in
                        PersonalRecordRow(record: record,
                                          onTap: { onEdit(record) },
                                          onEdit: { onEdit(record) },
                                          onDelete: {
                                              Task { await viewModel.delete(recordId: record.id) }
                                          },
                                          timestampText: record.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("", selection: $viewModel.sortMode) {
                        ForEach(PersonalAllRecordsViewModel.SortMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    do {
                        let url = try viewModel.exportCSV()
                        ShareSheet.present(url: url)
                    } catch { }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(Text(L.personalExportCSV.localized))
            }
        }
    }
}
