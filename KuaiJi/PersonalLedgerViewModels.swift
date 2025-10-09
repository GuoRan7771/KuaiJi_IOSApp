//
//  PersonalLedgerViewModels.swift
//  KuaiJi
//
//  View models powering the personal ledger UI flow.
//

import Combine
import Foundation
import SwiftData
import SwiftUI

struct PersonalOverviewState {
    var expenseMinorUnits: Int = 0
    var incomeMinorUnits: Int = 0
    var displayCurrency: CurrencyCode = .cny
    var includeFees: Bool = true
}

struct PersonalRecordRowViewData: Identifiable, Hashable {
    var id: UUID
    var categoryKey: String
    var categoryName: String
    var systemImage: String
    var note: String
    var amountMinorUnits: Int
    var currency: CurrencyCode
    var kind: PersonalTransactionKind
    var occurredAt: Date
    var accountName: String
    var accountId: UUID

    var amountIsPositive: Bool { kind == .income }
}

struct PersonalAccountRowViewData: Identifiable, Hashable {
    var id: UUID
    var name: String
    var type: PersonalAccountType
    var currency: CurrencyCode
    var balanceMinorUnits: Int
    var includeInNetWorth: Bool
    var note: String?
    var status: PersonalAccountStatus
    var convertedBalanceMinorUnits: Int
}

struct PersonalNetWorthSummaryViewData {
    var totalMinorUnits: Int
    var displayCurrency: CurrencyCode
}

struct PersonalRecordFilterState: Equatable {
    var dateRange: ClosedRange<Date>?
    var kinds: Set<PersonalTransactionKind>
    var accountIds: Set<UUID>
    var categoryKeys: Set<String>
    var minAmountText: String
    var maxAmountText: String
    var keyword: String

    static let `default` = PersonalRecordFilterState(dateRange: nil,
                                                     kinds: [.income, .expense],
                                                     accountIds: [],
                                                     categoryKeys: [],
                                                     minAmountText: "",
                                                     maxAmountText: "",
                                                     keyword: "")

    func toFilter() -> PersonalRecordFilter {
        var minimum: Int?
        if let value = Decimal(string: minAmountText), value > 0 {
            minimum = SettlementMath.minorUnits(from: value, scale: 2)
        }
        var maximum: Int?
        if let value = Decimal(string: maxAmountText), value > 0 {
            maximum = SettlementMath.minorUnits(from: value, scale: 2)
        }
        return PersonalRecordFilter(dateRange: dateRange,
                                    kinds: kinds.isEmpty ? nil : kinds,
                                    accountIds: accountIds.isEmpty ? nil : accountIds,
                                    categoryKeys: categoryKeys.isEmpty ? nil : categoryKeys,
                                    minimumAmountMinor: minimum,
                                    maximumAmountMinor: maximum,
                                    keyword: keyword.isEmpty ? nil : keyword)
    }
}

struct PersonalStatsSeriesPoint: Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var incomeMinorUnits: Int
    var expenseMinorUnits: Int
}

struct PersonalStatsCategoryShare: Identifiable, Hashable {
    var id: UUID = UUID()
    var categoryKey: String
    var amountMinorUnits: Int
}

@MainActor
final class PersonalLedgerRootViewModel: ObservableObject {
    let store: PersonalLedgerStore

    init(modelContext: ModelContext, defaultCurrency: CurrencyCode) {
        do {
            self.store = try PersonalLedgerStore(context: modelContext, defaultCurrency: defaultCurrency)
        } catch {
            fatalError("Failed to create PersonalLedgerStore: \(error)")
        }
    }

    func makeHomeViewModel() -> PersonalLedgerHomeViewModel {
        PersonalLedgerHomeViewModel(store: store)
    }

    func makeRecordFormViewModel(existing transaction: PersonalRecordRowViewData? = nil) -> PersonalRecordFormViewModel {
        PersonalRecordFormViewModel(store: store, editingRecord: transaction)
    }

    func makeAccountsViewModel() -> PersonalAccountsViewModel {
        PersonalAccountsViewModel(store: store)
    }

    func makeAccountFormViewModel(accountId: UUID? = nil) -> PersonalAccountFormViewModel {
        PersonalAccountFormViewModel(store: store, accountId: accountId)
    }

    func makeTransferFormViewModel(transferId: UUID? = nil) -> PersonalTransferFormViewModel {
        PersonalTransferFormViewModel(store: store, transferId: transferId)
    }

    func makeAllRecordsViewModel(anchorDate: Date = Date()) -> PersonalAllRecordsViewModel {
        PersonalAllRecordsViewModel(store: store, anchorDate: anchorDate)
    }

    func makeStatsViewModel() -> PersonalStatsViewModel {
        PersonalStatsViewModel(store: store)
    }

    func makeSettingsViewModel() -> PersonalLedgerSettingsViewModel {
        PersonalLedgerSettingsViewModel(store: store)
    }
}

@MainActor
final class PersonalLedgerHomeViewModel: ObservableObject {
    @Published var selectedMonth: Date
    @Published private(set) var overview = PersonalOverviewState()
    @Published private(set) var todayRecords: [PersonalRecordRowViewData] = []
    @Published private(set) var isLoading = false
    @Published var lastErrorMessage: String?

    private let store: PersonalLedgerStore
    private var cancellables: Set<AnyCancellable> = []

    init(store: PersonalLedgerStore) {
        self.store = store
        self.selectedMonth = Date()
        subscribeToStore()
        Task { await refresh() }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let totals = try store.monthlyTotals(for: selectedMonth, includeFees: store.preferences.countFeeInStats)
            overview = PersonalOverviewState(expenseMinorUnits: totals.expense,
                                             incomeMinorUnits: totals.income,
                                             displayCurrency: store.preferences.primaryDisplayCurrency,
                                             includeFees: store.preferences.countFeeInStats)
            let records = try store.todayTransactions(limit: 3)
            todayRecords = records.compactMap(mapRecord(_:))
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func changeMonth(by offset: Int) {
        if let newMonth = Calendar.current.date(byAdding: .month, value: offset, to: selectedMonth) {
            selectedMonth = newMonth
            Task { await refresh() }
        }
    }

    private func subscribeToStore() {
        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.refresh() }
            }
            .store(in: &cancellables)
    }

    private func mapRecord(_ transaction: PersonalTransaction) -> PersonalRecordRowViewData? {
        guard let account = store.account(with: transaction.accountId) else {
            return nil
        }
        let category = (expenseCategories + incomeCategories + feeCategories).first(where: { $0.key == transaction.categoryKey })
        return PersonalRecordRowViewData(id: transaction.remoteId,
                                         categoryKey: transaction.categoryKey,
                                         categoryName: category?.localizedName ?? transaction.categoryKey.capitalized,
                                         systemImage: category?.systemImage ?? iconForCategory(key: transaction.categoryKey),
                                         note: transaction.note,
                                         amountMinorUnits: transaction.amountMinorUnits,
                                         currency: account.currency,
                                         kind: transaction.kind,
                                         occurredAt: transaction.occurredAt,
                                         accountName: account.name,
                                         accountId: account.remoteId)
    }
}

@MainActor
final class PersonalRecordFormViewModel: ObservableObject {
    @Published var kind: PersonalTransactionKind = .expense {
        didSet {
            updateDefaultCategory()
            updateFXFieldVisibility()
        }
    }
    @Published var accountId: UUID?
    @Published var categoryKey: String = PersonalCategoryOption.commonExpenseKeys.first ?? ""
    @Published var amountText: String = ""
    @Published var occurredAt: Date = Date()
    @Published var note: String = ""
    @Published var attachmentURL: URL?
    @Published var fxRateText: String = ""
    @Published var showFXField = false
    @Published var isSaving = false
    @Published var errorMessage: String?

    var accounts: [PersonalAccount] { store.activeAccounts }

    private let store: PersonalLedgerStore
    private let editingRecord: PersonalRecordRowViewData?

    init(store: PersonalLedgerStore, editingRecord: PersonalRecordRowViewData? = nil) {
        self.store = store
        self.editingRecord = editingRecord
        if let record = editingRecord {
            self.kind = record.kind
            self.accountId = record.accountId
            self.categoryKey = record.categoryKey
            self.amountText = Self.decimalString(from: record.amountMinorUnits)
            self.occurredAt = record.occurredAt
            self.note = record.note
        } else {
            accountId = store.preferences.lastUsedAccountId ?? store.activeAccounts.first?.remoteId
            updateDefaultCategory()
        }
        updateFXFieldVisibility()
    }

    var categoryOptions: [PersonalCategoryOption] {
        PersonalCategoryOption.defaultCategories(for: kind)
    }

    func selectAccount(_ id: UUID?) {
        accountId = id
        updateFXFieldVisibility()
    }

    func toggleKind(_ newKind: PersonalTransactionKind) {
        kind = newKind
        updateFXFieldVisibility()
    }

    func updateFXFieldVisibility() {
        guard let accountId, let account = store.activeAccounts.first(where: { $0.remoteId == accountId }) else {
            showFXField = false
            return
        }
        let displayCurrency = store.preferences.primaryDisplayCurrency
        showFXField = account.currency != displayCurrency
        if showFXField {
            if fxRateText.isEmpty {
                if let saved = store.preferences.fxRates[account.currency] {
                    fxRateText = saved.description
                } else if let defaultRate = store.preferences.defaultFXRate {
                    fxRateText = defaultRate.description
                }
            }
        } else {
            fxRateText = ""
        }
    }

    func saveAttachment(data: Data, fileExtension: String) throws {
        let directory = try attachmentDirectory()
        let filename = UUID().uuidString + "." + fileExtension
        let fileURL = directory.appendingPathComponent(filename)
        try data.write(to: fileURL, options: .atomic)
        attachmentURL = fileURL
    }

    func removeAttachment() {
        if let url = attachmentURL {
            try? FileManager.default.removeItem(at: url)
        }
        attachmentURL = nil
    }

    func submit() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            guard let accountId else { throw PersonalLedgerError.accountRequired }
            guard let amount = Decimal(string: amountText), amount > 0 else {
                throw PersonalLedgerError.amountMustBePositive
            }
            let fxRate = try parseFXRateIfNeeded()
            let input = PersonalTransactionInput(id: editingRecord?.id,
                                                 kind: kind,
                                                 accountId: accountId,
                                                 categoryKey: categoryKey,
                                                 amount: amount,
                                                 occurredAt: occurredAt,
                                                 note: note,
                                                 attachmentPath: attachmentURL?.path,
                                                 displayCurrency: store.preferences.primaryDisplayCurrency,
                                                 fxRate: fxRate)
            _ = try store.saveTransaction(input)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func updateDefaultCategory() {
        switch kind {
        case .expense:
            if !PersonalCategoryOption.commonExpenseKeys.contains(categoryKey) {
                categoryKey = PersonalCategoryOption.commonExpenseKeys.first ?? "food"
            }
        case .income:
            if !PersonalCategoryOption.commonIncomeKeys.contains(categoryKey) {
                categoryKey = PersonalCategoryOption.commonIncomeKeys.first ?? "salary"
            }
        case .fee:
            categoryKey = "fees"
        }
    }

    private func parseFXRateIfNeeded() throws -> Decimal? {
        guard showFXField else { return nil }
        guard let value = Decimal(string: fxRateText), value > 0 else {
            throw PersonalLedgerError.invalidExchangeRate
        }
        return value
    }

    private func attachmentDirectory() throws -> URL {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = root.appendingPathComponent("PersonalLedgerAttachments", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private static func decimalString(from minorUnits: Int) -> String {
        let decimal = SettlementMath.decimal(fromMinorUnits: minorUnits, scale: 2)
        return NSDecimalNumber(decimal: decimal).stringValue
    }
}

@MainActor
final class PersonalAccountsViewModel: ObservableObject {
    @Published private(set) var accounts: [PersonalAccountRowViewData] = []
    @Published private(set) var totalSummary = PersonalNetWorthSummaryViewData(totalMinorUnits: 0, displayCurrency: .cny)
    @Published var showArchived = false { didSet { Task { await refresh() } } }
    @Published var lastError: String?

    let store: PersonalLedgerStore

    init(store: PersonalLedgerStore) {
        self.store = store
        Task { await refresh() }
    }

    func refresh() async {
        let source = showArchived ? store.activeAccounts + store.archivedAccounts : store.activeAccounts
        accounts = source.map { account in
            let converted = convertBalance(account)
            return PersonalAccountRowViewData(id: account.remoteId,
                                              name: account.name,
                                              type: account.type,
                                              currency: account.currency,
                                              balanceMinorUnits: account.balanceMinorUnits,
                                              includeInNetWorth: account.includeInNetWorth,
                                              note: account.note,
                                              status: account.status,
                                              convertedBalanceMinorUnits: converted)
        }
        totalSummary = PersonalNetWorthSummaryViewData(totalMinorUnits: calculateNetWorth(),
                                                       displayCurrency: store.preferences.primaryDisplayCurrency)
    }

    func archiveAccount(_ id: UUID) async {
        do {
            try store.archiveAccount(id: id)
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func activateAccount(_ id: UUID) async {
        do {
            try store.activateAccount(id: id)
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteAccount(_ id: UUID) async {
        do {
            try store.deleteAccount(id: id)
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func convertBalance(_ account: PersonalAccount) -> Int {
        store.convertToDisplay(minorUnits: account.balanceMinorUnits, currency: account.currency, fxRate: nil)
    }

    private func calculateNetWorth() -> Int {
        store.activeAccounts
            .filter { $0.includeInNetWorth && $0.status == .active }
            .map { account in
                store.convertToDisplay(minorUnits: account.balanceMinorUnits, currency: account.currency, fxRate: nil)
            }
            .reduce(0, +)
    }
}

@MainActor
final class PersonalAccountFormViewModel: ObservableObject {
    @Published var draft: PersonalAccountDraft
    @Published var isSaving = false
    @Published var errorMessage: String?

    private let store: PersonalLedgerStore
    private let isEditing: Bool

    init(store: PersonalLedgerStore, accountId: UUID? = nil) {
        self.store = store
        if let accountId, let account = (store.activeAccounts + store.archivedAccounts).first(where: { $0.remoteId == accountId }) {
            draft = PersonalAccountDraft(id: account.remoteId,
                                         name: account.name,
                                         type: account.type,
                                         currency: account.currency,
                                         includeInNetWorth: account.includeInNetWorth,
                                         initialBalance: SettlementMath.decimal(fromMinorUnits: account.balanceMinorUnits, scale: 2),
                                         note: account.note,
                                         status: account.status)
            isEditing = true
        } else {
            draft = PersonalAccountDraft()
            isEditing = false
        }
    }

    func submit() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            if isEditing {
                try store.updateAccount(from: draft)
            } else {
                _ = try store.createAccount(from: draft)
            }
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

@MainActor
final class PersonalTransferFormViewModel: ObservableObject {
    @Published var fromAccountId: UUID? {
        didSet { updateDefaultFXRate() }
    }
    @Published var toAccountId: UUID?
    @Published var amountText: String = ""
    @Published var fxRateText: String = "1"
    @Published var feeText: String = ""
    @Published var selectedFeeSide: PersonalTransferFeeSide = .from
    @Published var note: String = ""
    @Published var occurredAt: Date = Date()
    @Published var errorMessage: String?
    @Published var isSaving = false

    private let store: PersonalLedgerStore
    private let transferId: UUID?

    var accounts: [PersonalAccount] { store.activeAccounts }

    init(store: PersonalLedgerStore, transferId: UUID? = nil) {
        self.store = store
        self.transferId = transferId
        fromAccountId = store.activeAccounts.first?.remoteId
        toAccountId = store.activeAccounts.dropFirst().first?.remoteId
        updateDefaultFXRate()
    }

    private func updateDefaultFXRate() {
        guard let fromAccountId, let account = store.account(with: fromAccountId) else {
            fxRateText = "1"
            return
        }
        if account.currency == store.preferences.primaryDisplayCurrency {
            fxRateText = "1"
            return
        }
        if let stored = store.preferences.fxRates[account.currency], stored > 0 {
            fxRateText = NSDecimalNumber(decimal: stored).stringValue
        } else if let fallback = store.preferences.defaultFXRate, fallback > 0 {
            fxRateText = NSDecimalNumber(decimal: fallback).stringValue
        } else {
            fxRateText = "1"
        }
    }

    func submit() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            guard let fromId = fromAccountId, let toId = toAccountId else {
                throw PersonalLedgerError.accountRequired
            }
            guard let amount = Decimal(string: amountText), amount > 0 else {
                throw PersonalLedgerError.amountMustBePositive
            }
            guard let fxRate = Decimal(string: fxRateText), fxRate > 0 else {
                throw PersonalLedgerError.invalidExchangeRate
            }
            var feeAmount: Decimal? = nil
            if !feeText.trimmingCharacters(in: .whitespaces).isEmpty {
                guard let parsed = Decimal(string: feeText), parsed >= 0 else {
                    throw PersonalLedgerError.amountMustBePositive
                }
                feeAmount = parsed
            }
            let input = PersonalTransferInput(id: transferId,
                                              fromAccountId: fromId,
                                              toAccountId: toId,
                                              amountFrom: amount,
                                              fxRate: fxRate,
                                              occurredAt: occurredAt,
                                              note: note,
                                              feeAmount: feeAmount,
                                              feeCurrency: nil,
                                              feeSide: feeAmount == nil ? nil : selectedFeeSide)
            _ = try store.saveTransfer(input)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

@MainActor
final class PersonalAllRecordsViewModel: ObservableObject {
    @Published var filterState: PersonalRecordFilterState
    @Published private(set) var records: [PersonalRecordRowViewData] = []
    @Published var selection: Set<UUID> = []
    @Published var lastError: String?

    private let store: PersonalLedgerStore
    private var cancellables: Set<AnyCancellable> = []

    init(store: PersonalLedgerStore, anchorDate: Date = Date()) {
        self.store = store
        if let interval = Calendar.current.dateInterval(of: .day, for: anchorDate) {
            filterState = PersonalRecordFilterState(dateRange: interval.start...interval.end,
                                                    kinds: [.income, .expense],
                                                    accountIds: [],
                                                    categoryKeys: [],
                                                    minAmountText: "",
                                                    maxAmountText: "",
                                                    keyword: "")
        } else {
            filterState = .default
        }
        Task { await refresh() }
        store.$activeAccounts
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
            .store(in: &cancellables)
    }

    func refresh() async {
        do {
            let transactions = try store.records(filter: filterState.toFilter())
            records = transactions.compactMap(mapRecord(_:))
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteSelected() async {
        do {
            try store.deleteTransactions(ids: Array(selection))
            selection.removeAll()
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func exportCSV() throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        var csv = "日期,账户,类型,分类,金额,币种,备注\n"
        for record in records {
            let dateString = formatter.string(from: record.occurredAt)
            let typeString: String
            switch record.kind {
            case .income: typeString = "Income"
            case .expense: typeString = "Expense"
            case .fee: typeString = "Fee"
            }
            let amount = SettlementMath.decimal(fromMinorUnits: record.amountMinorUnits, scale: 2)
            csv += "\(dateString),\(record.accountName),\(typeString),\(record.categoryName),\(amount),\(record.currency.rawValue),\(record.note.replacingOccurrences(of: ",", with: " "))\n"
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("PersonalLedgerRecords-\(UUID().uuidString).csv")
        try csv.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }

    private func mapRecord(_ transaction: PersonalTransaction) -> PersonalRecordRowViewData? {
        guard let account = store.account(with: transaction.accountId) else {
            return nil
        }
        let category = (expenseCategories + incomeCategories + feeCategories).first(where: { $0.key == transaction.categoryKey })
        return PersonalRecordRowViewData(id: transaction.remoteId,
                                         categoryKey: transaction.categoryKey,
                                         categoryName: category?.localizedName ?? transaction.categoryKey.capitalized,
                                         systemImage: category?.systemImage ?? iconForCategory(key: transaction.categoryKey),
                                         note: transaction.note,
                                         amountMinorUnits: transaction.amountMinorUnits,
                                         currency: account.currency,
                                         kind: transaction.kind,
                                         occurredAt: transaction.occurredAt,
                                         accountName: account.name,
                                         accountId: account.remoteId)
    }
}

@MainActor
final class PersonalStatsViewModel: ObservableObject {
    enum Period: String, CaseIterable, Identifiable {
        case month
        case quarter
        case year

        var id: String { rawValue }
    }

    @Published var period: Period = .month { didSet { Task { await refresh() } } }
    @Published var anchorDate: Date = Date() { didSet { Task { await refresh() } } }
    @Published var includeFees: Bool = true { didSet { Task { await refresh() } } }
    @Published var selectedAccountIds: Set<UUID> = [] { didSet { Task { await refresh() } } }
    @Published private(set) var timeline: [PersonalStatsSeriesPoint] = []
    @Published private(set) var breakdown: [PersonalStatsCategoryShare] = []
    @Published var lastError: String?

    private let store: PersonalLedgerStore

    init(store: PersonalLedgerStore) {
        self.store = store
        Task { await refresh() }
    }

    func refresh() async {
        do {
            let range = dateRange()
            let kinds: Set<PersonalTransactionKind> = includeFees ? [.income, .expense, .fee] : [.income, .expense]
            let timelineMap = try store.timeline(for: range,
                                                 kinds: kinds,
                                                 accountIds: selectedAccountIds.isEmpty ? nil : selectedAccountIds)
            let sortedDates = timelineMap.keys.sorted()
            timeline = sortedDates.map { date in
                let entry = timelineMap[date] ?? (income: 0, expense: 0)
                return PersonalStatsSeriesPoint(date: date,
                                                 incomeMinorUnits: entry.income,
                                                 expenseMinorUnits: entry.expense)
            }
            let breakdownMap = try store.categoryBreakdown(for: range,
                                                            includeFees: includeFees,
                                                            accountIds: selectedAccountIds.isEmpty ? nil : selectedAccountIds)
            breakdown = breakdownMap.map { key, value in
                PersonalStatsCategoryShare(categoryKey: key, amountMinorUnits: value)
            }.sorted { $0.amountMinorUnits > $1.amountMinorUnits }
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func dateRange() -> ClosedRange<Date> {
        let calendar = Calendar.current
        switch period {
        case .month:
            let interval = calendar.dateInterval(of: .month, for: anchorDate) ?? DateInterval(start: anchorDate, duration: 0)
            return interval.start...interval.end
        case .quarter:
            let month = calendar.component(.month, from: anchorDate)
            let quarterIndex = ((month - 1) / 3) * 3
            var components = calendar.dateComponents([.year], from: anchorDate)
            components.month = quarterIndex + 1
            guard let start = calendar.date(from: components),
                  let end = calendar.date(byAdding: .month, value: 3, to: start) else {
                return anchorDate...anchorDate
            }
            return start...end
        case .year:
            let interval = calendar.dateInterval(of: .year, for: anchorDate) ?? DateInterval(start: anchorDate, duration: 0)
            return interval.start...interval.end
        }
    }
}

@MainActor
final class PersonalLedgerSettingsViewModel: ObservableObject {
    @Published var primaryCurrency: CurrencyCode
    @Published var fxSource: PersonalFXSource
    @Published var defaultFXPrecision: Int
    @Published var defaultFXRateText: String
    @Published var countFeeInStats: Bool
    @Published var feeCategoryKey: String
    @Published var fxRates: [CurrencyCode: String]
    @Published var lastError: String?

    private let store: PersonalLedgerStore

    init(store: PersonalLedgerStore) {
        self.store = store
        let prefs = store.preferences
        primaryCurrency = prefs.primaryDisplayCurrency
        fxSource = prefs.fxSource
        defaultFXPrecision = prefs.defaultFXPrecision
        if let rate = prefs.defaultFXRate {
            defaultFXRateText = NSDecimalNumber(decimal: rate).stringValue
        } else {
            defaultFXRateText = ""
        }
        countFeeInStats = prefs.countFeeInStats
        feeCategoryKey = prefs.defaultFeeCategoryKey ?? "fees"
        fxRates = Dictionary(uniqueKeysWithValues: prefs.fxRates.map { ($0.key, NSDecimalNumber(decimal: $0.value).stringValue) })
    }

    func save() async {
        do {
            let defaultRate = Decimal(string: defaultFXRateText)
            var parsedRates: [CurrencyCode: Decimal] = [:]
            for (code, text) in fxRates {
                if let value = Decimal(string: text), value > 0 {
                    parsedRates[code] = value
                }
            }
            try store.updatePreferences { prefs in
                prefs.primaryDisplayCurrency = primaryCurrency
                prefs.fxSource = fxSource
                prefs.defaultFXPrecision = defaultFXPrecision
                prefs.countFeeInStats = countFeeInStats
                prefs.defaultFeeCategoryKey = feeCategoryKey
                prefs.defaultFXRate = defaultRate
                prefs.fxRates = parsedRates
            }
        } catch {
            lastError = error.localizedDescription
        }
    }
}
