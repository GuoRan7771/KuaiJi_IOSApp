//
//  PersonalLedgerHomeViewModel.swift
//  KuaiJi
//

import Combine
import Foundation
import SwiftData
import SwiftUI

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
