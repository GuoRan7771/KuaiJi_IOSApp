//
//  PersonalLedgerViews.swift
//  KuaiJi
//
//  Simplified SwiftUI surfaces for the personal ledger module.
//

import Charts
import PhotosUI
import SwiftUI
import UIKit

enum PersonalLedgerRoute: Hashable {
    case allRecords(Date)
    case accounts
    case stats
    case recordDetail(PersonalRecordRowViewData)
}

struct PersonalLedgerNavigator: View {
    @ObservedObject var root: PersonalLedgerRootViewModel
    @StateObject private var homeViewModel: PersonalLedgerHomeViewModel
    @State private var path: [PersonalLedgerRoute] = []
    @State private var showingRecordForm = false
    @State private var recordToEdit: PersonalRecordRowViewData?

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
                                   onShowAll: { path.append(.allRecords(homeViewModel.selectedMonth)) },
                                   onShowAccounts: { path.append(.accounts) },
                                   onShowStats: { path.append(.stats) },
                                   onOpenRecord: { path.append(.recordDetail($0)) },
                                   onDeleteRecords: { ids in
                                       do {
                                           try root.store.deleteTransactions(ids: ids)
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
                case .accounts:
                    PersonalAccountsView(root: root, viewModel: root.makeAccountsViewModel())
                case .stats:
                    PersonalStatsView(viewModel: root.makeStatsViewModel())
                case .recordDetail(let record):
                    PersonalRecordDetailView(root: root,
                                             record: record,
                                             onEdit: { editable in
                                                 recordToEdit = editable
                                                 showingRecordForm = true
                                             })
                }
            }
            .sheet(isPresented: $showingRecordForm) {
                PersonalRecordFormHost(root: root, existing: recordToEdit) {
                    showingRecordForm = false
                    Task { await homeViewModel.refresh() }
                }
            }
            .navigationTitle(L.personalHomeTitle.localized)
        }
    }
}

struct PersonalLedgerHomeView: View {
    @ObservedObject var viewModel: PersonalLedgerHomeViewModel
    var onCreateRecord: () -> Void
    var onShowAll: () -> Void
    var onShowAccounts: () -> Void
    var onShowStats: () -> Void
    var onOpenRecord: (PersonalRecordRowViewData) -> Void
    var onDeleteRecords: ([UUID]) async -> Void
    var onEditRecord: (PersonalRecordRowViewData) -> Void

    @State private var selection: Set<UUID> = []
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List(selection: $selection) {
                Section {
                    PersonalOverviewCard(overview: viewModel.overview,
                                         onPrevious: { viewModel.changeMonth(by: -1) },
                                         onNext: { viewModel.changeMonth(by: 1) })
                        .listRowInsets(EdgeInsets())
                }
                Section(header: TodayHeader(onShowAll: onShowAll)) {
                    if viewModel.todayRecords.isEmpty {
                        Text(L.personalTodayEmpty.localized)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(viewModel.todayRecords) { record in
                            PersonalRecordRow(record: record,
                                              onTap: { onOpenRecord(record) },
                                              onEdit: { onEditRecord(record) },
                                              onDelete: { deleteRecords([record.id]) })
                        }
                        .onDelete { indexSet in
                            let ids = indexSet.compactMap { viewModel.todayRecords[$0].id }
                            deleteRecords(ids)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !selection.isEmpty {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label(L.delete.localized, systemImage: "trash")
                        }
                    }
                    EditButton()
                    Button(action: onShowStats) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                    }
                    Button(action: onShowAccounts) {
                        Image(systemName: "creditcard")
                    }
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
            }
        }
    }
}

private struct FloatingActionButton: View {
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title)
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Color.accentColor))
                .shadow(radius: 4, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct PersonalOverviewCard: View {
    var overview: PersonalOverviewState
    var onPrevious: () -> Void
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text(L.personalThisMonth.localized)
                    .font(.headline)
                Spacer()
                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                }
            }
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L.personalMonthlyExpense.localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(AmountFormatter.string(minorUnits: overview.expenseMinorUnits,
                                                currency: overview.displayCurrency,
                                                locale: Locale.current))
                        .font(.title2)
                        .foregroundStyle(.red)
                }
                Spacer()
                VStack(alignment: .leading, spacing: 6) {
                    Text(L.personalMonthlyIncome.localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(AmountFormatter.string(minorUnits: overview.incomeMinorUnits,
                                                currency: overview.displayCurrency,
                                                locale: Locale.current))
                        .font(.title2)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
        .padding(.horizontal)
    }
}

struct PersonalRecordRow: View {
    var record: PersonalRecordRowViewData
    var onTap: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.categoryName)
                    .font(.headline)
                if !record.note.isEmpty {
                    Text(record.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(AmountFormatter.string(minorUnits: record.amountMinorUnits,
                                            currency: record.currency,
                                            locale: Locale.current))
                    .foregroundStyle(record.amountIsPositive ? Color.green : Color.red)
                Text(record.occurredAt, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button(L.edit.localized, action: onEdit)
            Button(L.delete.localized, role: .destructive, action: onDelete)
        }
        .swipeActions {
            Button(role: .destructive, action: onDelete) {
                Label(L.delete.localized, systemImage: "trash")
            }
            Button(action: onEdit) {
                Label(L.edit.localized, systemImage: "pencil")
            }
            .tint(.blue)
        }
    }
}

struct PersonalRecordDetailView: View {
    @ObservedObject var root: PersonalLedgerRootViewModel
    var record: PersonalRecordRowViewData
    var onEdit: (PersonalRecordRowViewData) -> Void
    @State private var showingDeleteAlert = false

    var body: some View {
        List {
            Section(header: Text(L.personalDetailSection.localized)) {
                DetailRow(title: L.personalDetailCategory.localized, value: record.categoryName)
                DetailRow(title: L.personalDetailAccount.localized, value: record.accountName)
                DetailRow(title: L.personalDetailType.localized, value: record.kindDisplay)
                DetailRow(title: L.personalDetailAmount.localized,
                          value: AmountFormatter.string(minorUnits: record.amountMinorUnits,
                                                         currency: record.currency,
                                                         locale: Locale.current))
                DetailRow(title: L.personalDetailDate.localized,
                          value: record.occurredAt.formatted(date: .abbreviated, time: .shortened))
                if !record.note.isEmpty {
                    DetailRow(title: L.personalDetailNote.localized, value: record.note)
                }
            }
        }
        .navigationTitle(record.categoryName)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(L.edit.localized) { onEdit(record) }
                Button(role: .destructive) { showingDeleteAlert = true } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .alert(L.delete.localized, isPresented: $showingDeleteAlert) {
            Button(L.cancel.localized, role: .cancel) {}
            Button(L.delete.localized, role: .destructive) {
                Task {
                    try? root.store.deleteTransactions(ids: [record.id])
                }
            }
        } message: {
            Text(L.personalDeleteConfirm.localized)
        }
    }
}

private struct DetailRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

struct PersonalRecordFormHost: View {
    @StateObject private var viewModel: PersonalRecordFormViewModel
    var onDismiss: () -> Void

    init(root: PersonalLedgerRootViewModel, existing: PersonalRecordRowViewData?, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: root.makeRecordFormViewModel(existing: existing))
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            PersonalRecordFormView(viewModel: viewModel, onDone: onDismiss)
        }
    }
}

struct PersonalRecordFormView: View {
    @ObservedObject var viewModel: PersonalRecordFormViewModel
    var onDone: () -> Void
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        Form {
            Section(header: Text(L.personalFieldType.localized)) {
                Picker("", selection: $viewModel.kind) {
                    Text(L.personalTypeExpense.localized).tag(PersonalTransactionKind.expense)
                    Text(L.personalTypeIncome.localized).tag(PersonalTransactionKind.income)
                }
                .pickerStyle(.segmented)
            }
            Section(header: Text(L.personalFieldAccount.localized)) {
                Picker(L.personalFieldAccount.localized, selection: Binding(get: { viewModel.accountId }, set: viewModel.selectAccount)) {
                    ForEach(viewModel.accounts) { account in
                        Text("\(account.name) · \(account.currency.rawValue)").tag(account.remoteId as UUID?)
                    }
                }
            }
            Section(header: Text(L.personalFieldCategory.localized)) {
                Picker(L.personalFieldCategory.localized, selection: $viewModel.categoryKey) {
                    ForEach(viewModel.categoryOptions, id: \.key) { option in
                        Text(option.localizedName).tag(option.key)
                    }
                }
            }
            Section(header: Text(L.personalFieldAmount.localized)) {
                TextField(L.personalFieldAmount.localized, text: $viewModel.amountText)
                    .keyboardType(.decimalPad)
                if viewModel.showFXField {
                    TextField(L.personalFieldFXRate.localized, text: $viewModel.fxRateText)
                        .keyboardType(.decimalPad)
                }
                DatePicker(L.personalFieldDate.localized, selection: $viewModel.occurredAt, displayedComponents: [.date, .hourAndMinute])
                TextField(L.personalFieldNote.localized, text: $viewModel.note, axis: .vertical)
            }
            Section(header: Text(L.personalFieldAttachment.localized)) {
                if let url = viewModel.attachmentURL {
                    HStack {
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                        Spacer()
                        Button(role: .destructive, action: viewModel.removeAttachment) {
                            Image(systemName: "trash")
                        }
                    }
                }
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(L.personalFieldPickPhoto.localized, systemImage: "photo")
                }
                .onChange(of: selectedPhoto) { newItem in
                    guard let item = newItem else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self) {
                            try? viewModel.saveAttachment(data: data, fileExtension: "jpg")
                        }
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L.cancel.localized, action: onDone)
            }
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Button(L.save.localized) {
                        Task {
                            let success = await viewModel.submit()
                            if success { onDone() }
                        }
                    }
                }
            }
        }
        .alert(viewModel.errorMessage ?? "", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })) {
            Button(L.ok.localized, action: {})
        }
    }
}

struct PersonalAllRecordsView: View {
    @ObservedObject var root: PersonalLedgerRootViewModel
    @StateObject private var viewModel: PersonalAllRecordsViewModel
    @State private var showingShareError = false

    init(root: PersonalLedgerRootViewModel, viewModel: PersonalAllRecordsViewModel) {
        self.root = root
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List(selection: $viewModel.selection) {
            FilterControls(filterState: $viewModel.filterState) {
                Task { await viewModel.refresh() }
            }
            Section {
                ForEach(viewModel.records) { record in
                    PersonalRecordRow(record: record,
                                      onTap: { },
                                      onEdit: { },
                                      onDelete: {
                                          viewModel.selection = [record.id]
                                          Task { await viewModel.deleteSelected() }
                                      })
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L.personalAllRecordsTitle.localized)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if !viewModel.selection.isEmpty {
                    Button(L.delete.localized, role: .destructive) {
                        Task { await viewModel.deleteSelected() }
                    }
                }
                Button {
                    do {
                        let url = try viewModel.exportCSV()
                        ShareSheet.present(url: url)
                    } catch {
                        showingShareError = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .task { await viewModel.refresh() }
        .alert(L.personalExportFailed.localized, isPresented: $showingShareError) {
            Button(L.ok.localized, action: {})
        }
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
                TextField(L.personalFilterMax.localized, text: $filterState.maxAmountText)
                    .keyboardType(.decimalPad)
            }
            Button(L.done.localized, action: onApply)
        } label: {
            Text(L.personalFilterTitle.localized)
        }
    }
}

struct PersonalAccountsView: View {
    @ObservedObject var root: PersonalLedgerRootViewModel
    @StateObject private var viewModel: PersonalAccountsViewModel
    @State private var showingAccountForm = false
    @State private var editingAccount: UUID?
    @State private var showingTransferForm = false

    init(root: PersonalLedgerRootViewModel, viewModel: PersonalAccountsViewModel) {
        self.root = root
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            Section(header: Text(L.personalAccountsSummary.localized)) {
                HStack {
                    Text(L.personalNetWorth.localized)
                    Spacer()
                    Text(AmountFormatter.string(minorUnits: viewModel.totalSummary.totalMinorUnits,
                                                currency: viewModel.totalSummary.displayCurrency,
                                                locale: Locale.current))
                        .font(.headline)
                }
            }
            Section {
                Toggle(L.personalShowArchived.localized, isOn: $viewModel.showArchived)
            }
            Section(header: Text(L.personalAccountsList.localized)) {
                ForEach(viewModel.accounts) { account in
                    AccountRow(account: account,
                               onEdit: { editingAccount = account.id; showingAccountForm = true },
                               onArchive: { Task { await viewModel.archiveAccount(account.id) } },
                               onActivate: { Task { await viewModel.activateAccount(account.id) } },
                               onDelete: { Task { await viewModel.deleteAccount(account.id) } })
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L.personalAccountsTitle.localized)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(action: { editingAccount = nil; showingAccountForm = true }) {
                    Image(systemName: "plus")
                }
                Button(action: { showingTransferForm = true }) {
                    Image(systemName: "arrow.left.arrow.right")
                }
            }
        }
        .sheet(isPresented: $showingAccountForm) {
            PersonalAccountFormHost(root: root, accountId: editingAccount) {
                showingAccountForm = false
                Task { await viewModel.refresh() }
            }
        }
        .sheet(isPresented: $showingTransferForm) {
            PersonalTransferFormHost(root: root) {
                showingTransferForm = false
                Task { await viewModel.refresh() }
            }
        }
        .task { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
    }
}

private struct AccountRow: View {
    var account: PersonalAccountRowViewData
    var onEdit: () -> Void
    var onArchive: () -> Void
    var onActivate: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(account.name)
                    .font(.headline)
                Spacer()
                if account.includeInNetWorth {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            }
            HStack {
                Text(account.typeDisplay)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(AmountFormatter.string(minorUnits: account.balanceMinorUnits,
                                            currency: account.currency,
                                            locale: Locale.current))
                    .font(.headline)
            }
        }
        .padding(.vertical, 6)
        .swipeActions {
            Button(L.edit.localized, action: onEdit).tint(.blue)
            if account.status == .active {
                Button(L.personalArchive.localized, action: onArchive).tint(.orange)
            } else {
                Button(L.personalActivate.localized, action: onActivate).tint(.green)
            }
            Button(role: .destructive, action: onDelete) {
                Label(L.delete.localized, systemImage: "trash")
            }
        }
        .contextMenu {
            Button(L.edit.localized, action: onEdit)
            if account.status == .active {
                Button(L.personalArchive.localized, action: onArchive)
            } else {
                Button(L.personalActivate.localized, action: onActivate)
            }
            Button(L.delete.localized, role: .destructive, action: onDelete)
        }
    }
}

struct PersonalAccountFormHost: View {
    @StateObject private var viewModel: PersonalAccountFormViewModel
    var onDismiss: () -> Void

    init(root: PersonalLedgerRootViewModel, accountId: UUID?, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: root.makeAccountFormViewModel(accountId: accountId))
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            PersonalAccountFormView(viewModel: viewModel, onDone: onDismiss)
        }
    }
}

struct PersonalAccountFormView: View {
    @ObservedObject var viewModel: PersonalAccountFormViewModel
    var onDone: () -> Void
    @State private var balanceText: String

    init(viewModel: PersonalAccountFormViewModel, onDone: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
        _balanceText = State(initialValue: NSDecimalNumber(decimal: viewModel.draft.initialBalance).stringValue)
    }

    var body: some View {
        Form {
            Section(header: Text(L.personalFieldName.localized)) {
                TextField(L.personalFieldName.localized, text: $viewModel.draft.name)
                Picker(L.personalAccountTypeLabel.localized, selection: $viewModel.draft.type) {
                    ForEach(PersonalAccountType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                Picker(L.personalFieldCurrency.localized, selection: $viewModel.draft.currency) {
                    ForEach(CurrencyCode.allCases, id: \.self) { code in
                        Text(code.rawValue).tag(code)
                    }
                }
            }
            Section(header: Text(L.personalFieldBalance.localized)) {
                TextField(L.personalFieldBalance.localized, text: $balanceText)
                    .keyboardType(.decimalPad)
                    .onChange(of: balanceText) { newValue in
                        if let decimal = Decimal(string: newValue) {
                            viewModel.draft.initialBalance = decimal
                        }
                    }
                Toggle(L.personalIncludeInNet.localized, isOn: $viewModel.draft.includeInNetWorth)
                if viewModel.draft.id != nil {
                    Picker(L.personalAccountStatus.localized, selection: $viewModel.draft.status) {
                        Text(L.personalStatusActive.localized).tag(PersonalAccountStatus.active)
                        Text(L.personalStatusArchived.localized).tag(PersonalAccountStatus.archived)
                    }
                }
                TextField(L.personalFieldNote.localized, text: Binding($viewModel.draft.note, replacingNilWith: ""), axis: .vertical)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L.cancel.localized, action: onDone)
            }
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Button(L.save.localized) {
                        Task {
                            let success = await viewModel.submit()
                            if success { onDone() }
                        }
                    }
                }
            }
        }
        .alert(viewModel.errorMessage ?? "", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })) {
            Button(L.ok.localized, action: {})
        }
    }
}

struct PersonalTransferFormHost: View {
    @StateObject private var viewModel: PersonalTransferFormViewModel
    var onDismiss: () -> Void

    init(root: PersonalLedgerRootViewModel, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: root.makeTransferFormViewModel())
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            PersonalTransferFormView(viewModel: viewModel, onDone: onDismiss)
        }
    }
}

struct PersonalTransferFormView: View {
    @ObservedObject var viewModel: PersonalTransferFormViewModel
    var onDone: () -> Void

    var body: some View {
        Form {
            Section(header: Text(L.personalTransferAccounts.localized)) {
                Picker(L.personalTransferFrom.localized, selection: $viewModel.fromAccountId) {
                    ForEach(viewModel.accounts) { account in
                        Text(account.name).tag(account.remoteId as UUID?)
                    }
                }
                Picker(L.personalTransferTo.localized, selection: $viewModel.toAccountId) {
                    ForEach(viewModel.accounts) { account in
                        Text(account.name).tag(account.remoteId as UUID?)
                    }
                }
            }
            Section(header: Text(L.personalTransferAmount.localized)) {
                TextField(L.personalFieldAmount.localized, text: $viewModel.amountText)
                    .keyboardType(.decimalPad)
                TextField(L.personalFieldFXRate.localized, text: $viewModel.fxRateText)
                    .keyboardType(.decimalPad)
                TextField(L.personalTransferFee.localized, text: $viewModel.feeText)
                    .keyboardType(.decimalPad)
                Picker(L.personalTransferFeeSide.localized, selection: $viewModel.selectedFeeSide) {
                    Text(L.personalTransferFeeFrom.localized).tag(PersonalTransferFeeSide.from)
                    Text(L.personalTransferFeeTo.localized).tag(PersonalTransferFeeSide.to)
                }
                DatePicker(L.personalFieldDate.localized, selection: $viewModel.occurredAt, displayedComponents: [.date, .hourAndMinute])
                TextField(L.personalFieldNote.localized, text: $viewModel.note)
            }
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L.cancel.localized, action: onDone)
            }
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Button(L.save.localized) {
                        Task {
                            let success = await viewModel.submit()
                            if success { onDone() }
                        }
                    }
                }
            }
        }
        .alert(viewModel.errorMessage ?? "", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })) {
            Button(L.ok.localized, action: {})
        }
    }
}

struct PersonalStatsView: View {
    @ObservedObject var viewModel: PersonalStatsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker(L.personalStatsPeriod.localized, selection: $viewModel.period) {
                    ForEach(PersonalStatsViewModel.Period.allCases) { period in
                        Text(period.displayName).tag(period)
                    }
                }
                .pickerStyle(.segmented)

                Toggle(L.personalStatsIncludeFee.localized, isOn: $viewModel.includeFees)
                    .toggleStyle(.switch)

                if !viewModel.timeline.isEmpty {
                    Chart(viewModel.timeline) { point in
                        LineMark(x: .value("Date", point.date), y: .value("Income", point.incomeMinorUnits))
                            .foregroundStyle(.green)
                        LineMark(x: .value("Date", point.date), y: .value("Expense", point.expenseMinorUnits))
                            .foregroundStyle(.red)
                    }
                    .frame(height: 220)
                }

                if !viewModel.breakdown.isEmpty {
                    Chart(viewModel.breakdown) { item in
                        BarMark(x: .value("Category", item.categoryKey),
                                y: .value("Amount", item.amountMinorUnits))
                    }
                    .frame(height: 220)
                }
            }
            .padding()
        }
        .navigationTitle(L.personalStatsTitle.localized)
    }
}


extension PersonalFXSource {
    var displayName: String {
        switch self {
        case .manual: return L.personalFXSourceManual.localized
        case .fixed: return L.personalFXSourceFixed.localized
        }
    }
}
extension PersonalStatsViewModel.Period {
    var displayName: String {
        switch self {
        case .month: return L.personalStatsMonth.localized
        case .quarter: return L.personalStatsQuarter.localized
        case .year: return L.personalStatsYear.localized
        }
    }
}

extension PersonalRecordRowViewData {
    var kindDisplay: String {
        switch kind {
        case .income: return L.personalTypeIncome.localized
        case .expense: return L.personalTypeExpense.localized
        case .fee: return L.personalTypeFee.localized
        }
    }
}

extension PersonalAccountRowViewData {
    var typeDisplay: String { type.displayName }
}

extension PersonalAccountType {
    var displayName: String {
        switch self {
        case .bankCard: return L.personalAccountTypeBank.localized
        case .mobilePayment: return L.personalAccountTypeMobile.localized
        case .cash: return L.personalAccountTypeCash.localized
        case .creditCard: return L.personalAccountTypeCredit.localized
        case .prepaid: return L.personalAccountTypePrepaid.localized
        case .other: return L.personalAccountTypeOther.localized
        }
    }
}

extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith defaultValue: String) {
        self.init(get: { source.wrappedValue ?? defaultValue },
                  set: { source.wrappedValue = $0 })
    }
}

private enum ShareSheet {
    static func present(url: URL) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        root.present(controller, animated: true)
    }
}
