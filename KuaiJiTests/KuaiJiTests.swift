//
//  KuaiJiTests.swift
//  KuaiJiTests
//
//  Algorithm and settlement tests covering split strategies and rounding.
//

import Foundation
import Testing
@testable import KuaiJi

@Suite("Settlement & Transfer Algorithms")
struct SettlementAlgorithmTests {
    let ledgerId = UUID()
    let alice = UUID()
    let bob = UUID()
    let chloe = UUID()
    let dylan = UUID()

    let defaultSettings = LedgerSettings(defaultCurrency: .eur,
                                         defaultLocale: "fr_FR",
                                         includePayerInAA: true,
                                         roundingScale: 2,
                                         crossCurrencyRule: .forbid)

    @Test("两人 AA 平均分")
    func twoPersonAA() throws {
        let expense = makeExpense(payer: alice,
                                  amount: Decimal(string: "100")!,
                                  participants: [
                                    ExpenseParticipantShare(userId: alice, shareType: .aa),
                                    ExpenseParticipantShare(userId: bob, shareType: .aa)
                                  ])
        let result = try SettlementCalculator.computeNetBalances(ledgerCurrency: .eur,
                                                                  expenses: [expense],
                                                                  settings: defaultSettings)
        #expect(result[alice] == 5_000)
        #expect(result[bob] == -5_000)
        let plan = TransferPlanner.greedyMinTransfers(from: result)
        #expect(plan.transfers.count == 1)
        #expect(plan.transfers.first?.amountMinorUnits == 5_000)
    }

    @Test("三人其中一人请客")
    func treatScenario() throws {
        let expense = makeExpense(payer: bob,
                                  amount: Decimal(string: "75")!,
                                  participants: [
                                    ExpenseParticipantShare(userId: bob, shareType: .treat),
                                    ExpenseParticipantShare(userId: alice, shareType: .treat),
                                    ExpenseParticipantShare(userId: chloe, shareType: .treat)
                                  ],
                                  split: .payerTreat)
        let result = try SettlementCalculator.computeNetBalances(ledgerCurrency: .eur,
                                                                  expenses: [expense],
                                                                  settings: defaultSettings)
        #expect(result.count == 1)
        #expect(result[bob] == 7_500)
    }

    @Test("四人不同权重")
    func weightedSplit() throws {
        let expense = makeExpense(payer: chloe,
                                  amount: Decimal(string: "180")!,
                                  participants: [
                                    ExpenseParticipantShare(userId: alice, shareType: .weight, shareValue: 2),
                                    ExpenseParticipantShare(userId: bob, shareType: .weight, shareValue: 1),
                                    ExpenseParticipantShare(userId: chloe, shareType: .weight, shareValue: 1),
                                    ExpenseParticipantShare(userId: dylan, shareType: .treat)
                                  ],
                                  split: .weighted)
        let result = try SettlementCalculator.computeNetBalances(ledgerCurrency: .eur,
                                                                  expenses: [expense],
                                                                  settings: defaultSettings)
        #expect(result[alice] == -90_000) // 180 -> weights total 4 => alice owes 90
        #expect(result[bob] == -45_000)
        #expect(result[chloe] == 135_000)
        #expect(result[dylan] == nil)
    }

    @Test("尾差 0.01 分配")
    func roundingTailDistribution() throws {
        let participants = [
            ExpenseParticipantShare(userId: alice, shareType: .aa),
            ExpenseParticipantShare(userId: bob, shareType: .aa),
            ExpenseParticipantShare(userId: chloe, shareType: .aa)
        ]
        let expense = makeExpense(payer: alice,
                                  amount: Decimal(string: "100.01")!,
                                  participants: participants,
                                  metadata: ExpenseMetadata(includePayer: true),
                                  split: .payerAA)
        let result = try SettlementCalculator.computeNetBalances(ledgerCurrency: .eur,
                                                                  expenses: [expense],
                                                                  settings: defaultSettings)
        #expect(result.values.reduce(0, +) == 0)
        let shares = try SettlementCalculator.shareDistribution(for: expense,
                                                                 convertedTotalMinor: 10_001,
                                                                 includePayer: true,
                                                                 converter: CurrencyConverter(ledgerCurrency: .eur,
                                                                                              rule: defaultSettings.crossCurrencyRule,
                                                                                              scale: 2),
                                                                 settings: defaultSettings)
        #expect(shares.values.reduce(0, +) == 10_001)
        #expect(Set(shares.values) == Set([3_334, 3_333]))
    }

    @Test("跨货币被禁用")
    func crossCurrencyForbidden() {
        let usdExpense = ExpenseInput(ledgerId: ledgerId,
                                      payerId: alice,
                                      title: "USD 票据",
                                      note: "",
                                      category: .other,
                                      amountMinorUnits: 10_000,
                                      currency: .usd,
                                      date: .now,
                                      splitStrategy: .payerAA,
                                      metadata: ExpenseMetadata(includePayer: true),
                                      participants: [
                                        ExpenseParticipantShare(userId: alice, shareType: .aa),
                                        ExpenseParticipantShare(userId: bob, shareType: .aa)
                                      ])
        #expect(throws: SettlementError.crossCurrencyDisabled(expenseCurrency: .usd)) {
            _ = try SettlementCalculator.computeNetBalances(ledgerCurrency: .eur,
                                                             expenses: [usdExpense],
                                                             settings: defaultSettings)
        }
    }

    @Test("跨货币固定汇率")
    func crossCurrencyFixedRate() throws {
        var settings = defaultSettings
        settings.crossCurrencyRule = CrossCurrencyRule(mode: .fixedRate, rates: [.usd: Decimal(string: "0.9") ?? 0.9])
        let usdExpense = ExpenseInput(ledgerId: ledgerId,
                                      payerId: alice,
                                      title: "USD 午餐",
                                      note: "",
                                      category: .food,
                                      amountMinorUnits: 11_000,
                                      currency: .usd,
                                      date: .now,
                                      splitStrategy: .payerAA,
                                      metadata: ExpenseMetadata(includePayer: true),
                                      participants: [
                                        ExpenseParticipantShare(userId: alice, shareType: .aa),
                                        ExpenseParticipantShare(userId: bob, shareType: .aa)
                                      ])
        let balances = try SettlementCalculator.computeNetBalances(ledgerCurrency: .eur,
                                                                    expenses: [usdExpense],
                                                                    settings: settings)
        #expect(balances[alice] == 4_950) // 110 USD -> 99 EUR => payer net +49.5 EUR
        #expect(balances[bob] == -4_950)
    }

    // Helper
    private func makeExpense(payer: UUID,
                             amount: Decimal,
                             participants: [ExpenseParticipantShare],
                             metadata: ExpenseMetadata = ExpenseMetadata(includePayer: true),
                             split: SplitStrategy = .payerAA) -> ExpenseInput {
        ExpenseInput(ledgerId: ledgerId,
                     payerId: payer,
                     title: "测试",
                     note: "",
                     category: .other,
                     amountMinorUnits: SettlementMath.minorUnits(from: amount, scale: 2),
                     currency: .eur,
                     date: .now,
                     splitStrategy: split,
                     metadata: metadata,
                     participants: participants)
    }
}

@Suite("Legacy Transformer Compatibility")
struct LegacyStringArrayTransformerTests {
    private let transformer = LegacyStringArrayTransformer()

    @Test("Plist payloads can still be decoded")
    func propertyListDecoding() throws {
        let values = ["housing", "transport"]
        let data = try PropertyListSerialization.data(fromPropertyList: values,
                                                      format: .binary,
                                                      options: 0)
        let decoded = transformer.reverseTransformedValue(data) as? [String]
        #expect(decoded == values)
    }

    @Test("Nested keyed archives that wrap NSData are supported")
    func nestedArchiveDecoding() throws {
        let values = ["groceries", "utilities"]
        let inner = try PropertyListSerialization.data(fromPropertyList: values,
                                                       format: .binary,
                                                       options: 0)
        let archived = try NSKeyedArchiver.archivedData(withRootObject: inner, requiringSecureCoding: true)
        let decoded = transformer.reverseTransformedValue(archived) as? [String]
        #expect(decoded == values)
    }
}
