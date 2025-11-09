//
//  PersonalLedgerStoreTests.swift
//  KuaiJiTests
//
//  Unit tests for personal ledger storage behaviours (transactions, transfers, stats).
//

import Foundation
import SwiftData
import Testing
@testable import KuaiJi

@Suite("Personal Ledger Store")
struct PersonalLedgerStoreTests {
    private func makeStore() throws -> PersonalLedgerStore {
        let schema = Schema([
            PersonalAccount.self,
            PersonalTransaction.self,
            AccountTransfer.self,
            PersonalPreferences.self,
            PersonalCategory.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return try PersonalLedgerStore(context: container.mainContext, defaultCurrency: .cny)
    }

    @Test("Income and expense adjust balances and monthly totals")
    func incomeExpenseFlow() throws {
        let store = try makeStore()
        let account = try store.createAccount(from: PersonalAccountDraft(name: "Wallet", type: .cash, initialBalance: 0))
        let now = Date()

        try store.saveTransaction(PersonalTransactionInput(kind: .expense,
                                                            accountId: account.remoteId,
                                                            categoryKey: "food",
                                                            amount: Decimal(string: "120.50")!,
                                                            occurredAt: now,
                                                            note: "Dinner"))
        try store.saveTransaction(PersonalTransactionInput(kind: .income,
                                                            accountId: account.remoteId,
                                                            categoryKey: "salary",
                                                            amount: Decimal(string: "300.00")!,
                                                            occurredAt: now,
                                                            note: "Bonus"))

        try store.refreshAccounts()
        #expect(store.activeAccounts.count == 1)
        let updated = try #require(store.activeAccounts.first)
        #expect(updated.balanceMinorUnits == 17_950) // -120.50 + 300.00

        let totals = try store.monthlyTotals(for: now, includeFees: true)
        #expect(totals.expense == 12_050)
        #expect(totals.income == 30_000)
    }

    @Test("Locale-aware parsing accepts comma decimals for amounts and rates")
    func localeAwareParsing() throws {
        let store = try makeStore()
        let account = try store.createAccount(from: PersonalAccountDraft(name: "Wallet", type: .cash, initialBalance: 0))
        let now = Date()

        // Comma decimal for expense amount (e.g., French format)
        let commaAmount = NumberParsing.parseDecimal("120,50", locale: Locale(identifier: "fr_FR"))
        #expect(commaAmount == Decimal(string: "120.50"))
        try store.saveTransaction(PersonalTransactionInput(kind: .expense,
                                                            accountId: account.remoteId,
                                                            categoryKey: "food",
                                                            amount: commaAmount!,
                                                            occurredAt: now))

        // Comma decimal for transfer fx rate and fee
        let from = try store.createAccount(from: PersonalAccountDraft(name: "Bank", type: .bankCard, initialBalance: 0))
        let to = try store.createAccount(from: PersonalAccountDraft(name: "Savings", type: .bankCard, initialBalance: 0))
        let fx = NumberParsing.parseDecimal("1,2", locale: Locale(identifier: "fr_FR"))
        let fee = NumberParsing.parseDecimal("5,00", locale: Locale(identifier: "fr_FR"))
        #expect(fx == Decimal(string: "1.2"))
        #expect(fee == Decimal(string: "5"))
        _ = try store.saveTransfer(PersonalTransferInput(fromAccountId: from.remoteId,
                                                        toAccountId: to.remoteId,
                                                        amountFrom: Decimal(string: "10")!,
                                                        fxRate: fx!,
                                                        occurredAt: now,
                                                        feeAmount: fee,
                                                        feeCurrency: from.currency,
                                                        feeSide: .from))
    }

    @Test("Transfers adjust balances and produce fee records")
    func transferWithFee() throws {
        let store = try makeStore()
        let from = try store.createAccount(from: PersonalAccountDraft(name: "Bank", type: .bankCard, initialBalance: Decimal(string: "1000")!))
        let to = try store.createAccount(from: PersonalAccountDraft(name: "Savings", type: .bankCard, initialBalance: 0))

        let transfer = try store.saveTransfer(PersonalTransferInput(fromAccountId: from.remoteId,
                                                                   toAccountId: to.remoteId,
                                                                   amountFrom: Decimal(string: "200")!,
                                                                   fxRate: Decimal(string: "1.2")!,
                                                                   occurredAt: Date(),
                                                                   note: "Move to savings",
                                                                   feeAmount: Decimal(string: "5")!,
                                                                   feeCurrency: from.currency,
                                                                   feeSide: .from))

        try store.refreshAccounts()
        let refreshedFrom = try #require(store.activeAccounts.first(where: { $0.remoteId == from.remoteId }))
        let refreshedTo = try #require(store.activeAccounts.first(where: { $0.remoteId == to.remoteId }))
        #expect(refreshedFrom.balanceMinorUnits == SettlementMath.minorUnits(from: Decimal(string: "795")!, scale: 2))
        #expect(refreshedTo.balanceMinorUnits == SettlementMath.minorUnits(from: Decimal(string: "240")!, scale: 2))

        #expect(transfer.feeMinorUnits == 500)
        #expect(transfer.feeTransactionId != nil)

        let feeRecords = try store.records(filter: PersonalRecordFilter(kinds: [.fee]))
        #expect(feeRecords.count == 1)
        let fee = try #require(feeRecords.first)
        #expect(fee.amountMinorUnits == 500)
        #expect(fee.accountId == from.remoteId)

        try store.deleteTransfer(id: transfer.remoteId)
        try store.refreshAccounts()
        let restoredFrom = try #require(store.activeAccounts.first(where: { $0.remoteId == from.remoteId }))
        let restoredTo = try #require(store.activeAccounts.first(where: { $0.remoteId == to.remoteId }))
        #expect(restoredFrom.balanceMinorUnits == SettlementMath.minorUnits(from: Decimal(string: "1000")!, scale: 2))
        #expect(restoredTo.balanceMinorUnits == 0)
        let remainingFees = try store.records(filter: PersonalRecordFilter(kinds: [.fee]))
        #expect(remainingFees.isEmpty)
    }

    @Test("Category breakdown excludes transfers but supports fees when requested")
    func categoryBreakdown() throws {
        let store = try makeStore()
        let cash = try store.createAccount(from: PersonalAccountDraft(name: "Cash", type: .cash, initialBalance: 0))
        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now

        try store.saveTransaction(PersonalTransactionInput(kind: .expense,
                                                            accountId: cash.remoteId,
                                                            categoryKey: "food",
                                                            amount: Decimal(string: "80")!,
                                                            occurredAt: yesterday))
        try store.saveTransaction(PersonalTransactionInput(kind: .expense,
                                                            accountId: cash.remoteId,
                                                            categoryKey: "travel",
                                                            amount: Decimal(string: "20")!,
                                                            occurredAt: now))
        try store.saveTransaction(PersonalTransactionInput(kind: .fee,
                                                            accountId: cash.remoteId,
                                                            categoryKey: "fees",
                                                            amount: Decimal(string: "5")!,
                                                            occurredAt: now))
        try store.saveTransaction(PersonalTransactionInput(kind: .income,
                                                            accountId: cash.remoteId,
                                                            categoryKey: "salary",
                                                            amount: Decimal(string: "200")!,
                                                            occurredAt: now))

        let range = (Calendar.current.date(byAdding: .day, value: -2, to: now) ?? now)...Calendar.current.date(byAdding: .day, value: 1, to: now)!
        let withoutFee = try store.categoryBreakdown(for: range, includeFees: false, accountIds: nil)
        #expect(withoutFee["food"] == 8_000)
        #expect(withoutFee["travel"] == 2_000)
        #expect(withoutFee["fees"] == nil)

        let withFee = try store.categoryBreakdown(for: range, includeFees: true, accountIds: nil)
        #expect(withFee["fees"] == 500)
        #expect(withFee["food"] == 8_000)
    }
    @Test("Totals use FX conversion when currencies differ")
    func multiCurrencyTotals() throws {
        let store = try makeStore()
        try store.updatePreferences { prefs in
            prefs.primaryDisplayCurrency = .cny
            prefs.fxRates[.usd] = Decimal(string: "7.3")!
        }
        let usdAccount = try store.createAccount(from: PersonalAccountDraft(name: "USD Card", type: .creditCard, currency: .usd, initialBalance: 0))
        let now = Date()
        try store.saveTransaction(PersonalTransactionInput(kind: .expense,
                                                            accountId: usdAccount.remoteId,
                                                            categoryKey: "shopping",
                                                            amount: Decimal(string: "10")!,
                                                            occurredAt: now))
        let totals = try store.monthlyTotals(for: now, includeFees: true)
        #expect(totals.expense == 7_300)
    }

}
