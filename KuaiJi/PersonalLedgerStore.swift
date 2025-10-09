//
//  PersonalLedgerStore.swift
//  KuaiJi
//
//  Personal ledger domain service coordinating SwiftData operations and aggregates.
//

import Foundation
import Combine
import SwiftData

// MARK: - Errors & Inputs

enum PersonalLedgerError: LocalizedError {
    case accountNotFound
    case transactionNotFound
    case transferNotFound
    case amountMustBePositive
    case categoryRequired
    case accountRequired
    case cannotDeleteNonEmptyAccount
    case duplicateAccountName
    case nameRequired
    case sameTransferAccount
    case invalidExchangeRate
    case invalidFeeSide
    case invalidFeeCurrency

    var errorDescription: String? {
        switch self {
        case .accountNotFound: return "Account not found"
        case .transactionNotFound: return "Transaction not found"
        case .transferNotFound: return "Transfer not found"
        case .amountMustBePositive: return "Amount must be greater than zero"
        case .categoryRequired: return "Category is required"
        case .accountRequired: return "Account selection is required"
        case .cannotDeleteNonEmptyAccount: return "Balance must be zero before deletion"
        case .duplicateAccountName: return "Account name already exists"
        case .nameRequired: return "Account name is required"
        case .sameTransferAccount: return "Source and target accounts must differ"
        case .invalidExchangeRate: return "Exchange rate must be greater than zero"
        case .invalidFeeSide: return "Fee side is required when fee exists"
        case .invalidFeeCurrency: return "Fee currency does not match account"
        }
    }
}

struct PersonalAccountDraft {
    var id: UUID?
    var name: String
    var type: PersonalAccountType
    var currency: CurrencyCode
    var includeInNetWorth: Bool
    var initialBalance: Decimal
    var note: String?
    var status: PersonalAccountStatus

    init(id: UUID? = nil,
         name: String = "",
         type: PersonalAccountType = .bankCard,
         currency: CurrencyCode = .cny,
         includeInNetWorth: Bool = true,
         initialBalance: Decimal = 0,
         note: String? = nil,
         status: PersonalAccountStatus = .active) {
        self.id = id
        self.name = name
        self.type = type
        self.currency = currency
        self.includeInNetWorth = includeInNetWorth
        self.initialBalance = initialBalance
        self.note = note
        self.status = status
    }
}

struct PersonalTransactionInput {
    var id: UUID?
    var kind: PersonalTransactionKind
    var accountId: UUID?
    var categoryKey: String
    var amount: Decimal
    var occurredAt: Date
    var note: String
    var attachmentPath: String?
    var displayCurrency: CurrencyCode?
    var fxRate: Decimal?

    init(id: UUID? = nil,
         kind: PersonalTransactionKind,
         accountId: UUID?,
         categoryKey: String,
         amount: Decimal,
         occurredAt: Date,
         note: String = "",
         attachmentPath: String? = nil,
         displayCurrency: CurrencyCode? = nil,
         fxRate: Decimal? = nil) {
        self.id = id
        self.kind = kind
        self.accountId = accountId
        self.categoryKey = categoryKey
        self.amount = amount
        self.occurredAt = occurredAt
        self.note = note
        self.attachmentPath = attachmentPath
        self.displayCurrency = displayCurrency
        self.fxRate = fxRate
    }
}

struct PersonalTransferInput {
    var id: UUID?
    var fromAccountId: UUID?
    var toAccountId: UUID?
    var amountFrom: Decimal
    var fxRate: Decimal
    var occurredAt: Date
    var note: String
    var feeAmount: Decimal?
    var feeCurrency: CurrencyCode?
    var feeSide: PersonalTransferFeeSide?

    init(id: UUID? = nil,
         fromAccountId: UUID?,
         toAccountId: UUID?,
         amountFrom: Decimal,
         fxRate: Decimal = 1,
         occurredAt: Date,
         note: String = "",
         feeAmount: Decimal? = nil,
         feeCurrency: CurrencyCode? = nil,
         feeSide: PersonalTransferFeeSide? = nil) {
        self.id = id
        self.fromAccountId = fromAccountId
        self.toAccountId = toAccountId
        self.amountFrom = amountFrom
        self.fxRate = fxRate
        self.occurredAt = occurredAt
        self.note = note
        self.feeAmount = feeAmount
        self.feeCurrency = feeCurrency
        self.feeSide = feeSide
    }
}

struct PersonalRecordFilter {
    var dateRange: ClosedRange<Date>?
    var kinds: Set<PersonalTransactionKind>?
    var accountIds: Set<UUID>?
    var categoryKeys: Set<String>?
    var minimumAmountMinor: Int?
    var maximumAmountMinor: Int?
    var keyword: String?

    init(dateRange: ClosedRange<Date>? = nil,
         kinds: Set<PersonalTransactionKind>? = nil,
         accountIds: Set<UUID>? = nil,
         categoryKeys: Set<String>? = nil,
         minimumAmountMinor: Int? = nil,
         maximumAmountMinor: Int? = nil,
         keyword: String? = nil) {
        self.dateRange = dateRange
        self.kinds = kinds
        self.accountIds = accountIds
        self.categoryKeys = categoryKeys
        self.minimumAmountMinor = minimumAmountMinor
        self.maximumAmountMinor = maximumAmountMinor
        self.keyword = keyword
    }
}

struct PersonalStatsRequest {
    enum Period: CaseIterable {
        case month
        case quarter
        case year

        var calendarComponent: Calendar.Component {
            switch self {
            case .month: return .month
            case .quarter: return .month // handled separately
            case .year: return .year
            }
        }
    }

    var startDate: Date
    var endDate: Date
    var includeFee: Bool
    var accountIds: Set<UUID>?
    var currency: CurrencyCode?
}

// MARK: - Store

@MainActor
final class PersonalLedgerStore: ObservableObject {
    private let context: ModelContext
    private let calendar: Calendar

    @Published private(set) var preferences: PersonalPreferences
    @Published private(set) var activeAccounts: [PersonalAccount] = []
    @Published private(set) var archivedAccounts: [PersonalAccount] = []

    init(context: ModelContext, defaultCurrency: CurrencyCode = .cny, calendar: Calendar = .current) throws {
        self.context = context
        self.calendar = calendar
        self.preferences = try PersonalLedgerStore.ensurePreferences(in: context, defaultCurrency: defaultCurrency)
        try refreshAccounts()
    }

    // MARK: - Preferences

    func updatePreferences(_ block: (PersonalPreferences) -> Void) throws {
        block(preferences)
        try context.save()
        objectWillChange.send()
    }

    private static func ensurePreferences(in context: ModelContext, defaultCurrency: CurrencyCode) throws -> PersonalPreferences {
        var descriptor = FetchDescriptor<PersonalPreferences>()
        descriptor.fetchLimit = 1
        if let existing = try context.fetch(descriptor).first {
            return existing
        }

        let prefs = PersonalPreferences(primaryDisplayCurrency: defaultCurrency)
        context.insert(prefs)
        try context.save()
        return prefs
    }

    // MARK: - Accounts

    func refreshAccounts() throws {
        let descriptor = FetchDescriptor<PersonalAccount>(sortBy: [SortDescriptor(\.createdAt, order: .forward)])
        let fetched = try context.fetch(descriptor)
        activeAccounts = fetched.filter { $0.status == .active }
        archivedAccounts = fetched.filter { $0.status == .archived }
    }

    func createAccount(from draft: PersonalAccountDraft) throws -> PersonalAccount {
        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PersonalLedgerError.nameRequired
        }
        if try nameExists(trimmed, excluding: nil) {
            throw PersonalLedgerError.duplicateAccountName
        }
        let balanceMinor = SettlementMath.minorUnits(from: draft.initialBalance, scale: 2)
        let account = PersonalAccount(name: trimmed,
                                      type: draft.type,
                                      currency: draft.currency,
                                      includeInNetWorth: draft.includeInNetWorth,
                                      balanceMinorUnits: balanceMinor,
                                      note: draft.note,
                                      status: draft.status)
        context.insert(account)
        try context.save()
        try refreshAccounts()
        return account
    }

    func updateAccount(from draft: PersonalAccountDraft) throws {
        guard let id = draft.id else { return }
        guard let account = try findAccount(by: id) else { throw PersonalLedgerError.accountNotFound }
        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            throw PersonalLedgerError.nameRequired
        }
        if try nameExists(trimmed, excluding: account.remoteId) {
            throw PersonalLedgerError.duplicateAccountName
        }
        account.name = trimmed
        account.type = draft.type
        account.currency = draft.currency
        account.includeInNetWorth = draft.includeInNetWorth
        account.note = draft.note
        account.status = draft.status
        account.updatedAt = Date.now
        if draft.initialBalance != SettlementMath.decimal(fromMinorUnits: account.balanceMinorUnits, scale: 2) {
            account.balanceMinorUnits = SettlementMath.minorUnits(from: draft.initialBalance, scale: 2)
        }
        try context.save()
        try refreshAccounts()
    }

    func archiveAccount(id: UUID) throws {
        guard let account = try findAccount(by: id) else { throw PersonalLedgerError.accountNotFound }
        account.status = .archived
        account.updatedAt = Date.now
        try context.save()
        try refreshAccounts()
    }

    func activateAccount(id: UUID) throws {
        guard let account = try findAccount(by: id) else { throw PersonalLedgerError.accountNotFound }
        account.status = .active
        account.updatedAt = Date.now
        try context.save()
        try refreshAccounts()
    }

    func deleteAccount(id: UUID) throws {
        guard let account = try findAccount(by: id) else { throw PersonalLedgerError.accountNotFound }
        guard account.balanceMinorUnits == 0 else { throw PersonalLedgerError.cannotDeleteNonEmptyAccount }
        context.delete(account)
        try context.save()
        try refreshAccounts()
    }

    private func nameExists(_ name: String, excluding id: UUID?) throws -> Bool {
        let predicate = #Predicate<PersonalAccount> { account in
            if let id = id {
                account.remoteId != id && account.name == name
            } else {
                account.name == name
            }
        }
        var descriptor = FetchDescriptor<PersonalAccount>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first != nil
    }

    private func findAccount(by id: UUID) throws -> PersonalAccount? {
        let predicate = #Predicate<PersonalAccount> { $0.remoteId == id }
        var descriptor = FetchDescriptor<PersonalAccount>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func account(with id: UUID) -> PersonalAccount? {
        if let cached = activeAccounts.first(where: { $0.remoteId == id }) {
            return cached
        }
        if let cached = archivedAccounts.first(where: { $0.remoteId == id }) {
            return cached
        }
        return try? findAccount(by: id)
    }

    // MARK: - Transactions

    @discardableResult
    func saveTransaction(_ input: PersonalTransactionInput) throws -> PersonalTransaction {
        guard let accountId = input.accountId else {
            throw PersonalLedgerError.accountRequired
        }
        guard !input.categoryKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw PersonalLedgerError.categoryRequired
        }
        guard input.amount > 0 else {
            throw PersonalLedgerError.amountMustBePositive
        }
        guard let account = try findAccount(by: accountId) else { throw PersonalLedgerError.accountNotFound }
        let amountMinor = SettlementMath.minorUnits(from: input.amount, scale: 2)

        let transaction: PersonalTransaction
        if let id = input.id, let existing = try findTransaction(by: id) {
            try adjustBalance(for: existing, revert: true)
            transaction = existing
        } else {
            transaction = PersonalTransaction(kind: input.kind,
                                              accountId: account.remoteId,
                                              categoryKey: input.categoryKey,
                                              amountMinorUnits: amountMinor,
                                              occurredAt: input.occurredAt,
                                              note: input.note,
                                              attachmentPath: input.attachmentPath,
                                              displayCurrency: input.displayCurrency,
                                              fxRate: input.fxRate)
            context.insert(transaction)
        }

        transaction.kind = input.kind
        transaction.accountId = account.remoteId
        transaction.categoryKey = input.categoryKey
        transaction.amountMinorUnits = amountMinor
        transaction.occurredAt = input.occurredAt
        transaction.note = input.note
        transaction.attachmentPath = input.attachmentPath
        transaction.displayCurrency = input.displayCurrency
        transaction.fxRate = input.fxRate
        transaction.updatedAt = Date.now

        try adjustBalance(for: transaction, revert: false)
        preferences.lastUsedAccountId = account.remoteId
        preferences.lastUsedCategoryKey = input.categoryKey
        try context.save()
        try refreshAccounts()
        return transaction
    }

    func deleteTransactions(ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        let predicate = #Predicate<PersonalTransaction> { ids.contains($0.remoteId) }
        let descriptor = FetchDescriptor<PersonalTransaction>(predicate: predicate)
        let transactions = try context.fetch(descriptor)
        for transaction in transactions {
            try adjustBalance(for: transaction, revert: true)
            context.delete(transaction)
        }
        try context.save()
        try refreshAccounts()
    }

    private func findTransaction(by id: UUID) throws -> PersonalTransaction? {
        let predicate = #Predicate<PersonalTransaction> { $0.remoteId == id }
        var descriptor = FetchDescriptor<PersonalTransaction>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func adjustBalance(for transaction: PersonalTransaction, revert: Bool) throws {
        guard let account = try findAccount(by: transaction.accountId) else {
            throw PersonalLedgerError.accountNotFound
        }
        let sign: Int = revert ? -1 : 1
        switch transaction.kind {
        case .income:
            account.balanceMinorUnits += sign * transaction.amountMinorUnits
        case .expense, .fee:
            account.balanceMinorUnits -= sign * transaction.amountMinorUnits
        }
        account.updatedAt = Date.now
    }

    func todayTransactions(limit: Int) throws -> [PersonalTransaction] {
        let now = Date()
        guard let dayRange = calendar.dateInterval(of: .day, for: now) else { return [] }
        let records = try records(filter: PersonalRecordFilter(dateRange: dayRange.start...dayRange.end,
                                                               kinds: [.income, .expense]))
            .sorted(by: { $0.occurredAt > $1.occurredAt })
        return Array(records.prefix(limit))
    }

    func records(filter: PersonalRecordFilter) throws -> [PersonalTransaction] {
        var predicate: Predicate<PersonalTransaction>? = nil
        if let range = filter.dateRange {
            let start = range.lowerBound
            let end = range.upperBound
            predicate = #Predicate { transaction in
                transaction.occurredAt >= start && transaction.occurredAt < end
            }
        }
        let descriptor = FetchDescriptor<PersonalTransaction>(predicate: predicate,
                                                              sortBy: [SortDescriptor(\.occurredAt, order: .reverse)])
        var results = try context.fetch(descriptor)
        if let kinds = filter.kinds, !kinds.isEmpty {
            results = results.filter { kinds.contains($0.kind) }
        }
        if let accountIds = filter.accountIds, !accountIds.isEmpty {
            results = results.filter { accountIds.contains($0.accountId) }
        }
        if let categoryKeys = filter.categoryKeys, !categoryKeys.isEmpty {
            results = results.filter { categoryKeys.contains($0.categoryKey) }
        }
        if let minAmount = filter.minimumAmountMinor {
            results = results.filter { $0.amountMinorUnits >= minAmount }
        }
        if let maxAmount = filter.maximumAmountMinor {
            results = results.filter { $0.amountMinorUnits <= maxAmount }
        }
        if let keyword = filter.keyword?.lowercased(), !keyword.isEmpty {
            results = results.filter {
                $0.note.lowercased().contains(keyword) ||
                $0.categoryKey.lowercased().contains(keyword)
            }
        }
        return results
    }

    func monthlyTotals(for month: Date, includeFees: Bool) throws -> (expense: Int, income: Int) {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return (0, 0) }
        var kinds: Set<PersonalTransactionKind> = [.expense, .income]
        if includeFees {
            kinds.insert(.fee)
        }
        let transactions = try records(filter: PersonalRecordFilter(dateRange: interval.start...interval.end,
                                                                    kinds: kinds))
        var expense = 0
        var income = 0
        for transaction in transactions {
            let currency = currency(for: transaction.accountId)
            let converted = convertToDisplay(minorUnits: transaction.amountMinorUnits, currency: currency, fxRate: transaction.fxRate)
            switch transaction.kind {
            case .income:
                income += converted
            case .expense:
                expense += converted
            case .fee:
                if includeFees {
                    expense += converted
                }
            }
        }
        return (expense, income)
    }

    // MARK: - Transfers

    @discardableResult
    func saveTransfer(_ input: PersonalTransferInput) throws -> AccountTransfer {
        guard let fromId = input.fromAccountId, let toId = input.toAccountId else {
            throw PersonalLedgerError.accountRequired
        }
        guard fromId != toId else { throw PersonalLedgerError.sameTransferAccount }
        guard input.amountFrom > 0 else { throw PersonalLedgerError.amountMustBePositive }
        guard input.fxRate > 0 else { throw PersonalLedgerError.invalidExchangeRate }
        guard let fromAccount = try findAccount(by: fromId), let toAccount = try findAccount(by: toId) else {
            throw PersonalLedgerError.accountNotFound
        }

        let amountFromMinor = SettlementMath.minorUnits(from: input.amountFrom, scale: 2)
        let converted = input.amountFrom * input.fxRate
        let amountToMinor = SettlementMath.minorUnits(from: converted, scale: 2)

        let transfer: AccountTransfer
        if let id = input.id, let existing = try findTransfer(by: id) {
            try revertTransferEffects(existing)
            transfer = existing
        } else {
            transfer = AccountTransfer(fromAccountId: fromId,
                                       toAccountId: toId,
                                       amountFromMinorUnits: amountFromMinor,
                                       fxRate: input.fxRate,
                                       amountToMinorUnits: amountToMinor,
                                       feeMinorUnits: nil,
                                       feeCurrency: input.feeCurrency,
                                       feeChargedOn: input.feeSide,
                                       occurredAt: input.occurredAt,
                                       note: input.note,
                                       feeTransactionId: nil)
            context.insert(transfer)
        }

        transfer.fromAccountId = fromId
        transfer.toAccountId = toId
        transfer.amountFromMinorUnits = amountFromMinor
        transfer.fxRate = input.fxRate
        transfer.amountToMinorUnits = amountToMinor
        transfer.occurredAt = input.occurredAt
        transfer.note = input.note
        transfer.feeCurrency = input.feeCurrency
        transfer.feeChargedOn = input.feeSide
        transfer.updatedAt = Date.now

        fromAccount.balanceMinorUnits -= amountFromMinor
        toAccount.balanceMinorUnits += amountToMinor

        var feeTransaction: PersonalTransaction?
        if let feeDecimal = input.feeAmount, feeDecimal > 0 {
            guard let side = input.feeSide else { throw PersonalLedgerError.invalidFeeSide }
            let targetAccount = side == .from ? fromAccount : toAccount
            let currency = side == .from ? fromAccount.currency : toAccount.currency
            if let specifiedCurrency = input.feeCurrency, specifiedCurrency != currency {
                throw PersonalLedgerError.invalidFeeCurrency
            }
            let feeMinor = SettlementMath.minorUnits(from: feeDecimal, scale: 2)
            targetAccount.balanceMinorUnits -= feeMinor
            transfer.feeMinorUnits = feeMinor
            transfer.feeCurrency = currency
            transfer.feeChargedOn = side

            let feeTransactionId = transfer.feeTransactionId ?? UUID()
            if let existingId = transfer.feeTransactionId, let existingFee = try findTransaction(by: existingId) {
                feeTransaction = existingFee
            }
            if feeTransaction == nil {
                feeTransaction = PersonalTransaction(remoteId: feeTransactionId,
                                                     kind: .fee,
                                                     accountId: targetAccount.remoteId,
                                                     categoryKey: preferences.defaultFeeCategoryKey ?? "fees",
                                                     amountMinorUnits: feeMinor,
                                                     occurredAt: input.occurredAt,
                                                     note: input.note.isEmpty ? "Transfer fee" : input.note)
                if let feeTransaction {
                    context.insert(feeTransaction)
                }
            }
            if let feeTransaction {
                feeTransaction.kind = .fee
                feeTransaction.accountId = targetAccount.remoteId
                feeTransaction.categoryKey = preferences.defaultFeeCategoryKey ?? "fees"
                feeTransaction.amountMinorUnits = feeMinor
                feeTransaction.occurredAt = input.occurredAt
                feeTransaction.note = input.note.isEmpty ? "Transfer fee" : input.note
                feeTransaction.updatedAt = Date.now
                transfer.feeTransactionId = feeTransaction.remoteId
            }
        } else {
            if let feeId = transfer.feeTransactionId, let feeTransaction = try findTransaction(by: feeId) {
                try adjustBalance(for: feeTransaction, revert: true)
                context.delete(feeTransaction)
            }
            transfer.feeMinorUnits = nil
            transfer.feeCurrency = nil
            transfer.feeChargedOn = nil
            transfer.feeTransactionId = nil
        }

        fromAccount.updatedAt = Date.now
        toAccount.updatedAt = Date.now
        try context.save()
        try refreshAccounts()
        return transfer
    }

    func deleteTransfer(id: UUID) throws {
        guard let transfer = try findTransfer(by: id) else { throw PersonalLedgerError.transferNotFound }
        try revertTransferEffects(transfer)
        context.delete(transfer)
        try context.save()
        try refreshAccounts()
    }

    private func findTransfer(by id: UUID) throws -> AccountTransfer? {
        let predicate = #Predicate<AccountTransfer> { $0.remoteId == id }
        var descriptor = FetchDescriptor<AccountTransfer>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func revertTransferEffects(_ transfer: AccountTransfer) throws {
        guard let fromAccount = try findAccount(by: transfer.fromAccountId),
              let toAccount = try findAccount(by: transfer.toAccountId) else {
            throw PersonalLedgerError.accountNotFound
        }
        fromAccount.balanceMinorUnits += transfer.amountFromMinorUnits
        toAccount.balanceMinorUnits -= transfer.amountToMinorUnits
        if let feeMinor = transfer.feeMinorUnits,
           let side = transfer.feeChargedOn {
            if let feeId = transfer.feeTransactionId, let feeTransaction = try findTransaction(by: feeId) {
                try adjustBalance(for: feeTransaction, revert: true)
                context.delete(feeTransaction)
            } else {
                let account = (side == .from) ? fromAccount : toAccount
                account.balanceMinorUnits += feeMinor
            }
        }
        transfer.feeTransactionId = nil
        transfer.feeMinorUnits = nil
        transfer.feeCurrency = nil
        transfer.feeChargedOn = nil
        fromAccount.updatedAt = Date.now
        toAccount.updatedAt = Date.now
    }


    private func currency(for accountId: UUID) -> CurrencyCode {
        if let cached = activeAccounts.first(where: { $0.remoteId == accountId }) {
            return cached.currency
        }
        if let cached = archivedAccounts.first(where: { $0.remoteId == accountId }) {
            return cached.currency
        }
        if let account = try? findAccount(by: accountId) {
            return account.currency
        }
        return preferences.primaryDisplayCurrency
    }

    private func conversionRate(from currency: CurrencyCode, fxRate: Decimal?) -> Decimal {
        guard currency != preferences.primaryDisplayCurrency else { return 1 }
        if let fxRate, fxRate > 0 {
            return fxRate
        }
        if let stored = preferences.fxRates[currency], stored > 0 {
            return stored
        }
        if let fallback = preferences.defaultFXRate, fallback > 0 {
            return fallback
        }
        return 1
    }

    func convertToDisplay(minorUnits: Int, currency: CurrencyCode, fxRate: Decimal?) -> Int {
        guard currency != preferences.primaryDisplayCurrency else { return minorUnits }
        guard minorUnits != 0 else { return 0 }
        let amount = SettlementMath.decimal(fromMinorUnits: minorUnits, scale: 2)
        let converted = amount * conversionRate(from: currency, fxRate: fxRate)
        return SettlementMath.minorUnits(from: converted, scale: 2)
    }

    func clearAllPersonalData() throws {
        let transactions = try context.fetch(FetchDescriptor<PersonalTransaction>())
        for transaction in transactions {
            context.delete(transaction)
        }
        let transfers = try context.fetch(FetchDescriptor<AccountTransfer>())
        for transfer in transfers {
            context.delete(transfer)
        }
        let accounts = try context.fetch(FetchDescriptor<PersonalAccount>())
        for account in accounts {
            context.delete(account)
        }
        preferences.lastUsedAccountId = nil
        preferences.lastUsedCategoryKey = nil
        preferences.fxRates = [:]
        try context.save()
        try refreshAccounts()
    }

    // MARK: - Analytics

    func categoryBreakdown(for range: ClosedRange<Date>, includeFees: Bool, accountIds: Set<UUID>?) throws -> [String: Int] {
        var kinds: Set<PersonalTransactionKind> = [.expense]
        if includeFees {
            kinds.insert(.fee)
        }
        var filter = PersonalRecordFilter(dateRange: range, kinds: kinds)
        filter.accountIds = accountIds
        let transactions = try records(filter: filter)
        var totals: [String: Int] = [:]
        for transaction in transactions {
            let currency = currency(for: transaction.accountId)
            let converted = convertToDisplay(minorUnits: transaction.amountMinorUnits, currency: currency, fxRate: transaction.fxRate)
            totals[transaction.categoryKey, default: 0] += converted
        }
        return totals
    }

    func timeline(for range: ClosedRange<Date>, kinds: Set<PersonalTransactionKind>, accountIds: Set<UUID>?) throws -> [Date: (income: Int, expense: Int)] {
        var filter = PersonalRecordFilter(dateRange: range, kinds: kinds)
        filter.accountIds = accountIds
        let transactions = try records(filter: filter)
        var daily: [Date: (income: Int, expense: Int)] = [:]
        for transaction in transactions {
            let dayStart = calendar.startOfDay(for: transaction.occurredAt)
            var bucket = daily[dayStart] ?? (income: 0, expense: 0)
            let currency = currency(for: transaction.accountId)
            let converted = convertToDisplay(minorUnits: transaction.amountMinorUnits, currency: currency, fxRate: transaction.fxRate)
            switch transaction.kind {
            case .income:
                bucket.income += converted
            case .expense, .fee:
                bucket.expense += converted
            }
            daily[dayStart] = bucket
        }
        return daily
    }
}
