//
//  PersonalAccountViewModels.swift
//  KuaiJi
//

import Combine
import Foundation
import SwiftData
import SwiftUI

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
