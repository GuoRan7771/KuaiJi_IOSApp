//
//  PersonalCSVExportViewModel.swift
//  KuaiJi
//

import Combine
import Foundation
import SwiftData
import SwiftUI

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
