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

// MARK: - Store

@MainActor
final class PersonalLedgerStore: ObservableObject {
    private let context: ModelContext
    private let calendar: Calendar
    private let recoveryDefaultCurrency: CurrencyCode

    @Published private(set) var preferences: PersonalPreferences
    @Published private(set) var activeAccounts: [PersonalAccount] = []
    @Published private(set) var archivedAccounts: [PersonalAccount] = []
    @Published private(set) var recordTemplates: [PersonalRecordTemplate] = []
    @Published private(set) var customCategories: [PersonalCategoryDefinition] = []

    init(context: ModelContext, defaultCurrency: CurrencyCode = .cny, calendar: Calendar = .current) throws {
        self.context = context
        self.calendar = calendar
        self.recoveryDefaultCurrency = defaultCurrency
        self.preferences = try PersonalLedgerStore.ensurePreferences(in: context, defaultCurrency: defaultCurrency)
        try refreshCustomCategories()
        try refreshAccounts()
        try refreshTemplates()
    }

    // MARK: - Preferences

    func updatePreferences(_ block: (PersonalPreferences) -> Void) throws {
        ensurePreferencesConsistency()
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

    /// 在可能被外部数据清理后，确保 preferences 始终存在且为有效对象
    private func ensurePreferencesConsistency() {
        do {
            var descriptor = FetchDescriptor<PersonalPreferences>()
            descriptor.fetchLimit = 1
            if let existing = try context.fetch(descriptor).first {
                // 如果当前持有的引用不一致或已失效，则用数据库中的有效对象替换
                if existing.remoteId != preferences.remoteId {
                    preferences = existing
                }
            } else {
                // 已被清空，重建一份
                let prefs = PersonalPreferences(primaryDisplayCurrency: recoveryDefaultCurrency)
                context.insert(prefs)
                try context.save()
                preferences = prefs
            }
        } catch {
            // 兜底：若获取失败则尝试重建
            let prefs = PersonalPreferences(primaryDisplayCurrency: recoveryDefaultCurrency)
            context.insert(prefs)
            try? context.save()
            preferences = prefs
        }
    }

    // MARK: - Safe accessors for preferences
    func getPreferences() -> PersonalPreferences {
        ensurePreferencesConsistency()
        return preferences
    }

    func safePrimaryDisplayCurrency() -> CurrencyCode {
        ensurePreferencesConsistency()
        return preferences.primaryDisplayCurrency
    }

    func safeCountFeeInStats() -> Bool {
        ensurePreferencesConsistency()
        return preferences.countFeeInStats
    }

    func safeDefaultFXRate() -> Decimal? {
        ensurePreferencesConsistency()
        return preferences.defaultFXRate
    }

    func safeDefaultConversionFee() -> Decimal? {
        ensurePreferencesConsistency()
        return preferences.defaultConversionFee
    }

    func systemCategoryColorHex(for key: String) -> String? {
        ensurePreferencesConsistency()
        return preferences.systemCategoryColors?[key]
    }

    func systemCategoryHidden(_ key: String) -> Bool {
        ensurePreferencesConsistency()
        return preferences.hiddenSystemCategoryKeys?.contains(key) ?? false
    }

    func safeLastUsedAccountId() -> UUID? {
        ensurePreferencesConsistency()
        return preferences.lastUsedAccountId
    }

    func safeLastUsedCategoryKey() -> String? {
        ensurePreferencesConsistency()
        return preferences.lastUsedCategoryKey
    }

    func safeDefaultFeeCategoryKey() -> String? {
        ensurePreferencesConsistency()
        return preferences.defaultFeeCategoryKey
    }

    func safeFXRate(for currency: CurrencyCode) -> Decimal? {
        ensurePreferencesConsistency()
        return preferences.fxRates[currency]
    }

    // MARK: - Categories

    func refreshCustomCategories() throws {
        let descriptor = FetchDescriptor<PersonalCategoryDefinition>(
            sortBy: [
                SortDescriptor(\.sortIndex, order: .forward),
                SortDescriptor(\.createdAt, order: .forward)
            ])
        customCategories = try context.fetch(descriptor)
    }

    @discardableResult
    func saveCategory(_ input: PersonalCategoryInput) throws -> PersonalCategoryDefinition {
        let trimmedName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw PersonalLedgerError.nameRequired }
        let trimmedSymbol = input.systemImage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSymbol.isEmpty else { throw PersonalLedgerError.categoryRequired }
        let resolvedHex = input.color.toHexRGB() ?? Color.appBrand.toHexRGB() ?? "FF7F50"

        let category: PersonalCategoryDefinition
        if let id = input.id, let existing = try findCategory(by: id) {
            category = existing
        } else {
            let sortIndex = input.sortIndex ?? customCategories.filter { $0.kind == input.kind }.count
            category = PersonalCategoryDefinition(key: UUID().uuidString,
                                                  name: trimmedName,
                                                  kind: input.kind,
                                                  systemImage: trimmedSymbol,
                                                  colorHex: resolvedHex,
                                                  mappedSystemCategory: input.mappedSystemCategory,
                                                  sortIndex: sortIndex)
            context.insert(category)
        }

        category.name = trimmedName
        category.kind = input.kind
        category.systemImage = trimmedSymbol
        category.colorHex = resolvedHex
        category.mappedSystemCategory = input.mappedSystemCategory
        if let sortIndex = input.sortIndex {
            category.sortIndex = sortIndex
        }
        category.updatedAt = Date.now

        try context.save()
        try refreshCustomCategories()
        objectWillChange.send()
        return category
    }

    func deleteCategory(id: UUID) throws {
        guard let category = try findCategory(by: id) else { return }
        context.delete(category)
        try context.save()
        try refreshCustomCategories()
        objectWillChange.send()
    }

    func categoryOptions(for kind: PersonalTransactionKind) -> [PersonalCategoryOption] {
        categoryOptions(for: kind, includeHiddenKey: nil)
    }

    func categoryOptions(for kind: PersonalTransactionKind, includeHiddenKey: String?) -> [PersonalCategoryOption] {
        let base: [PersonalCategoryOption]
        switch kind {
        case .expense: base = systemExpenseCategories
        case .income: base = systemIncomeCategories
        case .fee: base = feeCategories
        }
        let visibleSystem = base.compactMap { option -> PersonalCategoryOption? in
            if systemCategoryHidden(option.key) && option.key != includeHiddenKey {
                return nil
            }
            return applySystemOverrides(to: option)
        }
        let custom = customCategories
            .filter { $0.kind == kind }
            .sorted { lhs, rhs in
                if lhs.sortIndex == rhs.sortIndex { return lhs.createdAt < rhs.createdAt }
                return lhs.sortIndex < rhs.sortIndex
            }
            .map(makeOption(from:))
        return visibleSystem + custom
    }

    func categoryOption(for key: String) -> PersonalCategoryOption? {
        if let custom = customCategories.first(where: { $0.key == key }) {
            return makeOption(from: custom)
        }
        if let system = systemOption(for: key) {
            return system
        }
        return nil
    }

    func categoryName(for key: String) -> String {
        categoryOption(for: key)?.localizedName ?? key
    }

    func categoryColor(for key: String) -> Color {
        if let option = categoryOption(for: key) {
            return option.color
        }
        return hashedCategoryColor(for: key)
    }

    func categoryIcon(for key: String) -> String {
        if let option = categoryOption(for: key) {
            return option.systemImage
        }
        if let legacy = legacyExpenseIconMap[key] {
            return legacy
        }
        return "tag"
    }

    private func makeOption(from category: PersonalCategoryDefinition) -> PersonalCategoryOption {
        let group: PersonalCategoryOption.Group
        switch category.kind {
        case .expense: group = .expense
        case .income: group = .income
        case .fee: group = .neutral
        }
        let color = Color(hex: category.colorHex) ?? Color.appBrand
        return PersonalCategoryOption(customKey: category.key,
                                      name: category.name,
                                      systemImage: category.systemImage,
                                      group: group,
                                      color: color,
                                      mappedSystemCategory: category.mappedSystemCategory)
    }

    private func systemOption(for key: String) -> PersonalCategoryOption? {
        if let base = (systemExpenseCategories + systemIncomeCategories + feeCategories).first(where: { $0.key == key }) {
            return applySystemOverrides(to: base)
        }
        return nil
    }

    private func applySystemOverrides(to option: PersonalCategoryOption) -> PersonalCategoryOption {
        let overrideColor = systemCategoryColorHex(for: option.key).flatMap(Color.init(hex:)) ?? option.color
        return PersonalCategoryOption(key: option.key,
                                      nameKey: option.nameKey ?? option.key,
                                      systemImage: option.systemImage,
                                      group: option.group,
                                      color: overrideColor,
                                      mappedSystemCategory: option.mappedSystemCategory,
                                      isCustom: false)
    }

    private func findCategory(by id: UUID) throws -> PersonalCategoryDefinition? {
        let predicate = #Predicate<PersonalCategoryDefinition> { $0.remoteId == id }
        var descriptor = FetchDescriptor<PersonalCategoryDefinition>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func setSystemCategoryColor(_ color: Color, for key: String) throws {
        guard !key.isEmpty else { return }
        try updatePreferences { prefs in
            var map = prefs.systemCategoryColors ?? [:]
            map[key] = color.toHexRGB() ?? "FF7F50"
            prefs.systemCategoryColors = map
        }
        objectWillChange.send()
    }

    func setSystemCategoryHidden(_ hidden: Bool, for key: String) throws {
        guard !key.isEmpty else { return }
        try updatePreferences { prefs in
            var set = Set(prefs.hiddenSystemCategoryKeys ?? [])
            if hidden {
                set.insert(key)
            } else {
                set.remove(key)
            }
            prefs.hiddenSystemCategoryKeys = Array(set)
        }
        objectWillChange.send()
    }

    // MARK: - Accounts

    func refreshAccounts() throws {
        let descriptor = FetchDescriptor<PersonalAccount>(
            sortBy: [
                SortDescriptor(\.sortIndex, order: .forward),
                SortDescriptor(\.createdAt, order: .forward)
            ])
        let fetched = try context.fetch(descriptor)
        activeAccounts = fetched.filter { $0.status == .active }
        archivedAccounts = fetched.filter { $0.status == .archived }
    }

    // 依据显示顺序持久化账户排序
    func reorderAccounts(idsInDisplayOrder: [UUID]) throws {
        let existing = activeAccounts + archivedAccounts
        let map = Dictionary(uniqueKeysWithValues: existing.map { ($0.remoteId, $0) })
        for (idx, id) in idsInDisplayOrder.enumerated() {
            if let account = map[id] {
                account.sortIndex = idx
                account.updatedAt = Date.now
            }
        }
        try context.save()
        try refreshAccounts()
    }

    func createAccount(from draft: PersonalAccountDraft) throws -> PersonalAccount {
        let trimmed = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw PersonalLedgerError.nameRequired
        }
        if nameExists(trimmed, excluding: nil) {
            throw PersonalLedgerError.duplicateAccountName
        }
        let balanceMinor = SettlementMath.minorUnits(from: draft.initialBalance, scale: 2)
        let creditMinor: Int?
        if draft.type == .creditCard, let limit = draft.creditLimit {
            creditMinor = SettlementMath.minorUnits(from: limit, scale: 2)
        } else {
            creditMinor = nil
        }
        let account = PersonalAccount(name: trimmed,
                                      type: draft.type,
                                      currency: draft.currency,
                                      includeInNetWorth: draft.includeInNetWorth,
                                      balanceMinorUnits: balanceMinor,
                                      note: draft.note,
                                      status: draft.status,
                                      creditLimitMinorUnits: creditMinor)
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
        if nameExists(trimmed, excluding: account.remoteId) {
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
        if draft.type == .creditCard, let limit = draft.creditLimit {
            account.creditLimitMinorUnits = SettlementMath.minorUnits(from: limit, scale: 2)
        } else {
            account.creditLimitMinorUnits = nil
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
        if preferences.lastUsedAccountId == account.remoteId {
            preferences.lastUsedAccountId = nil
        }
        context.delete(account)
        try context.save()
        try refreshAccounts()
    }

    private func nameExists(_ name: String, excluding id: UUID?) -> Bool {
        let lowered = name.lowercased()
        let existing = activeAccounts + archivedAccounts
        return existing.contains { account in
            if let id = id, account.remoteId == id { return false }
            return account.name.lowercased() == lowered
        }
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

    // MARK: - Templates

    func refreshTemplates() throws {
        let descriptor = FetchDescriptor<PersonalRecordTemplate>(
            sortBy: [
                SortDescriptor(\.sortIndex, order: .forward),
                SortDescriptor(\.createdAt, order: .forward)
            ])
        recordTemplates = try context.fetch(descriptor)
    }

    @discardableResult
    func saveTemplate(_ input: PersonalRecordTemplateInput) throws -> PersonalRecordTemplate {
        let trimmedName = input.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { throw PersonalLedgerError.templateNameRequired }
        let trimmedCategory = input.categoryKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if let accountId = input.accountId, try findAccount(by: accountId) == nil {
            throw PersonalLedgerError.accountNotFound
        }
        let cleanedNote: String?
        if let note = input.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            cleanedNote = note
        } else {
            cleanedNote = nil
        }

        let amountMinor = input.amount > 0 ? SettlementMath.minorUnits(from: input.amount, scale: 2) : 0
        let template: PersonalRecordTemplate
        if let id = input.id, let existing = try findTemplate(by: id) {
            template = existing
        } else {
            template = PersonalRecordTemplate(name: trimmedName,
                                              accountId: input.accountId,
                                              amountMinorUnits: amountMinor,
                                              currency: input.currency,
                                              categoryKey: trimmedCategory,
                                              note: input.note,
                                              sortIndex: recordTemplates.count)
            context.insert(template)
        }

        template.name = trimmedName
        template.accountId = input.accountId
        template.amountMinorUnits = amountMinor
        template.currency = input.currency
        template.categoryKey = trimmedCategory
        template.note = cleanedNote
        template.updatedAt = Date.now

        try context.save()
        try refreshTemplates()
        return template
    }

    func deleteTemplate(id: UUID) throws {
        guard let template = try findTemplate(by: id) else { throw PersonalLedgerError.templateNotFound }
        context.delete(template)
        try context.save()
        try refreshTemplates()
    }

    func reorderTemplates(idsInDisplayOrder: [UUID]) throws {
        let map = Dictionary(uniqueKeysWithValues: recordTemplates.map { ($0.remoteId, $0) })
        for (idx, id) in idsInDisplayOrder.enumerated() {
            if let template = map[id] {
                template.sortIndex = idx
                template.updatedAt = Date.now
            }
        }
        try context.save()
        try refreshTemplates()
    }

    func template(with id: UUID) -> PersonalRecordTemplate? {
        return try? findTemplate(by: id)
    }

    private func findTemplate(by id: UUID) throws -> PersonalRecordTemplate? {
        let predicate = #Predicate<PersonalRecordTemplate> { $0.remoteId == id }
        var descriptor = FetchDescriptor<PersonalRecordTemplate>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
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

    /// Deletes any personal records by id, including both transactions and transfers.
    /// When deleting transfers, also reverts their effects and removes any associated fee transactions.
    func deleteTransactionsOrTransfers(ids: [UUID]) throws {
        guard !ids.isEmpty else { return }

        // Delete transactions that match
        do {
            let txPredicate = #Predicate<PersonalTransaction> { ids.contains($0.remoteId) }
            let txDescriptor = FetchDescriptor<PersonalTransaction>(predicate: txPredicate)
            let transactions = try context.fetch(txDescriptor)
            for transaction in transactions {
                try adjustBalance(for: transaction, revert: true)
                context.delete(transaction)
            }
        }

        // Delete transfers that match
        do {
            let trPredicate = #Predicate<AccountTransfer> { ids.contains($0.remoteId) }
            let trDescriptor = FetchDescriptor<AccountTransfer>(predicate: trPredicate)
            let transfers = try context.fetch(trDescriptor)
            for transfer in transfers {
                try revertTransferEffects(transfer)
                context.delete(transfer)
            }
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

    func transfers(on date: Date) throws -> [AccountTransfer] {
        guard let dayRange = calendar.dateInterval(of: .day, for: date) else { return [] }
        return try transfers(in: dayRange.start...dayRange.end)
    }

    func transfers(in dateRange: ClosedRange<Date>?) throws -> [AccountTransfer] {
        var predicate: Predicate<AccountTransfer>? = nil
        if let range = dateRange {
            let start = range.lowerBound
            let end = range.upperBound
            predicate = #Predicate { transfer in
                transfer.occurredAt >= start && transfer.occurredAt < end
            }
        }
        let descriptor = FetchDescriptor<AccountTransfer>(predicate: predicate,
                                                          sortBy: [SortDescriptor(\.occurredAt, order: .reverse)])
        return try context.fetch(descriptor)
    }

    func transfer(with id: UUID) -> AccountTransfer? {
        let predicate = #Predicate<AccountTransfer> { $0.remoteId == id }
        var descriptor = FetchDescriptor<AccountTransfer>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func transaction(with id: UUID) -> PersonalTransaction? {
        let predicate = #Predicate<PersonalTransaction> { $0.remoteId == id }
        var descriptor = FetchDescriptor<PersonalTransaction>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
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

    func personalDataBounds() throws -> ClosedRange<Date> {
        let transactionDescriptor = FetchDescriptor<PersonalTransaction>(sortBy: [SortDescriptor(\.occurredAt, order: .forward)])
        let transactions = try context.fetch(transactionDescriptor)
        let transferDescriptor = FetchDescriptor<AccountTransfer>(sortBy: [SortDescriptor(\.occurredAt, order: .forward)])
        let transfers = try context.fetch(transferDescriptor)
        let earliestTransaction = transactions.first?.occurredAt
        let latestTransaction = transactions.last?.occurredAt
        let earliestTransfer = transfers.first?.occurredAt
        let latestTransfer = transfers.last?.occurredAt

        let candidates = [earliestTransaction, latestTransaction, earliestTransfer, latestTransfer].compactMap { $0 }
        guard let minDate = candidates.min(), let maxDate = candidates.max() else {
            let now = calendar.startOfMonth(for: Date())
            return now...now
        }
        let start = calendar.startOfMonth(for: minDate)
        let end = calendar.startOfMonth(for: maxDate)
        return start...end
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
        ensurePreferencesConsistency()
        guard currency != preferences.primaryDisplayCurrency else { return minorUnits }
        guard minorUnits != 0 else { return 0 }
        let amount = SettlementMath.decimal(fromMinorUnits: minorUnits, scale: 2)
        let converted = amount * conversionRate(from: currency, fxRate: fxRate)
        return SettlementMath.minorUnits(from: converted, scale: 2)
    }

    func clearAllPersonalData() throws {
        let templates = try context.fetch(FetchDescriptor<PersonalRecordTemplate>())
        for template in templates {
            context.delete(template)
        }
        let categories = try context.fetch(FetchDescriptor<PersonalCategoryDefinition>())
        for category in categories {
            context.delete(category)
        }
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
        preferences.systemCategoryColors = [:]
        preferences.hiddenSystemCategoryKeys = []
        try context.save()
        try refreshCustomCategories()
        try refreshAccounts()
        try refreshTemplates()
    }

    // MARK: - Export / Import Snapshot

    func exportSnapshot() throws -> PersonalLedgerSnapshot {
        let accountDescriptor = FetchDescriptor<PersonalAccount>()
        let transactionDescriptor = FetchDescriptor<PersonalTransaction>()
        let transferDescriptor = FetchDescriptor<AccountTransfer>()
        let categoryDescriptor = FetchDescriptor<PersonalCategoryDefinition>(
            sortBy: [
                SortDescriptor(\.sortIndex, order: .forward),
                SortDescriptor(\.createdAt, order: .forward)
            ])
        let templateDescriptor = FetchDescriptor<PersonalRecordTemplate>(
            sortBy: [
                SortDescriptor(\.sortIndex, order: .forward),
                SortDescriptor(\.createdAt, order: .forward)
            ])

        let accounts = try context.fetch(accountDescriptor)
        let transactions = try context.fetch(transactionDescriptor)
        let transfers = try context.fetch(transferDescriptor)
        let templates = try context.fetch(templateDescriptor)
        let categories = try context.fetch(categoryDescriptor)

        let snapshot = PersonalLedgerSnapshot(
            preferences: .init(from: preferences),
            accounts: accounts.map(PersonalLedgerSnapshot.Account.init(from:)),
            transactions: transactions.map(PersonalLedgerSnapshot.Transaction.init(from:)),
            transfers: transfers.map(PersonalLedgerSnapshot.Transfer.init(from:)),
            templates: templates.map(PersonalLedgerSnapshot.Template.init(from:)),
            categories: categories.map(PersonalLedgerSnapshot.Category.init(from:))
        )

        return snapshot
    }

    func importSnapshot(_ snapshot: PersonalLedgerSnapshot) throws {
        try clearAllPersonalData()

        try updatePreferences { prefs in
            prefs.primaryDisplayCurrency = snapshot.preferences.primaryDisplayCurrency
            prefs.fxSource = snapshot.preferences.fxSource
            prefs.defaultFXRate = snapshot.preferences.defaultFXRate
            prefs.fxRates = snapshot.preferences.fxRates
            prefs.defaultFXPrecision = snapshot.preferences.defaultFXPrecision
            prefs.countFeeInStats = snapshot.preferences.countFeeInStats
            prefs.lastUsedAccountId = snapshot.preferences.lastUsedAccountId
            prefs.lastUsedCategoryKey = snapshot.preferences.lastUsedCategoryKey
            prefs.defaultFeeCategoryKey = snapshot.preferences.defaultFeeCategoryKey
            prefs.defaultConversionFee = snapshot.preferences.defaultConversionFee
            prefs.lastBackupAt = snapshot.preferences.lastBackupAt
            prefs.systemCategoryColors = snapshot.preferences.systemCategoryColors
            prefs.hiddenSystemCategoryKeys = snapshot.preferences.hiddenSystemCategoryKeys
        }

        for account in snapshot.accounts {
            let model = PersonalAccount(
                remoteId: account.remoteId,
                name: account.name,
                type: account.type,
                currency: account.currency,
                includeInNetWorth: account.includeInNetWorth,
                balanceMinorUnits: account.balanceMinorUnits,
                note: account.note,
                status: account.status,
                creditLimitMinorUnits: account.creditLimitMinorUnits,
                createdAt: account.createdAt,
                updatedAt: account.updatedAt
            )
            context.insert(model)
        }

        for template in snapshot.templates {
            let model = PersonalRecordTemplate(
                remoteId: template.remoteId,
                name: template.name,
                accountId: template.accountId,
                amountMinorUnits: template.amountMinorUnits,
                currency: template.currency,
                categoryKey: template.categoryKey,
                note: template.note,
                createdAt: template.createdAt,
                updatedAt: template.updatedAt,
                sortIndex: template.sortIndex
            )
            context.insert(model)
        }

        for category in snapshot.categories {
            let model = PersonalCategoryDefinition(
                remoteId: category.remoteId,
                key: category.key,
                name: category.name,
                kind: category.kind,
                systemImage: category.systemImage,
                colorHex: category.colorHex,
                mappedSystemCategory: category.mappedSystemCategory,
                sortIndex: category.sortIndex,
                createdAt: category.createdAt,
                updatedAt: category.updatedAt
            )
            context.insert(model)
        }

        for transaction in snapshot.transactions {
            let model = PersonalTransaction(
                remoteId: transaction.remoteId,
                kind: transaction.kind,
                accountId: transaction.accountId,
                categoryKey: transaction.categoryKey,
                amountMinorUnits: transaction.amountMinorUnits,
                occurredAt: transaction.occurredAt,
                note: transaction.note,
                attachmentPath: transaction.attachmentPath,
                createdAt: transaction.createdAt,
                updatedAt: transaction.updatedAt,
                displayCurrency: transaction.displayCurrency,
                fxRate: transaction.fxRate
            )
            context.insert(model)
        }

        for transfer in snapshot.transfers {
            let model = AccountTransfer(
                remoteId: transfer.remoteId,
                fromAccountId: transfer.fromAccountId,
                toAccountId: transfer.toAccountId,
                amountFromMinorUnits: transfer.amountFromMinorUnits,
                fxRate: transfer.fxRate,
                amountToMinorUnits: transfer.amountToMinorUnits,
                feeMinorUnits: transfer.feeMinorUnits,
                feeCurrency: transfer.feeCurrency,
                feeChargedOn: transfer.feeChargedOn,
                occurredAt: transfer.occurredAt,
                note: transfer.note,
                createdAt: transfer.createdAt,
                updatedAt: transfer.updatedAt,
                feeTransactionId: transfer.feeTransactionId
            )
            context.insert(model)
        }

        try context.save()
        try refreshAccounts()
        try refreshCustomCategories()
        try refreshTemplates()
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
