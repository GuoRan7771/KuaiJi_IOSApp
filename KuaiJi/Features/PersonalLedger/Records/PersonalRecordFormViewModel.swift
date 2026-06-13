//
//  PersonalRecordFormViewModel.swift
//  KuaiJi
//

import Combine
import Foundation
import SwiftData
import SwiftUI

@MainActor
final class PersonalRecordFormViewModel: ObservableObject {
    @Published var kind: PersonalTransactionKind = .expense {
        didSet {
            reloadCategories()
            updateFXState()
        }
    }
    @Published var accountId: UUID?
    @Published var categoryKey: String = PersonalCategoryOption.commonExpenseKeys.first ?? ""
    @Published var amountText: String = ""
    @Published var amountCurrency: CurrencyCode
    @Published var occurredAt: Date = Date()
    @Published var note: String = ""
    @Published var fxRateText: String = ""
    @Published var feeText: String = ""
    @Published var showFXField = false
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published private(set) var templates: [PersonalRecordTemplateViewData] = []
    @Published private(set) var categoryOptions: [PersonalCategoryOption] = []

    var accounts: [PersonalAccount] { store.activeAccounts }
    var currencyOptions: [CurrencyCode] { CurrencyCode.allCases }
    var accountCurrencyCode: String {
        currentAccount()?.currency.rawValue ?? amountCurrency.rawValue
    }
    var fxRatePlaceholder: String {
        let value: Decimal
        if let account = currentAccount() {
            value = defaultFXRate(for: account)
        } else {
            value = store.safeDefaultFXRate() ?? 1
        }
        let string = NSDecimalNumber(decimal: value).stringValue
        return L.personalFXPlaceholder.localized(string)
    }
    var feePlaceholder: String {
        let value = store.safeDefaultConversionFee() ?? 0
        let string = NSDecimalNumber(decimal: value).stringValue
        return L.personalFeePlaceholder.localized(string)
    }

    // 汇率方向信息，例如："1 CNY = 0.14 USD"，当无法解析汇率时显示问号
    var fxInfoText: String {
        guard showFXField, let account = currentAccount() else { return "" }
        let from = amountCurrency
        let to = account.currency
        let trimmed = fxRateText.trimmingCharacters(in: .whitespacesAndNewlines)
        let rateText: String
        if let parsed = NumberParsing.parseDecimal(trimmed), parsed > 0 {
            rateText = NSDecimalNumber(decimal: parsed).stringValue
        } else {
            rateText = "?"
        }
        return L.personalTransferFXInfo.localized(from.rawValue, rateText, to.rawValue)
    }

    private let store: PersonalLedgerStore
    private let editingRecord: PersonalRecordRowViewData?
    private var userSetCustomCurrency = false
    private var cancellables: Set<AnyCancellable> = []

    init(store: PersonalLedgerStore, editingRecord: PersonalRecordRowViewData? = nil) {
        self.store = store
        self.editingRecord = editingRecord
        if let record = editingRecord, let recordKind = record.transactionKind {
            self.kind = recordKind
            self.accountId = record.accountId
            self.categoryKey = record.categoryKey
            self.amountText = Self.decimalString(from: record.amountMinorUnits)
            self.occurredAt = record.occurredAt
            self.note = record.note
            self.amountCurrency = record.currency
        } else {
            let defaultAccountId = store.safeLastUsedAccountId() ?? store.activeAccounts.first?.remoteId
            self.accountId = defaultAccountId
            if let account = store.activeAccounts.first(where: { $0.remoteId == defaultAccountId }) {
                self.amountCurrency = account.currency
            } else {
                self.amountCurrency = store.safePrimaryDisplayCurrency()
            }
            self.amountText = ""
            self.note = ""
            self.occurredAt = Date()
        }
        userSetCustomCurrency = currentAccount()?.currency != amountCurrency
        reloadCategories()
        updateFXState()
        loadTemplates()
        subscribeToStore()
    }

    func selectAccount(_ id: UUID?) {
        accountId = id
        if !userSetCustomCurrency, let account = currentAccount() {
            amountCurrency = account.currency
        }
        updateFXState()
    }

    func toggleKind(_ newKind: PersonalTransactionKind) {
        kind = newKind
        updateFXState()
    }

    func selectAmountCurrency(_ currency: CurrencyCode) {
        amountCurrency = currency
        userSetCustomCurrency = currentAccount()?.currency != currency
        updateFXState()
    }

    private func currentAccount() -> PersonalAccount? {
        guard let accountId else { return nil }
        return store.account(with: accountId)
    }

    private func defaultFXRate(for account: PersonalAccount) -> Decimal {
        if account.currency == store.safePrimaryDisplayCurrency() {
            return 1
        }
        if let stored = store.safeFXRate(for: account.currency), stored > 0 {
            return stored
        }
        if let fallback = store.safeDefaultFXRate(), fallback > 0 {
            return fallback
        }
        return 1
    }

    private func updateFXState() {
        let previous = showFXField
        guard let account = currentAccount() else {
            showFXField = false
            fxRateText = ""
            feeText = ""
            return
        }
        if amountCurrency != account.currency {
            showFXField = true
            if !previous {
                fxRateText = ""
                feeText = ""
            }
        } else {
            showFXField = false
            fxRateText = ""
            feeText = ""
            userSetCustomCurrency = false
        }
    }

    // 一键反转汇率：fxRateText = 1 / 当前值
    func invertFXRate() {
        let trimmed = fxRateText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = NumberParsing.parseDecimal(trimmed), parsed > 0 else { return }
        let inverted = 1 / parsed
        fxRateText = NSDecimalNumber(decimal: inverted).stringValue
    }

    func applyTemplate(_ template: PersonalRecordTemplateViewData) {
        kind = .expense
        if let id = template.accountId, store.account(with: id) != nil {
            accountId = id
        } else {
            accountId = nil
        }
        if template.amountMinorUnits > 0 {
            amountCurrency = template.currency
            userSetCustomCurrency = currentAccount()?.currency != template.currency
            amountText = Self.decimalString(from: template.amountMinorUnits)
        }
        if !template.categoryKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            categoryKey = template.categoryKey
        }
        if let note = template.note {
            self.note = note
        }
        updateFXState()
    }

    func submit() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            guard let account = currentAccount() else { throw PersonalLedgerError.accountRequired }
            guard let amount = NumberParsing.parseDecimal(amountText), amount > 0 else {
                throw PersonalLedgerError.amountMustBePositive
            }
            var convertedAmount = amount
            var fxRate: Decimal? = nil
            if showFXField {
                let trimmedRate = fxRateText.trimmingCharacters(in: .whitespacesAndNewlines)
                let effectiveRate: Decimal
                if trimmedRate.isEmpty {
                    effectiveRate = defaultFXRate(for: account)
                } else {
                    guard let rate = NumberParsing.parseDecimal(trimmedRate), rate > 0 else {
                        throw PersonalLedgerError.invalidExchangeRate
                    }
                    effectiveRate = rate
                }
                convertedAmount = amount * effectiveRate
                fxRate = effectiveRate
            }
            let feeValue: Decimal
            if showFXField {
                let trimmedFee = feeText.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedFee.isEmpty {
                    feeValue = store.preferences.defaultConversionFee ?? 0
                } else {
                    guard let parsed = NumberParsing.parseDecimal(trimmedFee), parsed >= 0 else {
                        throw PersonalLedgerError.amountMustBePositive
                    }
                    feeValue = parsed
                }
            } else {
                feeValue = 0
            }

            let input = PersonalTransactionInput(id: editingRecord?.id,
                                                 kind: kind,
                                                 accountId: account.remoteId,
                                                 categoryKey: categoryKey,
                                                 amount: convertedAmount,
                                                 occurredAt: occurredAt,
                                                 note: note,
                                                 displayCurrency: showFXField ? amountCurrency : nil,
                                                 fxRate: fxRate)
            _ = try store.saveTransaction(input)
            if showFXField, feeValue > 0, editingRecord == nil {
            let previousCategory = store.safeLastUsedCategoryKey()
                let feeNote: String
                if note.isEmpty {
                    feeNote = L.personalConversionFeeNote.localized
                } else {
                    feeNote = note + " · " + L.personalConversionFeeNote.localized
                }
                let feeInput = PersonalTransactionInput(kind: .fee,
                                                        accountId: account.remoteId,
                                                        categoryKey: store.safeDefaultFeeCategoryKey() ?? "fees",
                                                        amount: feeValue,
                                                        occurredAt: occurredAt,
                                                        note: feeNote,
                                                        displayCurrency: nil,
                                                        fxRate: nil)
                _ = try store.saveTransaction(feeInput)
                try store.updatePreferences { prefs in
                    prefs.lastUsedCategoryKey = previousCategory
                }
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func reloadCategories() {
        let includeHiddenKey = store.systemCategoryHidden(categoryKey) ? categoryKey : nil
        categoryOptions = store.categoryOptions(for: kind, includeHiddenKey: includeHiddenKey)
        ensureValidCategory()
    }

    private func ensureValidCategory() {
        if store.systemCategoryHidden(categoryKey), editingRecord == nil {
            let visible = store.categoryOptions(for: kind, includeHiddenKey: nil)
            if let first = visible.first {
                categoryKey = first.key
                return
            }
        }
        if categoryOptions.contains(where: { $0.key == categoryKey }) {
            return
        }
        if kind == .fee {
            categoryKey = "fees"
            return
        }
        if let last = store.safeLastUsedCategoryKey(),
           categoryOptions.contains(where: { $0.key == last }) {
            categoryKey = last
            return
        }
        if let first = categoryOptions.first {
            categoryKey = first.key
            return
        }
        if let fallback = PersonalCategoryOption.defaultCategories(for: kind).first {
            categoryKey = fallback.key
            return
        }
    }

    private static func decimalString(from minorUnits: Int) -> String {
        let decimal = SettlementMath.decimal(fromMinorUnits: minorUnits, scale: 2)
        return NSDecimalNumber(decimal: decimal).stringValue
    }

    private func loadTemplates() {
        templates = store.recordTemplates.map { template in
            let accountName: String?
            if let id = template.accountId, let account = store.account(with: id) {
                accountName = account.name
            } else {
                accountName = nil
            }
            let category = store.categoryOption(for: template.categoryKey)
            return PersonalRecordTemplateViewData(id: template.remoteId,
                                                  name: template.name,
                                                  accountId: template.accountId,
                                                  accountName: accountName,
                                                  amountMinorUnits: template.amountMinorUnits,
                                                  currency: template.currency,
                                                  categoryKey: template.categoryKey,
                                                  categoryName: category?.localizedName ?? (template.categoryKey.isEmpty ? L.personalTemplatesNoCategory.localized : template.categoryKey),
                                                  systemImage: category?.systemImage ?? store.categoryIcon(for: template.categoryKey),
                                                  note: template.note)
        }
    }

    private func subscribeToStore() {
        store.$recordTemplates
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.loadTemplates() }
            .store(in: &cancellables)
        store.$activeAccounts
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.loadTemplates() }
            .store(in: &cancellables)
        store.$archivedAccounts
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.loadTemplates() }
            .store(in: &cancellables)
        store.$customCategories
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadCategories()
                self?.loadTemplates()
            }
            .store(in: &cancellables)
        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reloadCategories() }
            .store(in: &cancellables)
    }

    func sharedCategoryForSharedLedger() -> ExpenseCategory? {
        guard let option = store.categoryOption(for: categoryKey) else {
            return ExpenseCategory(rawValue: categoryKey)
        }
        if option.isCustom {
            return option.mappedSystemCategory
        }
        return ExpenseCategory(rawValue: option.key)
    }

    func isCustomCategoryMissingSharedMapping() -> Bool {
        guard let option = store.categoryOption(for: categoryKey) else { return false }
        return option.isCustom && option.mappedSystemCategory == nil
    }
}
