//
//  PersonalAccountsView.swift
//  KuaiJi
//

import SwiftUI

struct PersonalAccountsView: View {
    @ObservedObject var root: PersonalLedgerRootViewModel
    @StateObject private var viewModel: PersonalAccountsViewModel
    @State private var showingAccountForm = false
    @State private var editingAccount: UUID?
    @State private var showingTransferForm = false
    @State private var pendingDeleteId: UUID?

    init(root: PersonalLedgerRootViewModel, viewModel: PersonalAccountsViewModel) {
        self.root = root
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            Section(header: Text(L.personalAccountsSummary.localized)) {
                if viewModel.totalSummary.entries.isEmpty {
                    Text(L.personalNetWorthEmpty.localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.totalSummary.entries) { entry in
                        HStack {
                            Text("\(L.personalNetWorth.localized) (\(entry.currency.rawValue))")
                            Spacer()
                            Text(AmountFormatter.string(minorUnits: entry.totalMinorUnits,
                                                        currency: entry.currency,
                                                        locale: Locale.current))
                                .font(.headline)
                        }
                    }
                }
            }
            Section {
                Toggle(L.personalShowArchived.localized, isOn: $viewModel.showArchived)
                    .tint(Color.appToggleOn)
            }
            Section(header: Text(L.personalAccountsList.localized)) {
                ForEach(viewModel.accounts) { account in
                    AccountRow(account: account,
                               onEdit: { editingAccount = account.id; showingAccountForm = true },
                               onArchive: { Task { await viewModel.archiveAccount(account.id) } },
                               onActivate: { Task { await viewModel.activateAccount(account.id) } },
                               onDelete: { pendingDeleteId = account.id })
                }
                .onMove(perform: viewModel.move)
                .onDelete { indexSet in
                    pendingDeleteId = indexSet.first.map { viewModel.accounts[$0].id }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(L.personalAccountsTitle.localized)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingTransferForm = true }) {
                    Image(systemName: "arrow.left.arrow.right")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                ControlGroup {
                    Button(action: { editingAccount = nil; showingAccountForm = true }) {
                        Image(systemName: "plus")
                    }
                    EditButton()
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
        .alert(viewModel.lastError ?? "", isPresented: Binding(get: { viewModel.lastError != nil }, set: { _ in viewModel.lastError = nil })) {
            Button(L.ok.localized, action: {})
        }
        .alert(L.delete.localized, isPresented: Binding(get: { pendingDeleteId != nil }, set: { v in if !v { pendingDeleteId = nil } })) {
            Button(L.cancel.localized, role: .cancel) { pendingDeleteId = nil }
            Button(L.delete.localized, role: .destructive) {
                if let id = pendingDeleteId {
                    Task { await viewModel.deleteAccount(id) }
                    pendingDeleteId = nil
                }
            }
        } message: {
            Text(L.personalDeleteConfirm.localized)
        }
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
            Button(L.edit.localized, action: onEdit).tint(Color.appTextPrimary)
            if account.status == .active {
                Button(L.personalArchive.localized, action: onArchive).tint(Color.appTextPrimary)
            } else {
                Button(L.personalActivate.localized, action: onActivate).tint(Color.appTextPrimary)
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
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
    }
}

struct PersonalAccountFormView: View {
    @ObservedObject var viewModel: PersonalAccountFormViewModel
    var onDone: () -> Void
    @State private var balanceText: String
    @State private var creditLimitText: String
    @FocusState private var balanceFieldFocused: Bool

    init(viewModel: PersonalAccountFormViewModel, onDone: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
        if viewModel.draft.initialBalance == 0 {
            _balanceText = State(initialValue: "")
        } else {
            _balanceText = State(initialValue: NSDecimalNumber(decimal: viewModel.draft.initialBalance).stringValue)
        }
        if let limit = viewModel.draft.creditLimit {
            _creditLimitText = State(initialValue: NSDecimalNumber(decimal: limit).stringValue)
        } else {
            _creditLimitText = State(initialValue: "")
        }
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
                        Text(code.displayLabel).tag(code)
                    }
                }
            }
            Section(header: Text(L.personalFieldBalance.localized)) {
                TextField(L.personalFieldBalance.localized, text: $balanceText)
                    .keyboardType(.decimalPad)
                    .focused($balanceFieldFocused)
                    .onChange(of: balanceText) { oldValue, newValue in
                        let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 2, locale: .current, oldValue: oldValue)
                        if validated != newValue { balanceText = validated }
                        let trimmed = validated.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            viewModel.draft.initialBalance = 0
                        } else if let decimal = NumberParsing.parseDecimal(trimmed) {
                            viewModel.draft.initialBalance = decimal
                        }
                    }
                Toggle(L.personalIncludeInNet.localized, isOn: $viewModel.draft.includeInNetWorth)
                    .tint(Color.appToggleOn)
                if viewModel.draft.type == .creditCard {
                    TextField(L.personalFieldCreditLimit.localized, text: $creditLimitText)
                        .keyboardType(.decimalPad)
                        .onChange(of: creditLimitText) { oldValue, newValue in
                            let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 2, locale: .current, oldValue: oldValue)
                            if validated != newValue { creditLimitText = validated }
                            let trimmed = validated.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty {
                                viewModel.draft.creditLimit = nil
                            } else if let decimal = NumberParsing.parseDecimal(trimmed) {
                                viewModel.draft.creditLimit = decimal
                            }
                        }
                }
                if viewModel.draft.id != nil {
                    Picker(L.personalAccountStatus.localized, selection: $viewModel.draft.status) {
                        Text(L.personalStatusActive.localized).tag(PersonalAccountStatus.active)
                        Text(L.personalStatusArchived.localized).tag(PersonalAccountStatus.archived)
                    }
                }
                TextField(L.personalFieldNote.localized, text: Binding($viewModel.draft.note, replacingNilWith: ""), axis: .vertical)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .tint(Color.appTextPrimary)
        .dismissKeyboardOnTap()
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
        .onAppear {
            if viewModel.draft.id == nil {
                DispatchQueue.main.async {
                    balanceFieldFocused = true
                }
            }
        }
        .onChange(of: viewModel.draft.type) { _, newValue in
            if newValue != .creditCard {
                creditLimitText = ""
                viewModel.draft.creditLimit = nil
            }
        }
    }
}
