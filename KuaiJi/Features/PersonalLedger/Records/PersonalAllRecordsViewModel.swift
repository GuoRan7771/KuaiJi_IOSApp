//
//  PersonalAllRecordsViewModel.swift
//  KuaiJi
//

import Combine
import Foundation
import SwiftData
import SwiftUI

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
