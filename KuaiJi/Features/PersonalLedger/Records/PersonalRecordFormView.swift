//
//  PersonalRecordFormView.swift
//  KuaiJi
//

import SwiftUI

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
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
    }
}

private struct SharedLedgerOption: Identifiable, Hashable {
    var id: UUID
    var name: String
    var currency: CurrencyCode
}

private struct SharedExpenseDraft: Identifiable, Hashable {
    var id: UUID = UUID()
    var amount: Decimal
    var currency: CurrencyCode
    var occurredAt: Date
    var category: ExpenseCategory
    var note: String
}

private extension SharedLedgerQuickAdd.SplitMode {
    var title: String {
        switch self {
        case .equalShares:
            return L.personalSaveAndShareModeEqual.localized
        case .payerTreat:
            return L.personalSaveAndShareModeTreat.localized
        }
    }
}

extension ExpenseCategory {
    var localizedName: String {
        switch self {
        case .food: return L.categoryFood.localized
        case .transport: return L.categoryTransport.localized
        case .accommodation: return L.categoryAccommodation.localized
        case .entertainment: return L.categoryEntertainment.localized
        case .utilities: return L.categoryUtilities.localized
        case .selfImprovement: return L.categorySelfImprovement.localized
        case .school: return L.categorySchool.localized
        case .medical: return L.categoryMedical.localized
        case .clothing: return L.categoryClothing.localized
        case .investment: return L.categoryInvestment.localized
        case .social: return L.categorySocial.localized
        case .other: return L.categoryOther.localized
        }
    }
}

private struct SaveToSharedSheet: View {
    var draft: SharedExpenseDraft
    var ledgers: [SharedLedgerOption]
    @Binding var selectedLedgerId: UUID?
    var onConfirm: (QuickSplitConfiguration) -> Void
    var onCancel: () -> Void

    private var selectedLedger: SharedLedgerOption? {
        guard let selectedLedgerId else { return nil }
        return ledgers.first(where: { $0.id == selectedLedgerId })
    }

    private var currencyMismatch: Bool {
        guard let ledger = selectedLedger else { return false }
        return ledger.currency != draft.currency
    }

    @EnvironmentObject private var appRootViewModel: AppRootViewModel
    @EnvironmentObject private var appState: AppState
    @AppStorage("theme") private var theme = "default"
    @State private var splitOption: ExpenseSplitOption = .meAllAA
    @State private var members: [MemberSummaryViewData] = []
    @State private var selectedOtherPayerId: UUID?
    @State private var selectedHelpPayPayerId: UUID?
    @State private var selectedBeneficiaryId: UUID?

    var body: some View {
        NavigationStack {
            Form {
                ledgerPickerSection()
                splitModeSection()
                summarySection()
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(L.personalSaveAndShareSheetTitle.localized)
            .toolbar { toolbarContent() }
        }
        .background(Color.appBackground)
        .tint(Color.appTextPrimary)
        .id(theme)
        .onAppear {
            let options = resolvedLedgers()
            if selectedLedgerId == nil || !options.contains(where: { $0.id == selectedLedgerId }) {
                selectedLedgerId = options.first?.id
            }
            loadMembersIfNeeded()
        }
        .onChange(of: selectedLedgerId) { _, _ in loadMembersIfNeeded() }
    }

    // MARK: - Subsections (split to reduce type-checking complexity)

    @ViewBuilder private func ledgerPickerSection() -> some View {
        Section(header: Text(L.personalSaveAndShareLedgerSection.localized)) {
            let options = resolvedLedgers()
            if options.isEmpty {
                Text(L.personalSaveAndShareNoLedgers.localized)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(options) { option in
                    Button { selectedLedgerId = option.id } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.name).foregroundStyle(Color.appTextPrimary)
                                Text(option.currency.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: selectedLedgerId == option.id ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedLedgerId == option.id ? Color.appSelection : Color.appSecondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("saveAndShare.ledgerRow.\(option.id.uuidString)")
                    .contentShape(Rectangle())
                }

                if currencyMismatch, let ledger = selectedLedgerFrom(options: options) {
                    Text(L.personalSaveAndShareCurrencyMismatch.localized(ledger.currency.rawValue, draft.currency.rawValue))
                        .font(.footnote)
                        .foregroundStyle(Color.appDanger)
                }
            }
        }
    }

    private func resolvedLedgers() -> [SharedLedgerOption] {
        if !ledgers.isEmpty { return ledgers }
        var options: [SharedLedgerOption] = []
        let summaries = appRootViewModel.ledgerSummaries
        if !summaries.isEmpty {
            options = summaries.map { SharedLedgerOption(id: $0.id, name: $0.name, currency: $0.currency) }
        } else if let manager = appState.dataManager, !manager.allLedgers.isEmpty {
            options = manager.allLedgers.map { SharedLedgerOption(id: $0.remoteId, name: $0.name, currency: $0.currency) }
        }
        return options.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func selectedLedgerFrom(options: [SharedLedgerOption]) -> SharedLedgerOption? {
        guard let selectedLedgerId else { return nil }
        return options.first { $0.id == selectedLedgerId }
    }

    @ViewBuilder private func splitModeSection() -> some View {
        Section(header: Text(L.personalSaveAndShareSplitMode.localized)) {
            ForEach(ExpenseSplitOption.allCases) { option in
                Button {
                    splitOption = option
                    ensureValidSelections()
                } label: {
                    HStack {
                        Image(systemName: splitOption == option ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(splitOption == option ? Color.appSelection : Color.appSecondaryText)
                        Text(option.title).foregroundStyle(Color.appTextPrimary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("saveAndShare.split.\(option.id)")
            }

            if splitOption == .otherAllAA || splitOption == .otherTreat {
                otherPayerControls()
            }

            if splitOption == .helpPay {
                helpPayControls()
            }
        }
        .listRowBackground(Color.appSurface)
    }

    @ViewBuilder private func otherPayerControls() -> some View {
        if selectableOtherPayers.isEmpty {
            Text(L.splitAddOtherMembers.localized)
                .font(.footnote)
                .foregroundStyle(Color.appWarning)
        } else {
            Picker(L.splitPayer.localized, selection: otherPayerBinding()) {
                ForEach(selectableOtherPayers, id: \.id) { m in
                    Text(m.name).tag(m.id as UUID?)
                }
            }
        }
    }

    @ViewBuilder private func helpPayControls() -> some View {
        Picker(L.splitPayer.localized, selection: helpPayPayerBinding()) {
            ForEach(members, id: \.id) { m in
                Text(m.name).tag(m.id as UUID?)
            }
        }
        .accessibilityIdentifier("saveAndShare.payerPicker")
        Picker(L.splitBeneficiary.localized, selection: beneficiaryBinding()) {
            ForEach(selectableBeneficiaries, id: \.id) { m in
                Text(m.name).tag(m.id as UUID?)
            }
        }
        .accessibilityIdentifier("saveAndShare.beneficiaryPicker")
    }

    @ViewBuilder private func summarySection() -> some View {
        Section(header: Text(L.personalSaveAndShareSummary.localized)) {
            HStack {
                Text(L.personalFieldAmount.localized)
                Spacer()
                Text("\(draft.currency.rawValue) \(NSDecimalNumber(decimal: draft.amount).stringValue)")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(L.personalFieldCategory.localized)
                Spacer()
                Text(draft.category.localizedName)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(L.personalFieldDate.localized)
                Spacer()
                Text(draft.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            if !draft.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(alignment: .top) {
                    Text(L.personalFieldNote.localized)
                    Spacer()
                    Text(draft.note)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .listRowBackground(Color.appSurface)
    }

    @ToolbarContentBuilder private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(L.cancel.localized, action: onCancel)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(L.personalSaveAndShare.localized) {
                if let config = try? buildConfiguration() {
                    onConfirm(config)
                }
            }
            .disabled(!canConfirm)
            .accessibilityIdentifier("saveAndShare.confirmButton")
        }
    }

    private var currentUserId: UUID { appRootViewModel.currentUser.id }

    private var selectableOtherPayers: [MemberSummaryViewData] {
        members.filter { $0.id != currentUserId }
    }

    private var selectableBeneficiaries: [MemberSummaryViewData] {
        guard let payer = selectedHelpPayPayerId else { return members }
        return members.filter { $0.id != payer }
    }

    private func loadMembersIfNeeded() {
        guard let id = selectedLedgerId else { return }
        members = appRootViewModel.ledgerMembers(ledgerId: id)
        ensureValidSelections()
    }

    // initializeLedgersIfNeeded removed; resolved via resolvedLedgers() and onAppear

    private func ensureValidSelections() {
        if splitOption == .otherAllAA || splitOption == .otherTreat {
            if selectedOtherPayerId == nil || !selectableOtherPayers.contains(where: { $0.id == selectedOtherPayerId }) {
                selectedOtherPayerId = selectableOtherPayers.first?.id
            }
        }
        if splitOption == .helpPay {
            if selectedHelpPayPayerId == nil { selectedHelpPayPayerId = members.first?.id }
            if selectedBeneficiaryId == nil || selectedBeneficiaryId == selectedHelpPayPayerId {
                selectedBeneficiaryId = selectableBeneficiaries.first?.id
            }
        }
    }

    private func otherPayerBinding() -> Binding<UUID?> {
        Binding<UUID?>(get: {
            selectedOtherPayerId ?? selectableOtherPayers.first?.id
        }, set: { newVal in
            selectedOtherPayerId = newVal
        })
    }

    private func helpPayPayerBinding() -> Binding<UUID?> {
        Binding<UUID?>(get: {
            selectedHelpPayPayerId ?? members.first?.id
        }, set: { newVal in
            selectedHelpPayPayerId = newVal
            if selectedBeneficiaryId == newVal {
                selectedBeneficiaryId = selectableBeneficiaries.first?.id
            }
        })
    }

    private func beneficiaryBinding() -> Binding<UUID?> {
        Binding<UUID?>(get: {
            selectedBeneficiaryId ?? selectableBeneficiaries.first?.id
        }, set: { newVal in
            selectedBeneficiaryId = newVal
        })
    }

    private var canConfirm: Bool {
        guard selectedLedgerId != nil, !resolvedLedgers().isEmpty else { return false }
        return isSplitValid()
    }

    private func isSplitValid() -> Bool {
        switch splitOption {
        case .meAllAA, .meTreat:
            return true
        case .otherAllAA, .otherTreat:
            // 只要选择了付款人即可
            return (selectedOtherPayerId != nil) || !selectableOtherPayers.isEmpty
        case .helpPay:
            guard let payer = selectedHelpPayPayerId ?? members.first?.id else { return false }
            let beneficiary = selectedBeneficiaryId ?? selectableBeneficiaries.first?.id
            return beneficiary != nil && payer != beneficiary
        }
    }

    private func buildConfiguration() throws -> QuickSplitConfiguration {
        let payerId: UUID
        let includePayer: Bool
        let strategy: SplitStrategy
        var participants: [ExpenseParticipantShare] = []

        switch splitOption {
        case .meAllAA:
            payerId = currentUserId
            includePayer = true
            strategy = .payerAA
            participants = members.map { ExpenseParticipantShare(userId: $0.id, shareType: .aa) }
        case .otherAllAA:
            payerId = selectedOtherPayerId ?? selectableOtherPayers.first?.id ?? currentUserId
            includePayer = true
            strategy = .payerAA
            participants = members.map { ExpenseParticipantShare(userId: $0.id, shareType: .aa) }
        case .meTreat:
            payerId = currentUserId
            includePayer = false
            strategy = .payerTreat
            participants = [ExpenseParticipantShare(userId: currentUserId, shareType: .treat)]
        case .otherTreat:
            payerId = selectedOtherPayerId ?? selectableOtherPayers.first?.id ?? currentUserId
            includePayer = false
            strategy = .actorTreat
            participants = [ExpenseParticipantShare(userId: payerId, shareType: .treat)]
        case .helpPay:
            let payer = selectedHelpPayPayerId ?? members.first?.id ?? currentUserId
            let beneficiary = selectedBeneficiaryId ?? selectableBeneficiaries.first?.id ?? currentUserId
            payerId = payer
            includePayer = false
            strategy = .helpPay
            participants = [ExpenseParticipantShare(userId: beneficiary, shareType: .aa)]
        }

        return QuickSplitConfiguration(payerId: payerId, splitStrategy: strategy, includePayer: includePayer, participants: participants)
    }
}

struct PersonalRecordFormView: View {
    @ObservedObject var viewModel: PersonalRecordFormViewModel
    var onDone: () -> Void

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appRootViewModel: AppRootViewModel
    @State private var isSharingWithSharedLedger = false
    @State private var sharedLedgerOptions: [SharedLedgerOption] = []
    @State private var selectedSharedLedgerId: UUID?
    @State private var pendingSharedDraft: SharedExpenseDraft?
    @State private var showCategoryMappingAlert = false
    private let lastSaveAndShareLedgerKey = "personal.lastSaveAndShareLedgerId"

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
            // 基本信息
            Section(header: Text(L.expenseBasicInfo.localized)) {
                HStack {
                    TextField(L.personalFieldAmount.localized, text: $viewModel.amountText)
                        .keyboardType(.decimalPad)
                        .onChange(of: viewModel.amountText) { oldValue, newValue in
                            let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 2, locale: .current, oldValue: oldValue)
                            if validated != newValue { viewModel.amountText = validated }
                        }
                    Menu {
                        ForEach(viewModel.currencyOptions, id: \.self) { code in
                            Button(action: { viewModel.selectAmountCurrency(code) }) {
                                Text(code.displayLabel)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.amountCurrency.displayLabel)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.15)))
                    }
                    .accessibilityLabel(Text(L.personalFieldCurrency.localized))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appListRowSeparatorLeading()

                if viewModel.showFXField {
                    TextField(L.personalFieldFXRate.localized,
                              text: $viewModel.fxRateText,
                              prompt: Text(viewModel.fxRatePlaceholder).foregroundStyle(.secondary))
                        .keyboardType(.decimalPad)
                        .onChange(of: viewModel.fxRateText) { oldValue, newValue in
                            let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 6, locale: .current, oldValue: oldValue)
                            if validated != newValue { viewModel.fxRateText = validated }
                        }
                    HStack(spacing: 8) {
                        Text(viewModel.fxInfoText)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L.personalTransferInvert.localized) {
                            viewModel.invertFXRate()
                        }
                        .font(.caption)
                    }
                    TextField(L.personalFieldFee.localized(viewModel.accountCurrencyCode),
                              text: $viewModel.feeText,
                              prompt: Text(viewModel.feePlaceholder).foregroundStyle(.secondary))
                        .keyboardType(.decimalPad)
                        .onChange(of: viewModel.feeText) { oldValue, newValue in
                            let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 2, locale: .current, oldValue: oldValue)
                            if validated != newValue { viewModel.feeText = validated }
                        }
                }
                // 备注/来源
                TextField(viewModel.kind == .expense ? L.expensePurpose.localized : "income.source".localized, text: $viewModel.note, axis: .vertical)
                // 分类
                Picker(L.personalFieldCategory.localized, selection: $viewModel.categoryKey) {
                    ForEach(viewModel.categoryOptions, id: \.key) { option in
                        Text(option.localizedName).tag(option.key)
                    }
                }
                // 时间
                DatePicker(L.personalFieldDate.localized, selection: $viewModel.occurredAt, displayedComponents: [.date, .hourAndMinute])
            }
            if !viewModel.templates.isEmpty {
                Section(header: Text(L.personalTemplatesQuickFill.localized),
                        footer: Text(L.personalTemplatesQuickFillHint.localized)
                    .foregroundStyle(Color.appSecondaryText)) {
                    ForEach(viewModel.templates) { template in
                        Button {
                            viewModel.applyTemplate(template)
                        } label: {
                            PersonalTemplateLabel(template: template)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L.personalTemplatesEmpty.localized)
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        Button {
                            NotificationCenter.default.post(name: .openPersonalTemplates, object: nil)
                            onDone()
                        } label: {
                            Text(L.personalTemplatesCreate.localized)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .tint(Color.appTextPrimary)
        .dismissKeyboardOnTap()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: onDone) {
                    Text(L.cancel.localized)
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if canShowSaveAndShareButton {
                    Button(action: { beginSaveAndShareFlow() }) {
                        Text(L.personalSaveAndShare.localized)
                            .font(.headline)
                            .foregroundStyle(Color.appTextPrimary)
                    }
                    .disabled(viewModel.isSaving || isSharingWithSharedLedger)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving || isSharingWithSharedLedger {
                    ProgressView()
                } else {
                    Button(action: {
                        Task {
                            let success = await viewModel.submit()
                            if success { onDone() }
                        }
                    }) {
                        Text(L.save.localized)
                            .font(.headline)
                            .foregroundStyle(Color.appTextPrimary)
                    }
                }
            }
        }
        .alert(viewModel.errorMessage ?? "", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })) {
            Button(L.ok.localized, action: {})
        }
        .alert(L.personalCategoryMappingTitle.localized, isPresented: $showCategoryMappingAlert) {
            Button(L.ok.localized, role: .cancel) { }
        } message: {
            Text(L.personalCategoryMappingRequired.localized)
        }
        .sheet(item: $pendingSharedDraft) { draft in
            SaveToSharedSheet(draft: draft,
                              ledgers: sharedLedgerOptions,
                              selectedLedgerId: $selectedSharedLedgerId,
                              onConfirm: { config in confirmSaveAndShare(with: draft, configuration: config) },
                              onCancel: { cancelSaveToSharedFlow() })
        }
    }

    private var canShowSaveAndShareButton: Bool {
        guard appState.showSharedLedgerTab,
              appState.showPersonalLedgerTab,
              viewModel.kind == .expense else { return false }
        if !appRootViewModel.ledgerSummaries.isEmpty { return true }
        if let manager = appState.dataManager, !manager.allLedgers.isEmpty { return true }
        return false
    }

    private func beginSaveAndShareFlow() {
        guard !isSharingWithSharedLedger, !viewModel.isSaving else { return }
        guard appState.dataManager != nil else {
            viewModel.errorMessage = L.personalSaveAndShareUnavailable.localized
            return
        }

        let trimmedAmount = viewModel.amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = NumberParsing.parseDecimal(trimmedAmount), amount > 0 else {
            viewModel.errorMessage = L.personalSaveAndShareInvalidAmount.localized
            return
        }

        if viewModel.isCustomCategoryMissingSharedMapping() {
            showCategoryMappingAlert = true
            return
        }
        guard let category = viewModel.sharedCategoryForSharedLedger() else {
            viewModel.errorMessage = L.personalSaveAndShareUnavailable.localized
            return
        }
        let draft = SharedExpenseDraft(amount: amount,
                                       currency: viewModel.amountCurrency,
                                       occurredAt: viewModel.occurredAt,
                                       category: category,
                                       note: viewModel.note)

        // Prefer shared ledgers from root view model; fallback to data manager if needed
        var options: [SharedLedgerOption] = []
        let summaries = appRootViewModel.ledgerSummaries
        if !summaries.isEmpty {
            options = summaries
                .map { SharedLedgerOption(id: $0.id, name: $0.name, currency: $0.currency) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } else if let manager = appState.dataManager, !manager.allLedgers.isEmpty {
            options = manager.allLedgers
                .map { SharedLedgerOption(id: $0.remoteId, name: $0.name, currency: $0.currency) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        guard !options.isEmpty else {
            viewModel.errorMessage = L.personalSaveAndShareNoLedgers.localized
            return
        }

        sharedLedgerOptions = options
        selectedSharedLedgerId = preferredSharedLedgerId(from: options)
        pendingSharedDraft = draft
    }

    private func cancelSaveToSharedFlow() {
        pendingSharedDraft = nil
    }

    private func confirmSaveAndShare(with draft: SharedExpenseDraft, configuration: QuickSplitConfiguration) {
        guard let ledgerId = selectedSharedLedgerId else { return }
        pendingSharedDraft = nil
        isSharingWithSharedLedger = true
        Task { @MainActor in
            defer { isSharingWithSharedLedger = false }
            do {
                try shareToSharedLedger(ledgerId: ledgerId, draft: draft, config: configuration)
                let success = await viewModel.submit()
                if success {
                    rememberLastSaveAndShareLedger(ledgerId)
                    onDone()
                }
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private func preferredSharedLedgerId(from options: [SharedLedgerOption]) -> UUID? {
        let defaults = UserDefaults.standard
        if let stored = defaults.string(forKey: lastSaveAndShareLedgerKey),
           let id = UUID(uuidString: stored),
           options.contains(where: { $0.id == id }) {
            return id
        }
        return options.first?.id
    }

    private func rememberLastSaveAndShareLedger(_ ledgerId: UUID) {
        UserDefaults.standard.set(ledgerId.uuidString, forKey: lastSaveAndShareLedgerKey)
    }

    @MainActor
    private func shareToSharedLedger(ledgerId: UUID, draft: SharedExpenseDraft, config: QuickSplitConfiguration) throws {
        guard let manager = appState.dataManager else {
            throw SaveToSharedError.dataUnavailable
        }
        guard let ledger = manager.allLedgers.first(where: { $0.remoteId == ledgerId }) else {
            throw SaveToSharedError.ledgerMissing
        }
        guard ledger.currency == draft.currency else {
            throw SaveToSharedError.currencyMismatch(shared: ledger.currency, personal: draft.currency)
        }
        guard manager.currentUser != nil else {
            throw SaveToSharedError.currentUserMissing
        }

        let trimmedNote = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmedNote.isEmpty ? L.defaultUntitledExpense.localized : trimmedNote

        manager.addExpense(ledgerId: ledgerId,
                           payerId: config.payerId,
                           title: title,
                           amount: draft.amount,
                           currency: draft.currency,
                           date: draft.occurredAt,
                           category: draft.category,
                           note: draft.note,
                           splitStrategy: config.splitStrategy,
                           includePayer: config.includePayer,
                           participants: config.participants)

        // Ensure shared ledger UI refreshes immediately
        appRootViewModel.loadFromPersistence()
    }
}

private enum SaveToSharedError: LocalizedError {
    case dataUnavailable
    case ledgerMissing
    case currencyMismatch(shared: CurrencyCode, personal: CurrencyCode)
    case currentUserMissing

    var errorDescription: String? {
        switch self {
        case .dataUnavailable:
            return L.personalSaveAndShareUnavailable.localized
        case .ledgerMissing:
            return L.personalSaveAndShareLedgerMissing.localized
        case let .currencyMismatch(shared, personal):
            return L.personalSaveAndShareCurrencyMismatch.localized(shared.rawValue, personal.rawValue)
        case .currentUserMissing:
            return L.personalSaveAndShareMissingCurrentUser.localized
        }
    }
}

// MARK: - Bridge to Shared Ledger Full Split UI

private struct QuickSplitConfiguration {
    let payerId: UUID
    let splitStrategy: SplitStrategy
    let includePayer: Bool
    let participants: [ExpenseParticipantShare]
}

private enum SharedExpensePrefillSheet {
    static func present(rootViewModel: AppRootViewModel, ledgerId: UUID, prefill: SharedExpenseDraft) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else { return }
        let host = UIHostingController(rootView: SharedExpensePrefillHost(rootViewModel: rootViewModel,
                                                                          ledgerId: ledgerId,
                                                                          prefill: prefill))
        rootVC.present(host, animated: true)
    }
}

private struct SharedExpensePrefillHost: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var viewModel: ExpenseFormScreenModel
    private let prefill: SharedExpenseDraft

    init(rootViewModel: AppRootViewModel, ledgerId: UUID, prefill: SharedExpenseDraft) {
        _viewModel = ObservedObject(wrappedValue: rootViewModel.makeExpenseFormViewModel(ledgerId: ledgerId))
        self.prefill = prefill
    }

    var body: some View {
        NavigationStack {
            ExpenseFormView(viewModel: viewModel)
                .navigationTitle(L.expenseTitle.localized)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L.close.localized, action: dismiss.callAsFunction) }
                }
        }
        .onAppear {
            // Prefill shared expense fields from personal draft
            viewModel.draft.title = prefill.note.isEmpty ? L.defaultUntitledExpense.localized : prefill.note
            viewModel.draft.amount = prefill.amount
            viewModel.draft.date = prefill.occurredAt
            viewModel.draft.note = prefill.note
            viewModel.draft.category = prefill.category
            viewModel.regeneratePreview()
        }
    }
}
