//
//  PersonalAllRecordsView.swift
//  KuaiJi
//

import SwiftUI

struct PersonalAllRecordsView: View {
    @ObservedObject var root: PersonalLedgerRootViewModel
    @StateObject private var viewModel: PersonalAllRecordsViewModel
    @State private var editingRecord: PersonalRecordRowViewData?

    init(root: PersonalLedgerRootViewModel, viewModel: PersonalAllRecordsViewModel) {
        self.root = root
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List(selection: $viewModel.selection) {
            Section {
                ForEach(viewModel.records) { record in
                    PersonalRecordRow(record: record,
                                      onTap: { },
                                      onEdit: {
                                          editingRecord = record
                                      },
                                      onDelete: {
                                          Task { await viewModel.deleteRecord(id: record.id) }
                                      },
                                      timestampText: timestampText(for: record))
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let id = viewModel.records[index].id
                        Task { await viewModel.deleteRecord(id: id) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(monthTitle())
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Picker("", selection: $viewModel.sortMode) {
                        ForEach(PersonalAllRecordsViewModel.SortMode.allCases) { mode in
                            Text(mode.title)
                                .foregroundStyle(Color.appLedgerContentText)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundStyle(Color.appLedgerContentText)
                }
                if !viewModel.selection.isEmpty {
                    Button(L.delete.localized, role: .destructive) {
                        Task { await viewModel.deleteSelected() }
                    }
                }
            }
        }
        .task { await viewModel.refresh() }
        .alert(viewModel.lastError ?? "", isPresented: Binding(get: { viewModel.lastError != nil }, set: { _ in viewModel.lastError = nil })) {
            Button(L.ok.localized, action: {})
        }
        .sheet(item: $editingRecord) { record in
            PersonalRecordFormHost(root: root, existing: record) {
                editingRecord = nil
                Task { @MainActor in
                    try? root.store.refreshAccounts()
                    await viewModel.refresh()
                }
            }
        }
    }

    private func monthTitle() -> String {
        // 若 filterState 的范围正好是整月，则用"yyyy-MM 交易记录"，否则退回"全部记录"
        if let range = viewModel.filterState.dateRange {
            let cal = Calendar.current
            if let interval = cal.dateInterval(of: .month, for: range.lowerBound), interval.start == range.lowerBound && interval.end == range.upperBound {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM"
                return fmt.string(from: range.lowerBound) + " " + L.personalAllRecordsTitle.localized
            }
        }
        return L.personalAllRecordsTitle.localized
    }

    private func timestampText(for record: PersonalRecordRowViewData) -> String {
        let date: Date
        switch viewModel.sortMode {
        case .occurredAt:
            date = record.occurredAt
        case .createdAt:
            date = record.createdAt
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct FilterControls: View {
    @Binding var filterState: PersonalRecordFilterState
    var onApply: () -> Void
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            DatePicker(L.personalFilterFrom.localized, selection: Binding(get: {
                filterState.dateRange?.lowerBound ?? Date()
            }, set: { newValue in
                if let upper = filterState.dateRange?.upperBound {
                    filterState.dateRange = newValue...upper
                } else {
                    filterState.dateRange = newValue...Date()
                }
            }), displayedComponents: [.date])
            DatePicker(L.personalFilterTo.localized, selection: Binding(get: {
                filterState.dateRange?.upperBound ?? Date()
            }, set: { newValue in
                if let lower = filterState.dateRange?.lowerBound {
                    filterState.dateRange = lower...newValue
                } else {
                    filterState.dateRange = Date()...newValue
                }
            }), displayedComponents: [.date])
            TextField(L.personalFilterKeyword.localized, text: $filterState.keyword)
            HStack {
                TextField(L.personalFilterMin.localized, text: $filterState.minAmountText)
                    .keyboardType(.decimalPad)
                    .onChange(of: filterState.minAmountText) { oldValue, newValue in
                        let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 2, locale: .current, oldValue: oldValue)
                        if validated != newValue { filterState.minAmountText = validated }
                    }
                TextField(L.personalFilterMax.localized, text: $filterState.maxAmountText)
                    .keyboardType(.decimalPad)
                    .onChange(of: filterState.maxAmountText) { oldValue, newValue in
                        let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 2, locale: .current, oldValue: oldValue)
                        if validated != newValue { filterState.maxAmountText = validated }
                    }
            }
            Button(L.done.localized, action: onApply)
        } label: {
            Text(L.personalFilterTitle.localized)
        }
    }
}
