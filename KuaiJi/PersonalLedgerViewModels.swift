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

struct PersonalOverviewEntry: Identifiable, Hashable {
    var currency: CurrencyCode
    var expenseMinorUnits: Int
    var incomeMinorUnits: Int

    var id: CurrencyCode { currency }
}

struct PersonalOverviewState {
    var entries: [PersonalOverviewEntry] = []
    var includeFees: Bool = true
}

struct PersonalYearMonth: Hashable, Identifiable, Comparable {
    var year: Int
    var month: Int

    var id: String { "\(year)-\(month)" }

    var date: Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }

    static func < (lhs: PersonalYearMonth, rhs: PersonalYearMonth) -> Bool {
        if lhs.year == rhs.year { return lhs.month < rhs.month }
        return lhs.year < rhs.year
    }
}

// Removed: PersonalMonthlyTotals (no longer needed after removing totals display in archive)

struct PersonalRecordRowViewData: Identifiable, Hashable {
    enum EntryNature: Hashable {
        case transaction(PersonalTransactionKind)
        case transfer
    }

    var id: UUID
    var categoryKey: String
    var categoryName: String
    var categoryColorHex: String?
    var systemImage: String
    var note: String
    var amountMinorUnits: Int
    var currency: CurrencyCode
    var occurredAt: Date
    var createdAt: Date
    var accountName: String
    var accountId: UUID?
    var entryNature: EntryNature
    var transferDescription: String?

    var isTransfer: Bool {
        if case .transfer = entryNature { return true }
        return false
    }

    var amountIsPositive: Bool {
        switch entryNature {
        case .transaction(let kind): return kind == .income
        case .transfer: return false
        }
    }

    var transactionKind: PersonalTransactionKind? {
        if case .transaction(let kind) = entryNature { return kind }
        return nil
    }
}

struct PersonalRecordTemplateViewData: Identifiable, Hashable {
    var id: UUID
    var name: String
    var accountId: UUID?
    var accountName: String?
    var amountMinorUnits: Int
    var currency: CurrencyCode
    var categoryKey: String
    var categoryName: String
    var systemImage: String
    var note: String?
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
    var creditLimitMinorUnits: Int?
}

struct PersonalNetWorthEntry: Identifiable, Hashable {
    var currency: CurrencyCode
    var totalMinorUnits: Int

    var id: CurrencyCode { currency }
}

struct PersonalNetWorthSummaryViewData {
    var entries: [PersonalNetWorthEntry]
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
                                                     kinds: [.income, .expense, .fee],
                                                     accountIds: [],
                                                     categoryKeys: [],
                                                     minAmountText: "",
                                                     maxAmountText: "",
                                                     keyword: "")

    func toFilter() -> PersonalRecordFilter {
        var minimum: Int?
        if let value = NumberParsing.parseDecimal(minAmountText), value > 0 {
            minimum = SettlementMath.minorUnits(from: value, scale: 2)
        }
        var maximum: Int?
        if let value = NumberParsing.parseDecimal(maxAmountText), value > 0 {
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
    var transactionCount: Int
}

struct PersonalStatsGrowthMetrics {
    let current: Int
    let previous: Int
    let delta: Int
    let rate: Double
}

enum PersonalStatsCategoryFocus {
    case expense
    case income
}

@MainActor
final class PersonalLedgerRootViewModel: ObservableObject {
    let store: PersonalLedgerStore

    init(modelContext: ModelContext, defaultCurrency: CurrencyCode) {
        do {
            self.store = try PersonalLedgerStore(context: modelContext, defaultCurrency: defaultCurrency)
        } catch {
            #if DEBUG
            preconditionFailure("Failed to create PersonalLedgerStore: \(error)")
            #else
            // Fallback: attempt to create an in-memory container and store
            let schema = Schema([
                PersonalCategoryDefinition.self,
                PersonalAccount.self,
                PersonalTransaction.self,
                AccountTransfer.self,
                PersonalRecordTemplate.self,
                PersonalPreferences.self
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let container = try? ModelContainer(for: schema, configurations: [configuration]),
               let fallback = try? PersonalLedgerStore(context: container.mainContext, defaultCurrency: defaultCurrency) {
                self.store = fallback
            } else {
                fatalError("Fatal: cannot initialize PersonalLedgerStore even in fallback: \(error)")
            }
            #endif
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

    func makeAllRecordsViewModelForAll() -> PersonalAllRecordsViewModel {
        let vm = PersonalAllRecordsViewModel(store: store, anchorDate: Date())
        vm.filterState = .default
        return vm
    }

    func makeStatsViewModel() -> PersonalStatsViewModel {
        PersonalStatsViewModel(store: store)
    }

    func makeSettingsViewModel() -> PersonalLedgerSettingsViewModel {
        PersonalLedgerSettingsViewModel(store: store)
    }

    func makeCSVExportViewModel() -> PersonalCSVExportViewModel {
        PersonalCSVExportViewModel(store: store)
    }

    func makeTemplatesViewModel() -> PersonalRecordTemplatesViewModel {
        PersonalRecordTemplatesViewModel(store: store)
    }

    func makeTemplateFormViewModel(templateId: UUID? = nil) -> PersonalRecordTemplateFormViewModel {
        PersonalRecordTemplateFormViewModel(store: store, templateId: templateId)
    }

    func makeCategorySettingsViewModel() -> PersonalCategorySettingsViewModel {
        PersonalCategorySettingsViewModel(store: store)
    }
}

@MainActor
final class PersonalCSVExportViewModel: ObservableObject {
    enum PeriodMode: CaseIterable, Identifiable {
        case range
        case month
        case quarter
        case year

        var id: String {
            switch self {
            case .range: return "range"
            case .month: return "month"
            case .quarter: return "quarter"
            case .year: return "year"
            }
        }
    }

    @Published var periodMode: PeriodMode = .month { didSet { Task { await refresh() } } }
    @Published var anchorDate: Date = Date() { didSet { Task { await refresh() } } }
    @Published var fromDate: Date = Calendar.current.startOfDay(for: Date()) { didSet { Task { await refresh() } } }
    @Published var toDate: Date = Date() { didSet { Task { await refresh() } } }
    @Published var selectedAccountIds: Set<UUID> = [] { didSet { Task { await refresh() } } }
    @Published var selectedCurrencies: Set<CurrencyCode> = [] { didSet { Task { await refresh() } } }
    @Published private(set) var records: [PersonalRecordRowViewData] = []
    @Published var sortMode: PersonalAllRecordsViewModel.SortMode = .occurredAt { didSet { Task { await refresh() } } }

    private let store: PersonalLedgerStore
    private let calendar = Calendar.current

    init(store: PersonalLedgerStore) {
        self.store = store
        Task { await refresh() }
    }

    var availableAccounts: [PersonalAccount] { store.activeAccounts }
    var availableCurrencies: [CurrencyCode] { Array(Set(store.activeAccounts.map { $0.currency })).sorted { $0.rawValue < $1.rawValue } }

    func effectiveDateRange() -> ClosedRange<Date> {
        switch periodMode {
        case .range:
            let start = calendar.startOfDay(for: fromDate)
            let endDay = calendar.startOfDay(for: toDate)
            let end = calendar.date(byAdding: .day, value: 1, to: endDay) ?? endDay
            return start...end
        case .month:
            let interval = calendar.dateInterval(of: .month, for: anchorDate) ?? DateInterval(start: anchorDate, duration: 0)
            return interval.start...interval.end
        case .quarter:
            let month = calendar.component(.month, from: anchorDate)
            let quarterIndex = ((month - 1) / 3) * 3
            var components = calendar.dateComponents([.year], from: anchorDate)
            components.month = quarterIndex + 1
            let start = calendar.date(from: components) ?? anchorDate
            let end = calendar.date(byAdding: .month, value: 3, to: start) ?? start
            return start...end
        case .year:
            let interval = calendar.dateInterval(of: .year, for: anchorDate) ?? DateInterval(start: anchorDate, duration: 0)
            return interval.start...interval.end
        }
    }

    func refresh() async {
        do {
            let range = effectiveDateRange()
            let filter = PersonalRecordFilter(dateRange: range,
                                              kinds: [.income, .expense, .fee],
                                              accountIds: selectedAccountIds.isEmpty ? nil : selectedAccountIds,
                                              categoryKeys: nil,
                                              minimumAmountMinor: nil,
                                              maximumAmountMinor: nil,
                                              keyword: nil)
            var combined = try store.records(filter: filter).compactMap { mapTransaction($0) }
            let transfers = try store.transfers(in: range).compactMap { mapTransfer($0) }
            combined.append(contentsOf: transfers)
            if !selectedCurrencies.isEmpty {
                combined = combined.filter { selectedCurrencies.contains($0.currency) }
            }
            records = sort(records: combined)
        } catch {
            records = []
        }
    }

    func exportCSV() throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        var csv = "日期,账户,类型,分类,金额,币种,备注\n"
        for record in records {
            let dateString = formatter.string(from: record.occurredAt)
            let typeString: String
            switch record.entryNature {
            case .transaction(let kind):
                switch kind {
                case .income: typeString = "Income"
                case .expense: typeString = "Expense"
                case .fee: typeString = "Fee"
                }
            case .transfer:
                typeString = "Transfer"
            }
            let amount = SettlementMath.decimal(fromMinorUnits: record.amountMinorUnits, scale: 2)
            csv += "\(dateString),\(record.accountName),\(typeString),\(record.categoryName),\(amount),\(record.currency.rawValue),\(record.note.replacingOccurrences(of: ",", with: " "))\n"
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("PersonalCSV-\(UUID().uuidString).csv")
        try csv.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }

    private func mapTransaction(_ transaction: PersonalTransaction) -> PersonalRecordRowViewData? {
        guard let account = store.account(with: transaction.accountId) else {
            return nil
        }
        let category = store.categoryOption(for: transaction.categoryKey)
        return PersonalRecordRowViewData(id: transaction.remoteId,
                                         categoryKey: transaction.categoryKey,
                                         categoryName: category?.localizedName ?? store.categoryName(for: transaction.categoryKey),
                                         categoryColorHex: store.categoryColor(for: transaction.categoryKey).toHexRGB(),
                                         systemImage: category?.systemImage ?? store.categoryIcon(for: transaction.categoryKey),
                                         note: transaction.note,
                                         amountMinorUnits: transaction.amountMinorUnits,
                                         currency: account.currency,
                                         occurredAt: transaction.occurredAt,
                                         createdAt: transaction.createdAt,
                                         accountName: account.name,
                                         accountId: account.remoteId,
                                         entryNature: .transaction(transaction.kind),
                                         transferDescription: nil)
    }

    private func mapTransfer(_ transfer: AccountTransfer) -> PersonalRecordRowViewData? {
        guard let fromAccount = store.account(with: transfer.fromAccountId),
              let toAccount = store.account(with: transfer.toAccountId) else {
            return nil
        }
        let direction = String(format: L.personalTransferDirection.localized, fromAccount.name, toAccount.name)
        return PersonalRecordRowViewData(id: transfer.remoteId,
                                         categoryKey: "transfer",
                                         categoryName: L.personalTransferTitle.localized,
                                         systemImage: "arrow.left.arrow.right",
                                         note: transfer.note,
                                         amountMinorUnits: -transfer.amountFromMinorUnits,
                                         currency: fromAccount.currency,
                                         occurredAt: transfer.occurredAt,
                                         createdAt: transfer.createdAt,
                                         accountName: fromAccount.name,
                                         accountId: fromAccount.remoteId,
                                         entryNature: .transfer,
                                         transferDescription: direction)
    }

    private func sort(records: [PersonalRecordRowViewData]) -> [PersonalRecordRowViewData] {
        switch sortMode {
        case .occurredAt:
            return records.sorted { lhs, rhs in
                if lhs.occurredAt == rhs.occurredAt { return lhs.createdAt > rhs.createdAt }
                return lhs.occurredAt > rhs.occurredAt
            }
        case .createdAt:
            return records.sorted { lhs, rhs in rhs.createdAt < lhs.createdAt }
        }
    }

    func delete(recordId: UUID) async {
        do {
            try store.deleteTransactionsOrTransfers(ids: [recordId])
            await refresh()
        } catch {
            print("Delete failed: \(error)")
        }
    }
}

@MainActor
final class PersonalLedgerHomeViewModel: ObservableObject {
    enum RecordSortMode: CaseIterable {
        case occurred
        case created

        var displayTitle: String {
            switch self {
            case .occurred: return L.personalSortOccurred.localized
            case .created: return L.personalSortCreated.localized
            }
        }
    }

    @Published var selectedMonth: Date
    @Published private(set) var overview = PersonalOverviewState()
    @Published private(set) var todayRecords: [PersonalRecordRowViewData] = []
    @Published private(set) var isLoading = false
    @Published var lastErrorMessage: String?
    @Published var recordSortMode: RecordSortMode = .occurred

    private let store: PersonalLedgerStore
    private let calendar: Calendar
    private var minAvailableMonth: Date
    private var maxAvailableMonth: Date
    private var cancellables: Set<AnyCancellable> = []
    private var cachedRange: ClosedRange<Date>?
    private var cachedYearMonths: [PersonalYearMonth] = []
    @Published private(set) var availableMonths: [PersonalYearMonth] = []
    @Published private(set) var isLoadingArchive = false
    @Published private(set) var archiveError: String?
    // Removed: totalsByMonth cache (no longer used by the archive screen)

    var displayCurrency: CurrencyCode { store.safePrimaryDisplayCurrency() }

    init(store: PersonalLedgerStore) {
        self.store = store
        let calendar = Calendar.current
        self.calendar = calendar
        let currentMonth = calendar.startOfMonth(for: Date())
        self.selectedMonth = currentMonth
        // 允许用户在无数据月份之间切换，范围为当前月份的前后 12 个月
        self.minAvailableMonth = calendar.date(byAdding: .month, value: -12, to: currentMonth) ?? currentMonth
        self.maxAvailableMonth = calendar.date(byAdding: .month, value: 12, to: currentMonth) ?? currentMonth
        subscribeToStore()
        Task { await refresh() }
        $recordSortMode
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
            .store(in: &cancellables)
    }

    var canGoToPreviousMonth: Bool {
        guard let previous = calendar.date(byAdding: .month, value: -1, to: selectedMonth) else { return false }
        return calendar.startOfMonth(for: previous) >= minAvailableMonth
    }

    var canGoToNextMonth: Bool {
        guard let next = calendar.date(byAdding: .month, value: 1, to: selectedMonth) else { return false }
        return calendar.startOfMonth(for: next) <= maxAvailableMonth
    }

    func toggleSortMode() {
        recordSortMode = recordSortMode == .occurred ? .created : .occurred
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let includeFees = store.safeCountFeeInStats()
            var entries: [PersonalOverviewEntry] = []
            if let interval = calendar.dateInterval(of: .month, for: selectedMonth) {
                let kinds: Set<PersonalTransactionKind> = includeFees ? [.income, .expense, .fee] : [.income, .expense]
                let filter = PersonalRecordFilter(dateRange: interval.start...interval.end, kinds: kinds)
                let transactions = try store.records(filter: filter)
                var totalsByCurrency: [CurrencyCode: (expense: Int, income: Int)] = [:]
                for transaction in transactions {
                    guard let account = store.account(with: transaction.accountId) else { continue }
                    let currency = account.currency
                    var bucket = totalsByCurrency[currency] ?? (expense: 0, income: 0)
                    switch transaction.kind {
                    case .income:
                        bucket.income += transaction.amountMinorUnits
                    case .expense:
                        bucket.expense += transaction.amountMinorUnits
                    case .fee:
                        if includeFees {
                            bucket.expense += transaction.amountMinorUnits
                        }
                    }
                    totalsByCurrency[currency] = bucket
                }
                entries = totalsByCurrency.map { (currency, bucket) in
                    PersonalOverviewEntry(currency: currency,
                                          expenseMinorUnits: bucket.expense,
                                          incomeMinorUnits: bucket.income)
                }
                let defaultCurrency = store.safePrimaryDisplayCurrency()
                entries.sort {
                    if $0.currency == defaultCurrency && $1.currency != defaultCurrency {
                        return true
                    }
                    if $1.currency == defaultCurrency && $0.currency != defaultCurrency {
                        return false
                    }
                    return $0.currency.rawValue < $1.currency.rawValue
                }
            }
            if entries.isEmpty {
                let defaultCurrency = store.safePrimaryDisplayCurrency()
                entries = [PersonalOverviewEntry(currency: defaultCurrency,
                                                 expenseMinorUnits: 0,
                                                 incomeMinorUnits: 0)]
            }
            overview = PersonalOverviewState(entries: entries,
                                             includeFees: includeFees)

            guard let monthInterval = calendar.dateInterval(of: .month, for: selectedMonth) else {
                todayRecords = []
                return
            }

            let monthlyRange = monthInterval.start...monthInterval.end
            let monthlyFilter = PersonalRecordFilter(dateRange: monthlyRange,
                                                     kinds: [.income, .expense, .fee],
                                                     accountIds: [],
                                                     categoryKeys: [],
                                                     minimumAmountMinor: nil,
                                                     maximumAmountMinor: nil,
                                                     keyword: nil)
            var rows = try store.records(filter: monthlyFilter).compactMap(mapTransaction(_:))
            let transfers = try store.transfers(in: monthlyRange).compactMap(mapTransfer(_:))
            rows.append(contentsOf: transfers)
            todayRecords = Array(sort(records: rows).prefix(5))
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func changeMonth(by offset: Int) {
        guard offset != 0,
              let candidate = calendar.date(byAdding: .month, value: offset, to: selectedMonth) else {
            return
        }
        let normalized = calendar.startOfMonth(for: candidate)
        guard normalized >= minAvailableMonth, normalized <= maxAvailableMonth else {
            return
        }
        selectedMonth = normalized
        Task { await refresh() }
    }

    func setSelectedMonth(_ date: Date) {
        let normalized = calendar.startOfMonth(for: date)
        selectedMonth = normalized
    }

    func prepareArchive() {
        isLoadingArchive = true
        archiveError = nil
        Task {
            do {
                let bounds = try store.personalDataBounds()
                await MainActor.run {
                    self.cachedRange = bounds
                    self.cachedYearMonths = makeYearMonths(range: bounds)
                    self.availableMonths = self.cachedYearMonths
                    self.isLoadingArchive = false
                }
            } catch {
                let month = calendar.startOfMonth(for: selectedMonth)
                let range = month...month
                await MainActor.run {
                    self.cachedRange = range
                    self.cachedYearMonths = makeYearMonths(range: range)
                    self.availableMonths = self.cachedYearMonths
                    self.archiveError = error.localizedDescription
                    self.isLoadingArchive = false
                }
            }
        }
    }

    // Removed: totals(for:) (no longer needed by the archive screen)

    private func makeYearMonths(range: ClosedRange<Date>) -> [PersonalYearMonth] {
        var months: [PersonalYearMonth] = []
        var current = calendar.startOfMonth(for: range.lowerBound)
        let end = calendar.startOfMonth(for: range.upperBound)
        while current <= end {
            let components = calendar.dateComponents([.year, .month], from: current)
            if let year = components.year, let month = components.month {
                months.append(PersonalYearMonth(year: year, month: month))
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: current) else { break }
            current = next
        }
        return months.sorted(by: >)
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

    private func mapTransaction(_ transaction: PersonalTransaction) -> PersonalRecordRowViewData? {
        guard let account = store.account(with: transaction.accountId) else {
            return nil
        }
        let category = store.categoryOption(for: transaction.categoryKey)
        return PersonalRecordRowViewData(id: transaction.remoteId,
                                         categoryKey: transaction.categoryKey,
                                         categoryName: category?.localizedName ?? store.categoryName(for: transaction.categoryKey),
                                         categoryColorHex: store.categoryColor(for: transaction.categoryKey).toHexRGB(),
                                         systemImage: category?.systemImage ?? store.categoryIcon(for: transaction.categoryKey),
                                         note: transaction.note,
                                         amountMinorUnits: transaction.amountMinorUnits,
                                         currency: account.currency,
                                         occurredAt: transaction.occurredAt,
                                         createdAt: transaction.createdAt,
                                         accountName: account.name,
                                         accountId: account.remoteId,
                                         entryNature: .transaction(transaction.kind),
                                         transferDescription: nil)
    }

    private func mapTransfer(_ transfer: AccountTransfer) -> PersonalRecordRowViewData? {
        guard let fromAccount = store.account(with: transfer.fromAccountId),
              let toAccount = store.account(with: transfer.toAccountId) else {
            return nil
        }
        let direction = String(format: L.personalTransferDirection.localized, fromAccount.name, toAccount.name)
        return PersonalRecordRowViewData(id: transfer.remoteId,
                                         categoryKey: "transfer",
                                         categoryName: L.personalTransferTitle.localized,
                                         systemImage: "arrow.left.arrow.right",
                                         note: transfer.note,
                                         amountMinorUnits: -transfer.amountFromMinorUnits,
                                         currency: fromAccount.currency,
                                         occurredAt: transfer.occurredAt,
                                         createdAt: transfer.createdAt,
                                         accountName: fromAccount.name,
                                         accountId: fromAccount.remoteId,
                                         entryNature: .transfer,
                                         transferDescription: direction)
    }

    private func sort(records: [PersonalRecordRowViewData]) -> [PersonalRecordRowViewData] {
        records.sorted { lhs, rhs in
            let lhsKey = recordSortMode == .occurred ? lhs.occurredAt : lhs.createdAt
            let rhsKey = recordSortMode == .occurred ? rhs.occurredAt : rhs.createdAt
            if lhsKey == rhsKey {
                return lhs.createdAt > rhs.createdAt
            }
            return lhsKey > rhsKey
        }
    }
}

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? date
    }
}

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

@MainActor
final class PersonalRecordTemplatesViewModel: ObservableObject {
    @Published private(set) var templates: [PersonalRecordTemplateViewData] = []
    @Published var lastError: String?

    private let store: PersonalLedgerStore
    private var cancellables: Set<AnyCancellable> = []

    init(store: PersonalLedgerStore) {
        self.store = store
        Task { await refresh() }
        store.$recordTemplates
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildTemplates() }
            .store(in: &cancellables)
        store.$activeAccounts
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildTemplates() }
            .store(in: &cancellables)
        store.$archivedAccounts
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildTemplates() }
            .store(in: &cancellables)
        store.$customCategories
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildTemplates() }
            .store(in: &cancellables)
    }

    func refresh() async {
        do {
            try store.refreshTemplates()
            rebuildTemplates()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteTemplate(id: UUID) async {
        do {
            try store.deleteTemplate(id: id)
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        var newList = templates
        newList.move(fromOffsets: source, toOffset: destination)
        templates = newList
        Task {
            do {
                try store.reorderTemplates(idsInDisplayOrder: newList.map { $0.id })
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func rebuildTemplates() {
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
}

@MainActor
final class PersonalRecordTemplateFormViewModel: ObservableObject {
    @Published var name: String
    @Published var accountId: UUID?
    @Published var amountText: String
    @Published var currency: CurrencyCode
    @Published var categoryKey: String
    @Published var note: String
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published private(set) var categoryOptions: [PersonalCategoryOption] = []

    var accounts: [PersonalAccount] { store.activeAccounts }
    var currencyOptions: [CurrencyCode] { CurrencyCode.allCases }
    var isEditing: Bool { editingId != nil }

    private let store: PersonalLedgerStore
    private let editingId: UUID?
    private var cancellables: Set<AnyCancellable> = []

    init(store: PersonalLedgerStore, templateId: UUID? = nil) {
        self.store = store
        self.editingId = templateId
        if let templateId, let template = store.template(with: templateId) {
            name = template.name
            if let accountId = template.accountId, store.account(with: accountId) != nil {
                self.accountId = accountId
            } else {
                self.accountId = nil
            }
            amountText = template.amountMinorUnits > 0 ? Self.decimalString(from: template.amountMinorUnits) : ""
            currency = template.currency
            categoryKey = template.categoryKey
            note = template.note ?? ""
        } else {
            name = ""
            self.accountId = nil
            amountText = ""
            currency = store.safePrimaryDisplayCurrency()
            categoryKey = ""
            note = ""
        }
        reloadCategories()
        enforceValidCategory()
        subscribeToStore()
    }

    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            var parsedAmount: Decimal = 0
            if !amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                guard let amount = NumberParsing.parseDecimal(amountText), amount >= 0 else {
                    throw PersonalLedgerError.amountMustBePositive
                }
                parsedAmount = amount
            }
            let input = PersonalRecordTemplateInput(id: editingId,
                                                    name: trimmedName,
                                                    accountId: accountId,
                                                    amount: parsedAmount,
                                                    currency: currency,
                                                    categoryKey: categoryKey,
                                                    note: cleanedNote.isEmpty ? nil : cleanedNote)
            _ = try store.saveTemplate(input)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private static func decimalString(from minorUnits: Int) -> String {
        let decimal = SettlementMath.decimal(fromMinorUnits: minorUnits, scale: 2)
        return NSDecimalNumber(decimal: decimal).stringValue
    }

    private func reloadCategories() {
        let includeHiddenKey = store.systemCategoryHidden(categoryKey) ? categoryKey : nil
        categoryOptions = store.categoryOptions(for: .expense, includeHiddenKey: includeHiddenKey)
    }

    private func enforceValidCategory() {
        if store.systemCategoryHidden(categoryKey), !isEditing {
            let visible = store.categoryOptions(for: .expense, includeHiddenKey: nil)
            if let first = visible.first {
                categoryKey = first.key
                return
            }
        }
        if categoryKey.isEmpty { return }
        if !categoryOptions.contains(where: { $0.key == categoryKey }) {
            categoryKey = categoryOptions.first?.key ?? ""
        }
    }

    private func subscribeToStore() {
        store.$customCategories
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadCategories()
                self?.enforceValidCategory()
            }
            .store(in: &cancellables)
        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadCategories()
                self?.enforceValidCategory()
            }
            .store(in: &cancellables)
    }
}

@MainActor
final class PersonalAccountsViewModel: ObservableObject {
    @Published private(set) var accounts: [PersonalAccountRowViewData] = []
    @Published private(set) var totalSummary = PersonalNetWorthSummaryViewData(entries: [])
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
                                              convertedBalanceMinorUnits: converted,
                                              creditLimitMinorUnits: account.creditLimitMinorUnits)
        }
        totalSummary = PersonalNetWorthSummaryViewData(entries: calculateNetWorthEntries())
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

    // 拖拽排序：更新本地顺序并持久化
    func move(from source: IndexSet, to destination: Int) {
        var newList = accounts
        newList.move(fromOffsets: source, toOffset: destination)
        accounts = newList
        Task {
            do {
                try store.reorderAccounts(idsInDisplayOrder: newList.map { $0.id })
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func convertBalance(_ account: PersonalAccount) -> Int {
        store.convertToDisplay(minorUnits: account.balanceMinorUnits, currency: account.currency, fxRate: nil)
    }

    private func calculateNetWorthEntries() -> [PersonalNetWorthEntry] {
        let relevantAccounts = store.activeAccounts.filter { $0.includeInNetWorth && $0.status == .active }
        var totals: [CurrencyCode: Int] = [:]
        for account in relevantAccounts {
            totals[account.currency, default: 0] += account.balanceMinorUnits
        }
        if totals.isEmpty {
            return []
        }
        let primary = store.safePrimaryDisplayCurrency()
        return totals
            .map { PersonalNetWorthEntry(currency: $0.key, totalMinorUnits: $0.value) }
            .sorted {
                if $0.currency == primary && $1.currency != primary { return true }
                if $1.currency == primary && $0.currency != primary { return false }
                return $0.currency.rawValue < $1.currency.rawValue
            }
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
                                         creditLimit: account.creditLimitMinorUnits.map { SettlementMath.decimal(fromMinorUnits: $0, scale: 2) },
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
            if draft.type != .creditCard {
                draft.creditLimit = nil
            }
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
        didSet { handleAccountChange() }
    }
    @Published var toAccountId: UUID? {
        didSet { handleAccountChange() }
    }
    @Published var amountText: String = ""
    @Published var fxRateText: String = ""
    @Published var feeText: String = ""
    @Published var selectedFeeSide: PersonalTransferFeeSide = .from
    @Published var note: String = ""
    @Published var occurredAt: Date = Date()
    @Published var errorMessage: String?
    @Published var isSaving = false
    @Published private(set) var fxRateEditable = true

    private let store: PersonalLedgerStore
    private let transferId: UUID?

    var accounts: [PersonalAccount] { store.activeAccounts }
    private var defaultFeeValue: Decimal { store.safeDefaultConversionFee() ?? 0 }
    var fxRatePlaceholder: String {
        let value: Decimal
        if let account = currentFromAccount() {
            value = defaultFXRate(for: account)
        } else {
            value = 1
        }
        let string = NSDecimalNumber(decimal: value).stringValue
        return L.personalFXPlaceholder.localized(string)
    }
    var feePlaceholder: String {
        let string = NSDecimalNumber(decimal: defaultFeeValue).stringValue
        return L.personalFeePlaceholder.localized(string)
    }

    // 汇率方向信息，例如："1 CNY = 0.14 USD"，当无法解析汇率时显示问号
    var fxInfoText: String {
        guard let from = currentFromAccount()?.currency,
              let to = currentToAccount()?.currency else { return "" }
        let trimmed = fxRateText.trimmingCharacters(in: .whitespacesAndNewlines)
        let rateText: String
        if let parsed = NumberParsing.parseDecimal(trimmed), parsed > 0 {
            rateText = NSDecimalNumber(decimal: parsed).stringValue
        } else {
            rateText = "?"
        }
        return L.personalTransferFXInfo.localized(from.rawValue, rateText, to.rawValue)
    }

    init(store: PersonalLedgerStore, transferId: UUID? = nil) {
        self.store = store
        self.transferId = transferId
        fromAccountId = store.activeAccounts.first?.remoteId
        toAccountId = store.activeAccounts.dropFirst().first?.remoteId
        handleAccountChange()
    }

    private func handleAccountChange() {
        guard let fromAccount = currentFromAccount() else {
            fxRateEditable = true
            return
        }
        if let toAccount = currentToAccount(), fromAccount.currency == toAccount.currency {
            fxRateEditable = false
            fxRateText = ""
            feeText = ""
        } else {
            fxRateEditable = true
        }
    }

    private func shouldAllowFXRate() -> Bool {
        fxRateEditable
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

    private func currentFromAccount() -> PersonalAccount? {
        guard let fromAccountId else { return nil }
        return store.account(with: fromAccountId)
    }

    private func currentToAccount() -> PersonalAccount? {
        guard let toAccountId else { return nil }
        return store.account(with: toAccountId)
    }

    // 一键反转汇率：fxRateText = 1 / 当前值
    func invertFXRate() {
        let trimmed = fxRateText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = NumberParsing.parseDecimal(trimmed), parsed > 0 else { return }
        let inverted = 1 / parsed
        fxRateText = NSDecimalNumber(decimal: inverted).stringValue
    }

    func submit() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            guard let fromId = fromAccountId, let toId = toAccountId else {
                throw PersonalLedgerError.accountRequired
            }
            guard let amount = NumberParsing.parseDecimal(amountText), amount > 0 else {
                throw PersonalLedgerError.amountMustBePositive
            }
            let fxRate: Decimal
            if shouldAllowFXRate() {
                let trimmed = fxRateText.trimmingCharacters(in: .whitespacesAndNewlines)
                let baseAccount = currentFromAccount()
                if trimmed.isEmpty, let account = baseAccount {
                    fxRate = defaultFXRate(for: account)
                } else {
                    guard let parsed = NumberParsing.parseDecimal(trimmed), parsed > 0 else {
                        throw PersonalLedgerError.invalidExchangeRate
                    }
                    fxRate = parsed
                }
            } else {
                fxRate = 1
            }
            var feeAmount: Decimal? = nil
            let trimmedFee = feeText.trimmingCharacters(in: .whitespacesAndNewlines)
            let effectiveFee: Decimal
            if trimmedFee.isEmpty {
                effectiveFee = defaultFeeValue
            } else {
                guard let parsed = NumberParsing.parseDecimal(trimmedFee), parsed >= 0 else {
                    throw PersonalLedgerError.amountMustBePositive
                }
                effectiveFee = parsed
            }
            if effectiveFee > 0 {
                feeAmount = effectiveFee
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
    enum SortMode: CaseIterable, Identifiable {
        case occurredAt
        case createdAt

        var id: String {
            switch self {
            case .occurredAt: return "occurredAt"
            case .createdAt: return "createdAt"
            }
        }

        var title: String {
            switch self {
            case .occurredAt: return L.personalSortOccurred.localized
            case .createdAt: return L.personalSortCreated.localized
            }
        }
    }

    @Published var filterState: PersonalRecordFilterState
    @Published private(set) var records: [PersonalRecordRowViewData] = []
    @Published var selection: Set<UUID> = []
    @Published var sortMode: SortMode = .occurredAt { didSet { Task { await refresh() } } }
    @Published var lastError: String?

    private let store: PersonalLedgerStore
    private var cancellables: Set<AnyCancellable> = []

    init(store: PersonalLedgerStore, anchorDate: Date = Date()) {
        self.store = store
        if let interval = Calendar.current.dateInterval(of: .month, for: anchorDate) {
            filterState = PersonalRecordFilterState(dateRange: interval.start...interval.end,
                                                    kinds: [.income, .expense, .fee],
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
            let filter = filterState.toFilter()
            let transactions = try store.records(filter: filter)
            var combined = transactions.compactMap { mapTransaction($0) }
            let transfers = try store.transfers(in: filter.dateRange)
                .compactMap { mapTransfer($0) }
            combined.append(contentsOf: transfers)
            records = sort(records: combined)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteSelected() async {
        do {
            try store.deleteTransactionsOrTransfers(ids: Array(selection))
            selection.removeAll()
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteRecord(id: UUID) async {
        do {
            try store.deleteTransactionsOrTransfers(ids: [id])
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func sort(records: [PersonalRecordRowViewData]) -> [PersonalRecordRowViewData] {
        switch sortMode {
        case .occurredAt:
            return records.sorted { lhs, rhs in
                if lhs.occurredAt == rhs.occurredAt { return lhs.createdAt > rhs.createdAt }
                return lhs.occurredAt > rhs.occurredAt
            }
        case .createdAt:
            return records.sorted { lhs, rhs in rhs.createdAt < lhs.createdAt }
        }
    }
    func exportCSV() throws -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        var csv = "日期,账户,类型,分类,金额,币种,备注\n"
        for record in records {
            let dateString = formatter.string(from: record.occurredAt)
            let typeString: String
            switch record.entryNature {
            case .transaction(let kind):
                switch kind {
                case .income: typeString = "Income"
                case .expense: typeString = "Expense"
                case .fee: typeString = "Fee"
                }
            case .transfer:
                typeString = "Transfer"
            }
            let amount = SettlementMath.decimal(fromMinorUnits: record.amountMinorUnits, scale: 2)
            csv += "\(dateString),\(record.accountName),\(typeString),\(record.categoryName),\(amount),\(record.currency.rawValue),\(record.note.replacingOccurrences(of: ",", with: " "))\n"
        }
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("PersonalLedgerRecords-\(UUID().uuidString).csv")
        try csv.write(to: tempURL, atomically: true, encoding: .utf8)
        return tempURL
    }

    private func mapTransaction(_ transaction: PersonalTransaction) -> PersonalRecordRowViewData? {
        guard let account = store.account(with: transaction.accountId) else {
            return nil
        }
        let category = store.categoryOption(for: transaction.categoryKey)
        return PersonalRecordRowViewData(id: transaction.remoteId,
                                         categoryKey: transaction.categoryKey,
                                         categoryName: category?.localizedName ?? store.categoryName(for: transaction.categoryKey),
                                         categoryColorHex: store.categoryColor(for: transaction.categoryKey).toHexRGB(),
                                         systemImage: category?.systemImage ?? store.categoryIcon(for: transaction.categoryKey),
                                         note: transaction.note,
                                         amountMinorUnits: transaction.amountMinorUnits,
                                         currency: account.currency,
                                         occurredAt: transaction.occurredAt,
                                         createdAt: transaction.createdAt,
                                         accountName: account.name,
                                         accountId: account.remoteId,
                                         entryNature: .transaction(transaction.kind),
                                         transferDescription: nil)
    }

    private func mapTransfer(_ transfer: AccountTransfer) -> PersonalRecordRowViewData? {
        guard let fromAccount = store.account(with: transfer.fromAccountId),
              let toAccount = store.account(with: transfer.toAccountId) else {
            return nil
        }
        let direction = String(format: L.personalTransferDirection.localized, fromAccount.name, toAccount.name)
        return PersonalRecordRowViewData(id: transfer.remoteId,
                                         categoryKey: "transfer",
                                         categoryName: L.personalTransferTitle.localized,
                                         systemImage: "arrow.left.arrow.right",
                                         note: transfer.note,
                                         amountMinorUnits: -transfer.amountFromMinorUnits,
                                         currency: fromAccount.currency,
                                         occurredAt: transfer.occurredAt,
                                         createdAt: transfer.createdAt,
                                         accountName: fromAccount.name,
                                         accountId: fromAccount.remoteId,
                                         entryNature: .transfer,
                                         transferDescription: direction)
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
    @Published var selectedCurrency: CurrencyCode { didSet { Task { await refresh() } } }
    @Published private(set) var timeline: [PersonalStatsSeriesPoint] = []
    @Published private(set) var expenseBreakdown: [PersonalStatsCategoryShare] = []
    @Published private(set) var incomeBreakdown: [PersonalStatsCategoryShare] = []
    @Published private(set) var expenseGrowth: PersonalStatsGrowthMetrics?
    @Published private(set) var incomeGrowth: PersonalStatsGrowthMetrics?
    // Deprecated: kept for compatibility
    @Published private(set) var expenseGrowthRate: Double?
    @Published private(set) var incomeGrowthRate: Double?
    @Published private(set) var availableCurrencies: [CurrencyCode] = []
    @Published var lastError: String?

    private let store: PersonalLedgerStore

    init(store: PersonalLedgerStore) {
        self.store = store
        self.selectedCurrency = store.safePrimaryDisplayCurrency()
        Task { await refresh() }
    }

    func makeCategoryRecordsViewModel(for categoryKey: String, focus: PersonalStatsCategoryFocus) -> PersonalStatsCategoryRecordsViewModel {
        PersonalStatsCategoryRecordsViewModel(store: store,
                                              categoryKey: categoryKey,
                                              categoryName: categoryName(for: categoryKey),
                                              focus: focus,
                                              period: period,
                                              anchorDate: anchorDate,
                                              includeFees: includeFees,
                                              selectedAccountIds: selectedAccountIds,
                                              selectedCurrency: selectedCurrency)
    }

    func refresh() async {
        do {
            let range = Self.dateRange(for: period, anchorDate: anchorDate)
            // refresh available currencies from active accounts
            let currencies = Array(Set(store.activeAccounts.map { $0.currency })).sorted { $0.rawValue < $1.rawValue }
            availableCurrencies = currencies.isEmpty ? [store.safePrimaryDisplayCurrency()] : currencies
            if !availableCurrencies.contains(selectedCurrency) {
                selectedCurrency = availableCurrencies.first ?? store.safePrimaryDisplayCurrency()
            }

            // Build timeline and breakdown for the selected currency only (no cross-currency conversion)
            let calendar = Calendar.current
            var filter = PersonalRecordFilter(dateRange: range,
                                             kinds: includeFees ? [.income, .expense, .fee] : [.income, .expense],
                                             accountIds: selectedAccountIds.isEmpty ? nil : selectedAccountIds,
                                             categoryKeys: nil,
                                             minimumAmountMinor: nil,
                                             maximumAmountMinor: nil,
                                             keyword: nil)
            let all = try store.records(filter: filter)
            // Filter by account currency
            let txns = all.filter { tx in
                guard let account = store.account(with: tx.accountId) else { return false }
                return account.currency == selectedCurrency
            }
            // timeline
            var daily: [Date: (income: Int, expense: Int)] = [:]
            for t in txns {
                let day = calendar.startOfDay(for: t.occurredAt)
                var bucket = daily[day] ?? (0, 0)
                switch t.kind {
                case .income:
                    bucket.income += t.amountMinorUnits
                case .expense:
                    bucket.expense += t.amountMinorUnits
                case .fee:
                    if includeFees { bucket.expense += t.amountMinorUnits }
                }
                daily[day] = bucket
            }
            let sortedDates = daily.keys.sorted()
            timeline = sortedDates.map { d in
                let e = daily[d] ?? (0, 0)
                return PersonalStatsSeriesPoint(date: d, incomeMinorUnits: e.income, expenseMinorUnits: e.expense)
            }
            // breakdown for expenses/incomes (respecting currency separation)
            var expenseTotals: [String: Int] = [:]
            var expenseCounts: [String: Int] = [:]
            var incomeTotals: [String: Int] = [:]
            var incomeCounts: [String: Int] = [:]
            for t in txns {
                switch t.kind {
                case .income:
                    incomeTotals[t.categoryKey, default: 0] += t.amountMinorUnits
                    incomeCounts[t.categoryKey, default: 0] += 1
                case .expense:
                    expenseTotals[t.categoryKey, default: 0] += t.amountMinorUnits
                    expenseCounts[t.categoryKey, default: 0] += 1
                case .fee:
                    guard includeFees else { continue }
                    expenseTotals[t.categoryKey, default: 0] += t.amountMinorUnits
                    expenseCounts[t.categoryKey, default: 0] += 1
                }
            }
            expenseBreakdown = expenseTotals.map {
                PersonalStatsCategoryShare(categoryKey: $0.key,
                                           amountMinorUnits: $0.value,
                                           transactionCount: expenseCounts[$0.key] ?? 0)
            }
            .sorted { $0.amountMinorUnits > $1.amountMinorUnits }

            incomeBreakdown = incomeTotals.map {
                PersonalStatsCategoryShare(categoryKey: $0.key,
                                           amountMinorUnits: $0.value,
                                           transactionCount: incomeCounts[$0.key] ?? 0)
            }
            .sorted { $0.amountMinorUnits > $1.amountMinorUnits }

            // Compute expense growth rate (current vs previous period)
            let prevRange = Self.previousRange(for: period, anchorDate: anchorDate)
            // compute previous expense sum for selected currency
            filter = PersonalRecordFilter(dateRange: prevRange,
                                          kinds: includeFees ? [.income, .expense, .fee] : [.income, .expense],
                                          accountIds: selectedAccountIds.isEmpty ? nil : selectedAccountIds,
                                          categoryKeys: nil,
                                          minimumAmountMinor: nil,
                                          maximumAmountMinor: nil,
                                          keyword: nil)
            let prevAll = try store.records(filter: filter)
            let prevTxns = prevAll.filter { tx in
                guard let account = store.account(with: tx.accountId) else { return false }
                return account.currency == selectedCurrency
            }
            let currentExpense = timeline.reduce(0) { $0 + $1.expenseMinorUnits }
            let prevExpense = prevTxns.reduce(0) { partial, t in
                switch t.kind {
                case .income: return partial
                case .expense: return partial + t.amountMinorUnits
                case .fee: return includeFees ? partial + t.amountMinorUnits : partial
                }
            }
            let currentIncome = timeline.reduce(0) { $0 + $1.incomeMinorUnits }
            let prevIncome = prevTxns.reduce(0) { partial, t in
                switch t.kind {
                case .income: return partial + t.amountMinorUnits
                case .expense: return partial
                case .fee: return partial
                }
            }

            expenseGrowth = Self.growthMetrics(current: currentExpense, previous: prevExpense)
            incomeGrowth = Self.growthMetrics(current: currentIncome, previous: prevIncome)
            expenseGrowthRate = expenseGrowth?.rate
            incomeGrowthRate = incomeGrowth?.rate
        } catch {
            lastError = error.localizedDescription
        }
    }

    static func dateRange(for period: Period, anchorDate: Date) -> ClosedRange<Date> {
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

    static func previousRange(for period: Period, anchorDate: Date) -> ClosedRange<Date> {
        let current = dateRange(for: period, anchorDate: anchorDate)
        let cal = Calendar.current
        switch period {
        case .month:
            let start = cal.date(byAdding: .month, value: -1, to: current.lowerBound) ?? current.lowerBound
            let end = cal.date(byAdding: .month, value: -1, to: current.upperBound) ?? current.upperBound
            return start...end
        case .quarter:
            let start = cal.date(byAdding: .month, value: -3, to: current.lowerBound) ?? current.lowerBound
            let end = cal.date(byAdding: .month, value: -3, to: current.upperBound) ?? current.upperBound
            return start...end
        case .year:
            let start = cal.date(byAdding: .year, value: -1, to: current.lowerBound) ?? current.lowerBound
            let end = cal.date(byAdding: .year, value: -1, to: current.upperBound) ?? current.upperBound
            return start...end
        }
    }

    private static func growthMetrics(current: Int, previous: Int) -> PersonalStatsGrowthMetrics? {
        guard previous != 0 else { return nil }
        let delta = current - previous
        let rate = Double(delta) / Double(previous)
        return PersonalStatsGrowthMetrics(current: current, previous: previous, delta: delta, rate: rate)
    }

    func categoryName(for key: String) -> String {
        store.categoryName(for: key)
    }

    func categoryColor(for key: String) -> Color {
        store.categoryColor(for: key)
    }

    func categoryIcon(for key: String) -> String {
        store.categoryIcon(for: key)
    }
}

@MainActor
final class PersonalStatsCategoryRecordsViewModel: ObservableObject {
    @Published private(set) var records: [PersonalRecordRowViewData] = []
    @Published var lastError: String?

    let categoryKey: String
    let categoryName: String
    let period: PersonalStatsViewModel.Period
    let anchorDate: Date
    let focus: PersonalStatsCategoryFocus
    let includeFees: Bool
    let selectedAccountIds: Set<UUID>
    let selectedCurrency: CurrencyCode

    private let store: PersonalLedgerStore

    init(store: PersonalLedgerStore,
         categoryKey: String,
         categoryName: String,
         focus: PersonalStatsCategoryFocus,
         period: PersonalStatsViewModel.Period,
         anchorDate: Date,
         includeFees: Bool,
         selectedAccountIds: Set<UUID>,
         selectedCurrency: CurrencyCode) {
        self.store = store
        self.categoryKey = categoryKey
        self.categoryName = categoryName
        self.focus = focus
        self.period = period
        self.anchorDate = anchorDate
        self.includeFees = includeFees
        self.selectedAccountIds = selectedAccountIds
        self.selectedCurrency = selectedCurrency
    }

    func refresh() async {
        do {
            let range = PersonalStatsViewModel.dateRange(for: period, anchorDate: anchorDate)
            var kinds: Set<PersonalTransactionKind> = []
            switch focus {
            case .expense:
                kinds.insert(.expense)
                if includeFees { kinds.insert(.fee) }
            case .income:
                kinds.insert(.income)
            }
            let filter = PersonalRecordFilter(dateRange: range,
                                              kinds: kinds,
                                              accountIds: selectedAccountIds.isEmpty ? nil : selectedAccountIds,
                                              categoryKeys: Set([categoryKey]),
                                              minimumAmountMinor: nil,
                                              maximumAmountMinor: nil,
                                              keyword: nil)
            let txns = try store.records(filter: filter)
            let filtered = txns.filter { tx in
                guard let account = store.account(with: tx.accountId) else { return false }
                return account.currency == selectedCurrency
            }
            records = filtered
                .compactMap { mapTransaction($0) }
                .sorted { lhs, rhs in
                    if lhs.occurredAt == rhs.occurredAt { return lhs.createdAt > rhs.createdAt }
                    return lhs.occurredAt > rhs.occurredAt
                }
        } catch {
            lastError = error.localizedDescription
            records = []
        }
    }

    private func mapTransaction(_ transaction: PersonalTransaction) -> PersonalRecordRowViewData? {
        guard let account = store.account(with: transaction.accountId) else {
            return nil
        }
        let category = store.categoryOption(for: transaction.categoryKey)
        return PersonalRecordRowViewData(id: transaction.remoteId,
                                         categoryKey: transaction.categoryKey,
                                         categoryName: category?.localizedName ?? store.categoryName(for: transaction.categoryKey),
                                         categoryColorHex: store.categoryColor(for: transaction.categoryKey).toHexRGB(),
                                         systemImage: category?.systemImage ?? store.categoryIcon(for: transaction.categoryKey),
                                         note: transaction.note,
                                         amountMinorUnits: transaction.amountMinorUnits,
                                         currency: account.currency,
                                         occurredAt: transaction.occurredAt,
                                         createdAt: transaction.createdAt,
                                         accountName: account.name,
                                         accountId: account.remoteId,
                                         entryNature: .transaction(transaction.kind),
                                         transferDescription: nil)
    }
}

@MainActor
final class PersonalLedgerSettingsViewModel: ObservableObject {
    @Published var primaryCurrency: CurrencyCode
    @Published var defaultFXPrecision: Int
    @Published var defaultFXRateText: String
    @Published var defaultFeeText: String
    @Published var countFeeInStats: Bool
    @Published var feeCategoryKey: String
    @Published var fxRates: [CurrencyCode: String]
    @Published var lastError: String?

    private let store: PersonalLedgerStore

    init(store: PersonalLedgerStore) {
        self.store = store
        let prefs = store.getPreferences()
        primaryCurrency = prefs.primaryDisplayCurrency
        defaultFXPrecision = prefs.defaultFXPrecision
        defaultFXRateText = ""
        defaultFeeText = ""
        countFeeInStats = prefs.countFeeInStats
        feeCategoryKey = prefs.defaultFeeCategoryKey ?? "fees"
        fxRates = [:]
        applyPreferences(prefs)
    }

    func save() async {
        do {
            let trimmedRate = defaultFXRateText.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedFee = defaultFeeText.trimmingCharacters(in: .whitespacesAndNewlines)
            let defaultRate = NumberParsing.parseDecimal(trimmedRate)
            var normalizedDefaultFee = NumberParsing.parseDecimal(trimmedFee) ?? 0
            if normalizedDefaultFee < 0 {
                normalizedDefaultFee = 0
            }
            var parsedRates: [CurrencyCode: Decimal] = [:]
            for (code, text) in fxRates {
                if let value = NumberParsing.parseDecimal(text), value > 0 {
                    parsedRates[code] = value
                }
            }
            try store.updatePreferences { prefs in
                prefs.primaryDisplayCurrency = primaryCurrency
                prefs.fxSource = .manual
                prefs.defaultFXPrecision = defaultFXPrecision
                prefs.countFeeInStats = countFeeInStats
                prefs.defaultFeeCategoryKey = feeCategoryKey
                prefs.defaultFXRate = defaultRate
                prefs.defaultConversionFee = normalizedDefaultFee
                prefs.fxRates = parsedRates
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func reloadFromStore() {
        applyPreferences(store.getPreferences())
    }

    private func applyPreferences(_ prefs: PersonalPreferences) {
        primaryCurrency = prefs.primaryDisplayCurrency
        defaultFXPrecision = prefs.defaultFXPrecision
        if let rate = prefs.defaultFXRate {
            defaultFXRateText = NSDecimalNumber(decimal: rate).stringValue
        } else {
            defaultFXRateText = ""
        }
        if let defaultFee = prefs.defaultConversionFee, defaultFee != 0 {
            defaultFeeText = NSDecimalNumber(decimal: defaultFee).stringValue
        } else {
            defaultFeeText = ""
        }
        countFeeInStats = prefs.countFeeInStats
        feeCategoryKey = prefs.defaultFeeCategoryKey ?? "fees"
        fxRates = Dictionary(uniqueKeysWithValues: prefs.fxRates.map { ($0.key, NSDecimalNumber(decimal: $0.value).stringValue) })
        if prefs.fxSource != .manual {
            do {
                try store.updatePreferences { preferences in
                    preferences.fxSource = .manual
                }
            } catch {
                lastError = error.localizedDescription
            }
        }
    }
}

struct PersonalCategoryRowViewData: Identifiable {
    var id: UUID
    var key: String
    var name: String
    var kind: PersonalTransactionKind
    var systemImage: String
    var colorHex: String
    var mappedSystemCategory: ExpenseCategory?

    var color: Color {
        Color(hex: colorHex) ?? Color.appBrand
    }
}

struct PersonalCategoryDraft: Identifiable {
    var id: UUID? = nil
    var name: String = ""
    var kind: PersonalTransactionKind = .expense
    var systemImage: String = "tag"
    var color: Color = Color.appBrand
    var mappedSystemCategory: ExpenseCategory? = nil
}

@MainActor
final class PersonalCategorySettingsViewModel: ObservableObject {
    @Published private(set) var customCategories: [PersonalCategoryRowViewData] = []
    @Published var lastError: String?

    var systemExpenseOptions: [PersonalCategoryOption] { systemExpenseCategories }
    var systemIncomeOptions: [PersonalCategoryOption] { systemIncomeCategories }
    var systemFeeOptions: [PersonalCategoryOption] { feeCategories }

    private let store: PersonalLedgerStore
    private var cancellables: Set<AnyCancellable> = []

    init(store: PersonalLedgerStore) {
        self.store = store
        rebuild()
        store.$customCategories
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuild() }
            .store(in: &cancellables)
    }

    func rebuild() {
        customCategories = store.customCategories.map { category in
            PersonalCategoryRowViewData(id: category.remoteId,
                                        key: category.key,
                                        name: category.name,
                                        kind: category.kind,
                                        systemImage: category.systemImage,
                                        colorHex: category.colorHex,
                                        mappedSystemCategory: category.mappedSystemCategory)
        }
    }

    func systemColor(for key: String, fallback: Color) -> Color {
        store.systemCategoryColorHex(for: key).flatMap(Color.init(hex:)) ?? fallback
    }

    func isHiddenSystemCategory(_ key: String) -> Bool {
        store.systemCategoryHidden(key)
    }

    func updateSystemCategoryColor(_ color: Color, key: String) {
        do {
            try store.setSystemCategoryColor(color, for: key)
            objectWillChange.send()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func updateSystemCategoryHidden(_ hidden: Bool, key: String) {
        do {
            try store.setSystemCategoryHidden(hidden, for: key)
            objectWillChange.send()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func makeDraft(for id: UUID? = nil) -> PersonalCategoryDraft {
        guard let id, let existing = store.customCategories.first(where: { $0.remoteId == id }) else {
            return PersonalCategoryDraft()
        }
        return PersonalCategoryDraft(id: existing.remoteId,
                                     name: existing.name,
                                     kind: existing.kind,
                                     systemImage: existing.systemImage,
                                     color: Color(hex: existing.colorHex) ?? Color.appBrand,
                                     mappedSystemCategory: existing.mappedSystemCategory)
    }

    func save(draft: PersonalCategoryDraft) -> Bool {
        do {
            let input = PersonalCategoryInput(id: draft.id,
                                              name: draft.name,
                                              kind: draft.kind,
                                              systemImage: draft.systemImage,
                                              color: draft.color,
                                              mappedSystemCategory: draft.kind == .expense ? draft.mappedSystemCategory : nil,
                                              sortIndex: nil)
            _ = try store.saveCategory(input)
            rebuild()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func transactionCount(for id: UUID) -> Int {
        return (try? store.transactionCount(forCategoryId: id)) ?? 0
    }

    func categoryOptions(for kind: PersonalTransactionKind) -> [PersonalCategoryOption] {
        store.categoryOptions(for: kind)
    }

    func delete(id: UUID, reassignTo newKey: String? = nil) {
        do {
            if let newKey = newKey {
                try store.reassignTransactions(fromCategoryId: id, toCategoryKey: newKey)
            }
            try store.deleteCategory(id: id)
            rebuild()
        } catch {
            lastError = error.localizedDescription
        }
    }
}
