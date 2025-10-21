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

struct PersonalMonthlyTotals: Equatable {
    var expenseMinorUnits: Int
    var incomeMinorUnits: Int
}

struct PersonalRecordRowViewData: Identifiable, Hashable {
    enum EntryNature: Hashable {
        case transaction(PersonalTransactionKind)
        case transfer
    }

    var id: UUID
    var categoryKey: String
    var categoryName: String
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

// MARK: - Stats Enhancements (Structure, Growth, Insights)

struct PersonalSpendingStructure {
    let essentialMinorUnits: Int
    let discretionaryMinorUnits: Int
    var total: Int { essentialMinorUnits + discretionaryMinorUnits }
    var essentialShare: Double { total > 0 ? Double(essentialMinorUnits) / Double(total) : 0 }
    var discretionaryShare: Double { total > 0 ? Double(discretionaryMinorUnits) / Double(total) : 0 }
}

struct CategoryTrendInsight: Identifiable, Hashable {
    let id: UUID = UUID()
    let categoryKey: String
    let increasingStreak: Int
    let recentGrowthRate: Double
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
                PersonalAccount.self,
                PersonalTransaction.self,
                AccountTransfer.self,
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
        let category = (expenseCategories + incomeCategories + feeCategories).first(where: { $0.key == transaction.categoryKey })
        return PersonalRecordRowViewData(id: transaction.remoteId,
                                         categoryKey: transaction.categoryKey,
                                         categoryName: category?.localizedName ?? transaction.categoryKey.capitalized,
                                         systemImage: category?.systemImage ?? iconForCategory(key: transaction.categoryKey),
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
    @Published private(set) var totalsByMonth: [PersonalYearMonth: PersonalMonthlyTotals] = [:]

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
        totalsByMonth = [:]
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

    func totals(for month: PersonalYearMonth) async throws -> (expense: Int, income: Int) {
        if let cached = totalsByMonth[month] {
            return (cached.expenseMinorUnits, cached.incomeMinorUnits)
        }
        let result = try store.monthlyTotals(for: month.date, includeFees: store.safeCountFeeInStats())
        totalsByMonth[month] = PersonalMonthlyTotals(expenseMinorUnits: result.expense, incomeMinorUnits: result.income)
        return result
    }

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
        let category = (expenseCategories + incomeCategories + feeCategories).first(where: { $0.key == transaction.categoryKey })
        return PersonalRecordRowViewData(id: transaction.remoteId,
                                         categoryKey: transaction.categoryKey,
                                         categoryName: category?.localizedName ?? transaction.categoryKey.capitalized,
                                         systemImage: category?.systemImage ?? iconForCategory(key: transaction.categoryKey),
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
            updateDefaultCategory()
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
            updateDefaultCategory()
            self.amountText = ""
            self.note = ""
            self.occurredAt = Date()
        }
        userSetCustomCurrency = currentAccount()?.currency != amountCurrency
        updateFXState()
    }

    var categoryOptions: [PersonalCategoryOption] {
        PersonalCategoryOption.defaultCategories(for: kind)
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

    private static func decimalString(from minorUnits: Int) -> String {
        let decimal = SettlementMath.decimal(fromMinorUnits: minorUnits, scale: 2)
        return NSDecimalNumber(decimal: decimal).stringValue
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
        let category = (expenseCategories + incomeCategories + feeCategories).first(where: { $0.key == transaction.categoryKey })
        return PersonalRecordRowViewData(id: transaction.remoteId,
                                         categoryKey: transaction.categoryKey,
                                         categoryName: category?.localizedName ?? transaction.categoryKey.capitalized,
                                         systemImage: category?.systemImage ?? iconForCategory(key: transaction.categoryKey),
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
    @Published private(set) var structure: PersonalSpendingStructure?
    @Published private(set) var expenseGrowthRate: Double?
    @Published private(set) var insights: [CategoryTrendInsight] = []
    @Published private(set) var availableCurrencies: [CurrencyCode] = []
    @Published var lastError: String?

    private let store: PersonalLedgerStore

    init(store: PersonalLedgerStore) {
        self.store = store
        self.selectedCurrency = store.safePrimaryDisplayCurrency()
        Task { await refresh() }
    }

    func refresh() async {
        do {
            let range = dateRange()
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

            // Compute spending structure (essential vs discretionary)
            let essentialKeys: Set<String> = [
                "food", "transport", "accommodation", "utilities",
                // legacy compatibility keys
                "housing", "health", "education"
            ]
            var essentialTotal = 0
            var discretionaryTotal = 0
            for item in expenseBreakdown {
                if essentialKeys.contains(item.categoryKey) {
                    essentialTotal += item.amountMinorUnits
                } else {
                    discretionaryTotal += item.amountMinorUnits
                }
            }
            structure = PersonalSpendingStructure(essentialMinorUnits: essentialTotal,
                                                  discretionaryMinorUnits: discretionaryTotal)

            // Compute expense growth rate (current vs previous period)
            func previousRange(from r: ClosedRange<Date>, period: Period) -> ClosedRange<Date> {
                let cal = Calendar.current
                switch period {
                case .month:
                    let start = cal.date(byAdding: .month, value: -1, to: r.lowerBound) ?? r.lowerBound
                    let end = cal.date(byAdding: .month, value: -1, to: r.upperBound) ?? r.upperBound
                    return start...end
                case .quarter:
                    let start = cal.date(byAdding: .month, value: -3, to: r.lowerBound) ?? r.lowerBound
                    let end = cal.date(byAdding: .month, value: -3, to: r.upperBound) ?? r.upperBound
                    return start...end
                case .year:
                    let start = cal.date(byAdding: .year, value: -1, to: r.lowerBound) ?? r.lowerBound
                    let end = cal.date(byAdding: .year, value: -1, to: r.upperBound) ?? r.upperBound
                    return start...end
                }
            }
            let prevRange = previousRange(from: range, period: period)
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
            expenseGrowthRate = prevExpense > 0 ? Double(currentExpense - prevExpense) / Double(prevExpense) : nil

            // Build category trend insights over recent periods
            func lastNRanges(_ n: Int, endingWith r: ClosedRange<Date>, period: Period) -> [ClosedRange<Date>] {
                var result: [ClosedRange<Date>] = [r]
                for _ in 1..<n {
                    result.append(previousRange(from: result.last!, period: period))
                }
                return result.reversed()
            }
            let ranges = lastNRanges(6, endingWith: range, period: period)
            // key -> series of shares across periods
            var seriesPerCategory: [String: [Double]] = [:]
            for r in ranges {
                let filter = PersonalRecordFilter(dateRange: r,
                                             kinds: includeFees ? [.income, .expense, .fee] : [.income, .expense],
                                             accountIds: selectedAccountIds.isEmpty ? nil : selectedAccountIds,
                                             categoryKeys: nil,
                                             minimumAmountMinor: nil,
                                             maximumAmountMinor: nil,
                                             keyword: nil)
                let allR = try store.records(filter: filter)
                let txR = allR.filter { tx in
                    guard let account = store.account(with: tx.accountId) else { return false }
                    return account.currency == selectedCurrency
                }
                var map: [String: Int] = [:]
                for t in txR {
                    switch t.kind {
                    case .income:
                        continue
                    case .expense:
                        map[t.categoryKey, default: 0] += t.amountMinorUnits
                    case .fee:
                        if includeFees { map[t.categoryKey, default: 0] += t.amountMinorUnits }
                    }
                }
                let total = map.values.reduce(0, +)
                // padding zero for existing keys
                for key in seriesPerCategory.keys {
                    seriesPerCategory[key, default: []].append(0)
                }
                if total > 0 {
                    for (key, val) in map {
                        let share = Double(val) / Double(total)
                        if var arr = seriesPerCategory[key] {
                            arr.removeLast()
                            arr.append(share)
                            seriesPerCategory[key] = arr
                        } else {
                            let zeros = Array(repeating: 0.0, count: ranges.count - 1)
                            seriesPerCategory[key] = zeros + [share]
                        }
                    }
                }
            }
            var alerts: [CategoryTrendInsight] = []
            for (key, series) in seriesPerCategory {
                guard series.count >= 3 else { continue }
                let last3 = Array(series.suffix(3))
                // strict increasing with small epsilon
                let eps = 0.0001
                let inc = zip(last3, last3.dropFirst()).allSatisfy { ($1 - $0) > eps }
                let streak = inc ? 3 : 0
                if let last = series.last, let prev = series.dropLast().last, prev > 0 {
                    let grow = (last - prev) / prev
                    if streak >= 3 || grow >= 0.2 {
                        alerts.append(CategoryTrendInsight(categoryKey: key, increasingStreak: streak, recentGrowthRate: grow))
                    }
                }
            }
            insights = alerts.sorted { ($0.increasingStreak, $0.recentGrowthRate) > ($1.increasingStreak, $1.recentGrowthRate) }
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
