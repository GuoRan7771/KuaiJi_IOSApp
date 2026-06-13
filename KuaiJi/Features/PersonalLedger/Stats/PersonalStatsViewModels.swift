//
//  PersonalStatsViewModels.swift
//  KuaiJi
//

import Combine
import Foundation
import SwiftData
import SwiftUI

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
