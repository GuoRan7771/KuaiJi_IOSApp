//
//  PersonalLedgerStoreTypes.swift
//  KuaiJi
//

import Foundation
import Combine
import SwiftData
import SwiftUI

//
//  PersonalLedgerStore.swift
//  KuaiJi
//
//  Personal ledger domain service coordinating SwiftData operations and aggregates.
//

import Foundation
import Combine
import SwiftData
import SwiftUI

// MARK: - Errors & Inputs

enum PersonalLedgerError: LocalizedError {
    case accountNotFound
    case transactionNotFound
    case transferNotFound
    case templateNotFound
    case amountMustBePositive
    case categoryRequired
    case accountRequired
    case cannotDeleteNonEmptyAccount
    case duplicateAccountName
    case nameRequired
    case templateNameRequired
    case sameTransferAccount
    case invalidExchangeRate
    case invalidFeeSide
    case invalidFeeCurrency

    var errorDescription: String? {
        switch self {
        case .accountNotFound: return "Account not found".localized
        case .transactionNotFound: return "Transaction not found".localized
        case .transferNotFound: return "Transfer not found".localized
        case .templateNotFound: return "Template not found".localized
        case .amountMustBePositive: return L.errorAmountMustBePositive.localized
        case .categoryRequired: return "Category is required".localized
        case .accountRequired: return L.errorAccountRequired.localized
        case .cannotDeleteNonEmptyAccount: return "Balance must be zero before deletion".localized
        case .duplicateAccountName: return "Account name already exists".localized
        case .nameRequired: return "Account name is required".localized
        case .templateNameRequired: return L.errorTemplateNameRequired.localized
        case .sameTransferAccount: return "Source and target accounts must differ".localized
        case .invalidExchangeRate: return "Exchange rate must be greater than zero".localized
        case .invalidFeeSide: return "Fee side is required when fee exists".localized
        case .invalidFeeCurrency: return "Fee currency does not match account".localized
        }
    }
}

// MARK: - Export Snapshot Models

struct PersonalLedgerSnapshot: Codable {
    private enum CodingKeys: String, CodingKey {
        case preferences
        case accounts
        case transactions
        case transfers
        case templates
        case categories
    }

    struct Preferences: Codable {
        var primaryDisplayCurrency: CurrencyCode
        var fxSource: PersonalFXSource
        var defaultFXRate: Decimal?
        var fxRates: [CurrencyCode: Decimal]
        var defaultFXPrecision: Int
        var countFeeInStats: Bool
        var lastUsedAccountId: UUID?
        var lastUsedCategoryKey: String?
        var defaultFeeCategoryKey: String?
        var defaultConversionFee: Decimal?
        var lastBackupAt: Date?
        var systemCategoryColors: [String: String]
        var hiddenSystemCategoryKeys: [String]

        init(from preferences: PersonalPreferences) {
            self.primaryDisplayCurrency = preferences.primaryDisplayCurrency
            self.fxSource = preferences.fxSource
            self.defaultFXRate = preferences.defaultFXRate
            self.fxRates = preferences.fxRates
            self.defaultFXPrecision = preferences.defaultFXPrecision
            self.countFeeInStats = preferences.countFeeInStats
            self.lastUsedAccountId = preferences.lastUsedAccountId
            self.lastUsedCategoryKey = preferences.lastUsedCategoryKey
            self.defaultFeeCategoryKey = preferences.defaultFeeCategoryKey
            self.defaultConversionFee = preferences.defaultConversionFee
            self.lastBackupAt = preferences.lastBackupAt
            self.systemCategoryColors = preferences.systemCategoryColors ?? [:]
            self.hiddenSystemCategoryKeys = preferences.hiddenSystemCategoryKeys ?? []
        }

        private enum CodingKeys: String, CodingKey {
            case primaryDisplayCurrency, fxSource, defaultFXRate, fxRates, defaultFXPrecision, countFeeInStats, lastUsedAccountId, lastUsedCategoryKey, defaultFeeCategoryKey, defaultConversionFee, lastBackupAt, systemCategoryColors, hiddenSystemCategoryKeys
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            primaryDisplayCurrency = try container.decode(CurrencyCode.self, forKey: .primaryDisplayCurrency)
            fxSource = try container.decode(PersonalFXSource.self, forKey: .fxSource)
            defaultFXRate = try container.decodeIfPresent(Decimal.self, forKey: .defaultFXRate)
            fxRates = try container.decodeIfPresent([CurrencyCode: Decimal].self, forKey: .fxRates) ?? [:]
            defaultFXPrecision = try container.decode(Int.self, forKey: .defaultFXPrecision)
            countFeeInStats = try container.decode(Bool.self, forKey: .countFeeInStats)
            lastUsedAccountId = try container.decodeIfPresent(UUID.self, forKey: .lastUsedAccountId)
            lastUsedCategoryKey = try container.decodeIfPresent(String.self, forKey: .lastUsedCategoryKey)
            defaultFeeCategoryKey = try container.decodeIfPresent(String.self, forKey: .defaultFeeCategoryKey)
            defaultConversionFee = try container.decodeIfPresent(Decimal.self, forKey: .defaultConversionFee)
            lastBackupAt = try container.decodeIfPresent(Date.self, forKey: .lastBackupAt)
            systemCategoryColors = try container.decodeIfPresent([String: String].self, forKey: .systemCategoryColors) ?? [:]
            hiddenSystemCategoryKeys = try container.decodeIfPresent([String].self, forKey: .hiddenSystemCategoryKeys) ?? []
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(primaryDisplayCurrency, forKey: .primaryDisplayCurrency)
            try container.encode(fxSource, forKey: .fxSource)
            try container.encodeIfPresent(defaultFXRate, forKey: .defaultFXRate)
            try container.encode(fxRates, forKey: .fxRates)
            try container.encode(defaultFXPrecision, forKey: .defaultFXPrecision)
            try container.encode(countFeeInStats, forKey: .countFeeInStats)
            try container.encodeIfPresent(lastUsedAccountId, forKey: .lastUsedAccountId)
            try container.encodeIfPresent(lastUsedCategoryKey, forKey: .lastUsedCategoryKey)
            try container.encodeIfPresent(defaultFeeCategoryKey, forKey: .defaultFeeCategoryKey)
            try container.encodeIfPresent(defaultConversionFee, forKey: .defaultConversionFee)
            try container.encodeIfPresent(lastBackupAt, forKey: .lastBackupAt)
            try container.encode(systemCategoryColors, forKey: .systemCategoryColors)
            try container.encode(hiddenSystemCategoryKeys, forKey: .hiddenSystemCategoryKeys)
        }
    }

    struct Category: Codable {
        var remoteId: UUID
        var key: String
        var name: String
        var kind: PersonalTransactionKind
        var systemImage: String
        var colorHex: String
        var mappedSystemCategory: ExpenseCategory?
        var sortIndex: Int
        var createdAt: Date
        var updatedAt: Date

        init(from category: PersonalCategoryDefinition) {
            self.remoteId = category.remoteId
            self.key = category.key
            self.name = category.name
            self.kind = category.kind
            self.systemImage = category.systemImage
            self.colorHex = category.colorHex
            self.mappedSystemCategory = category.mappedSystemCategory
            self.sortIndex = category.sortIndex
            self.createdAt = category.createdAt
            self.updatedAt = category.updatedAt
        }
    }

    struct Account: Codable {
        var remoteId: UUID
        var name: String
        var type: PersonalAccountType
        var currency: CurrencyCode
        var includeInNetWorth: Bool
        var balanceMinorUnits: Int
        var note: String?
        var status: PersonalAccountStatus
        var creditLimitMinorUnits: Int?
        var createdAt: Date
        var updatedAt: Date

        init(from account: PersonalAccount) {
            self.remoteId = account.remoteId
            self.name = account.name
            self.type = account.type
            self.currency = account.currency
            self.includeInNetWorth = account.includeInNetWorth
            self.balanceMinorUnits = account.balanceMinorUnits
            self.note = account.note
            self.status = account.status
            self.creditLimitMinorUnits = account.creditLimitMinorUnits
            self.createdAt = account.createdAt
            self.updatedAt = account.updatedAt
        }
    }

    struct Transaction: Codable {
        var remoteId: UUID
        var kind: PersonalTransactionKind
        var accountId: UUID
        var categoryKey: String
        var amountMinorUnits: Int
        var occurredAt: Date
        var note: String
        var attachmentPath: String?
        var createdAt: Date
        var updatedAt: Date
        var displayCurrency: CurrencyCode?
        var fxRate: Decimal?

        init(from transaction: PersonalTransaction) {
            self.remoteId = transaction.remoteId
            self.kind = transaction.kind
            self.accountId = transaction.accountId
            self.categoryKey = transaction.categoryKey
            self.amountMinorUnits = transaction.amountMinorUnits
            self.occurredAt = transaction.occurredAt
            self.note = transaction.note
            self.attachmentPath = transaction.attachmentPath
            self.createdAt = transaction.createdAt
            self.updatedAt = transaction.updatedAt
            self.displayCurrency = transaction.displayCurrency
            self.fxRate = transaction.fxRate
        }
    }

    struct Transfer: Codable {
        var remoteId: UUID
        var fromAccountId: UUID
        var toAccountId: UUID
        var amountFromMinorUnits: Int
        var fxRate: Decimal
        var amountToMinorUnits: Int
        var feeMinorUnits: Int?
        var feeCurrency: CurrencyCode?
        var feeChargedOn: PersonalTransferFeeSide?
        var occurredAt: Date
        var note: String
        var createdAt: Date
        var updatedAt: Date
        var feeTransactionId: UUID?

        init(from transfer: AccountTransfer) {
            self.remoteId = transfer.remoteId
            self.fromAccountId = transfer.fromAccountId
            self.toAccountId = transfer.toAccountId
            self.amountFromMinorUnits = transfer.amountFromMinorUnits
            self.fxRate = transfer.fxRate
            self.amountToMinorUnits = transfer.amountToMinorUnits
            self.feeMinorUnits = transfer.feeMinorUnits
            self.feeCurrency = transfer.feeCurrency
            self.feeChargedOn = transfer.feeChargedOn
            self.occurredAt = transfer.occurredAt
            self.note = transfer.note
            self.createdAt = transfer.createdAt
            self.updatedAt = transfer.updatedAt
            self.feeTransactionId = transfer.feeTransactionId
        }
    }

    struct Template: Codable {
        var remoteId: UUID
        var name: String
        var accountId: UUID?
        var amountMinorUnits: Int
        var currency: CurrencyCode
        var categoryKey: String
        var note: String?
        var createdAt: Date
        var updatedAt: Date
        var sortIndex: Int

        init(from template: PersonalRecordTemplate) {
            self.remoteId = template.remoteId
            self.name = template.name
            self.accountId = template.accountId
            self.amountMinorUnits = template.amountMinorUnits
            self.currency = template.currency
            self.categoryKey = template.categoryKey
            self.note = template.note
            self.createdAt = template.createdAt
            self.updatedAt = template.updatedAt
            self.sortIndex = template.sortIndex
        }
    }

    var preferences: Preferences
    var accounts: [Account]
    var transactions: [Transaction]
    var transfers: [Transfer]
    var templates: [Template] = []
        var categories: [Category] = []

    init(preferences: Preferences,
         accounts: [Account],
         transactions: [Transaction],
         transfers: [Transfer],
         templates: [Template] = [],
         categories: [Category] = []) {
        self.preferences = preferences
        self.accounts = accounts
        self.transactions = transactions
        self.transfers = transfers
        self.templates = templates
        self.categories = categories
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        preferences = try container.decode(Preferences.self, forKey: .preferences)
        accounts = try container.decode([Account].self, forKey: .accounts)
        transactions = try container.decode([Transaction].self, forKey: .transactions)
        transfers = try container.decode([Transfer].self, forKey: .transfers)
        templates = try container.decodeIfPresent([Template].self, forKey: .templates) ?? []
        categories = try container.decodeIfPresent([Category].self, forKey: .categories) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(preferences, forKey: .preferences)
        try container.encode(accounts, forKey: .accounts)
        try container.encode(transactions, forKey: .transactions)
        try container.encode(transfers, forKey: .transfers)
        if !templates.isEmpty {
            try container.encode(templates, forKey: .templates)
        }
        if !categories.isEmpty {
            try container.encode(categories, forKey: .categories)
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
    var creditLimit: Decimal?
    var note: String?
    var status: PersonalAccountStatus

    init(id: UUID? = nil,
         name: String = "",
         type: PersonalAccountType = .bankCard,
         currency: CurrencyCode = .cny,
         includeInNetWorth: Bool = true,
         initialBalance: Decimal = 0,
         creditLimit: Decimal? = nil,
         note: String? = nil,
         status: PersonalAccountStatus = .active) {
        self.id = id
        self.name = name
        self.type = type
        self.currency = currency
        self.includeInNetWorth = includeInNetWorth
        self.initialBalance = initialBalance
        self.creditLimit = creditLimit
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

struct PersonalRecordTemplateInput {
    var id: UUID?
    var name: String
    var accountId: UUID?
    var amount: Decimal
    var currency: CurrencyCode
    var categoryKey: String
    var note: String?

    init(id: UUID? = nil,
         name: String = "",
         accountId: UUID? = nil,
         amount: Decimal = 0,
         currency: CurrencyCode = .cny,
         categoryKey: String = "",
         note: String? = nil) {
        self.id = id
        self.name = name
        self.accountId = accountId
        self.amount = amount
        self.currency = currency
        self.categoryKey = categoryKey
        self.note = note
    }
}

struct PersonalCategoryInput {
    var id: UUID?
    var name: String
    var kind: PersonalTransactionKind
    var systemImage: String
    var color: Color
    var mappedSystemCategory: ExpenseCategory?
    var sortIndex: Int?
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
