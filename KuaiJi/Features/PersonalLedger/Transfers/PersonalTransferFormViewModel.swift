//
//  PersonalTransferFormViewModel.swift
//  KuaiJi
//

import Combine
import Foundation
import SwiftData
import SwiftUI

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
