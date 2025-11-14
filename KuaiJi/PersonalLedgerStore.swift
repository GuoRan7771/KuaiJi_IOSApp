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
    case cannotHideAllCategories

    var errorDescription: String? {
        switch self {
        case .accountNotFound: return "Account not found".localized
        case .transactionNotFound: return "Transaction not found".localized
        case .transferNotFound: return "Transfer not found".localized
        case .amountMustBePositive: return L.errorAmountMustBePositive.localized
        case .categoryRequired: return "Category is required".localized
        case .accountRequired: return L.errorAccountRequired.localized
        case .cannotDeleteNonEmptyAccount: return "Balance must be zero before deletion".localized
        case .duplicateAccountName: return "Account name already exists".localized
        case .nameRequired: return "Account name is required".localized
        case .sameTransferAccount: return "Source and target accounts must differ".localized
        case .invalidExchangeRate: return "Exchange rate must be greater than zero".localized
        case .invalidFeeSide: return "Fee side is required when fee exists".localized
        case .invalidFeeCurrency: return "Fee currency does not match account".localized
        case .cannotHideAllCategories: return L.personalCategoryHideError.localized
        }
    }
}

// MARK: - Export Snapshot Models

struct PersonalLedgerSnapshot: Codable {
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
        var sharedCategoryMappings: [String: String]

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
            self.sharedCategoryMappings = preferences.sharedCategoryMappings
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

    struct Category: Codable {
        var remoteId: UUID
        var key: String
        var name: String
        var localizationKey: String?
        var iconName: String
        var colorHex: String?
        var kind: PersonalTransactionKind
        var isSystem: Bool
        var isHidden: Bool
        var sortIndex: Int
        var createdAt: Date
        var updatedAt: Date

        init(from category: PersonalCategory) {
            self.remoteId = category.remoteId
            self.key = category.key
            self.name = category.name
            self.localizationKey = category.localizationKey
            self.iconName = category.iconName
            self.colorHex = category.colorHex
            self.kind = category.kind
            self.isSystem = category.isSystem
            self.isHidden = category.isHidden
            self.sortIndex = category.sortIndex
            self.createdAt = category.createdAt
            self.updatedAt = category.updatedAt
        }
    }

    struct StatsGroup: Codable {
        var remoteId: UUID
        var name: String
        var colorHex: String?
        var kind: PersonalTransactionKind
        var role: PersonalStatsGroupRole
        var isVisibleByDefault: Bool
        var sortIndex: Int
        var categoryKeys: [String]
        var createdAt: Date
        var updatedAt: Date

        init(from group: PersonalStatsGroup) {
            self.remoteId = group.remoteId
            self.name = group.name
            self.colorHex = group.colorHex
            self.kind = group.kind
            self.role = group.role
            self.isVisibleByDefault = group.isVisibleByDefault
            self.sortIndex = group.sortIndex
            self.categoryKeys = group.categoryKeys
            self.createdAt = group.createdAt
            self.updatedAt = group.updatedAt
        }
    }

    var preferences: Preferences
    var accounts: [Account]
    var transactions: [Transaction]
    var transfers: [Transfer]
    var categories: [Category]
    var statsGroups: [StatsGroup] = []
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
    @Published private(set) var categories: [PersonalCategory] = []
    @Published private(set) var statsGroups: [PersonalStatsGroup] = []

    private static let defaultEssentialCategoryKeys: [String] = [
        "food",
        "transport",
        "accommodation",
        "utilities",
        "medical",
        // legacy keys for backward compatibility
        "housing",
        "health",
        "education"
    ]

    private static let defaultDiscretionaryCategoryKeys: [String] = {
        let essential = Set(defaultEssentialCategoryKeys)
        return PersonalCategorySeedCatalog.expense
            .map { $0.key }
            .filter { !essential.contains($0) }
    }()

    private static let defaultEssentialColorHex = "#6750A4"
    private static let defaultDiscretionaryColorHex = "#F76D57"

    init(context: ModelContext, defaultCurrency: CurrencyCode = .cny, calendar: Calendar = .current) throws {
        self.context = context
        self.calendar = calendar
        self.recoveryDefaultCurrency = defaultCurrency
        self.preferences = try PersonalLedgerStore.ensurePreferences(in: context, defaultCurrency: defaultCurrency)
        try refreshAccounts()
        try refreshCategories()
        try ensureDefaultCategories()
        try refreshStatsGroups()
        try pruneInvalidCategoryAssignments()
        try ensureDefaultStatsGroups()
        try repairLegacyStatsGroupAssignmentsIfNeeded()
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

    func sharedCategoryMapping(for key: String) -> ExpenseCategory? {
        ensurePreferencesConsistency()
        guard let raw = preferences.sharedCategoryMappings[key] else { return nil }
        return ExpenseCategory(rawValue: raw)
    }

    func setSharedCategoryMapping(for key: String, to category: ExpenseCategory) throws {
        ensurePreferencesConsistency()
        preferences.sharedCategoryMappings[key] = category.rawValue
        try context.save()
    }

    func removeSharedCategoryMapping(for key: String) throws {
        ensurePreferencesConsistency()
        if preferences.sharedCategoryMappings.removeValue(forKey: key) != nil {
            try context.save()
        }
    }

    // MARK: - Categories

    func refreshCategories() throws {
        let descriptor = FetchDescriptor<PersonalCategory>(
            sortBy: [
                SortDescriptor(\.sortIndex, order: .forward),
                SortDescriptor(\.createdAt, order: .forward)
            ])
        categories = try context.fetch(descriptor)
        if categories.isEmpty {
            try ensureDefaultCategories()
            return
        }
        try backfillCategoryKindsIfNeeded()
        try pruneInvalidCategoryAssignments()
    }

    private func ensureDefaultCategories() throws {
        let existingKeys = Set(categories.map { $0.key })
        var didInsert = false
        for (index, seed) in PersonalCategorySeedCatalog.all.enumerated() {
            guard !existingKeys.contains(seed.key) else { continue }
            let category = PersonalCategory(key: seed.key,
                                            name: seed.displayName,
                                            localizationKey: seed.localizationKey,
                                            iconName: seed.systemImage,
                                            colorHex: seed.colorHex,
                                            kind: seed.kind,
                                            isSystem: true,
                                            sortIndex: index)
            context.insert(category)
            didInsert = true
        }
        if didInsert {
            try context.save()
            try refreshCategories()
        }
        try normalizeCategorySortOrder()
    }

    private func normalizeCategorySortOrder() throws {
        var didChange = false
        for kind in PersonalTransactionKind.allCases {
            let filtered = categories
                .filter { $0.kind == kind }
                .sorted {
                    if $0.sortIndex == $1.sortIndex {
                        return $0.createdAt < $1.createdAt
                    }
                    return $0.sortIndex < $1.sortIndex
                }
            for (idx, category) in filtered.enumerated() {
                if category.sortIndex != idx {
                    category.sortIndex = idx
                    category.updatedAt = Date.now
                    didChange = true
                }
            }
        }
        if didChange {
            try context.save()
            try refreshCategories()
        }
    }

    private func backfillCategoryKindsIfNeeded() throws {
        var didUpdate = false
        for category in categories where category.needsKindBackfill {
            let fallback: PersonalTransactionKind
            if let seed = PersonalCategorySeedCatalog.all.first(where: { $0.key == category.key }) {
                fallback = seed.kind
            } else {
                fallback = .expense
            }
            category.backfillKindIfNeeded(defaultKind: fallback)
            didUpdate = true
        }
        if didUpdate {
            try context.save()
            categories = try context.fetch(FetchDescriptor(
                sortBy: [
                    SortDescriptor(\.sortIndex, order: .forward),
                    SortDescriptor(\.createdAt, order: .forward)
                ]))
        }
    }

    func categories(for kind: PersonalTransactionKind, includeHidden: Bool = false) -> [PersonalCategory] {
        categories
            .filter { $0.kind == kind && (includeHidden || !$0.isHidden) }
            .sorted { lhs, rhs in
                if lhs.sortIndex == rhs.sortIndex {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.sortIndex < rhs.sortIndex
            }
    }

    // MARK: - Stats Groups

    func refreshStatsGroups() throws {
        let descriptor = FetchDescriptor<PersonalStatsGroup>(
            sortBy: [
                SortDescriptor(\.sortIndex, order: .forward),
                SortDescriptor(\.createdAt, order: .forward)
            ])
        statsGroups = try context.fetch(descriptor)
    }

    private func repairLegacyStatsGroupAssignmentsIfNeeded() throws {
        let defaults = UserDefaults.standard
        let flag = "LegacyStatsGroupCategoryFixApplied"
        guard !defaults.bool(forKey: flag) else { return }
        let descriptor = FetchDescriptor<PersonalStatsGroup>()
        let groups = try context.fetch(descriptor)
        guard !groups.isEmpty else {
            defaults.set(true, forKey: flag)
            return
        }
        for group in groups {
            let keys = group.categoryKeys
            group.categoryKeys = keys.map { $0 }
        }
        if context.hasChanges {
            try context.save()
        }
        defaults.set(true, forKey: flag)
    }

    private func ensureDefaultStatsGroups() throws {
        guard statsGroups.isEmpty else { return }
        let essential = PersonalStatsGroup(name: L.personalStatsEssential.localized,
                                           colorHex: Self.defaultEssentialColorHex,
                                           isVisibleByDefault: true,
                                           sortIndex: 0,
                                           kind: .expense,
                                           role: .essential,
                                           categoryKeys: Self.defaultEssentialCategoryKeys)
        let discretionary = PersonalStatsGroup(name: L.personalStatsDiscretionary.localized,
                                               colorHex: Self.defaultDiscretionaryColorHex,
                                               isVisibleByDefault: true,
                                               sortIndex: 1,
                                               kind: .expense,
                                               role: .discretionary,
                                               categoryKeys: Self.defaultDiscretionaryCategoryKeys)
        context.insert(essential)
        context.insert(discretionary)
        try context.save()
        try refreshStatsGroups()
    }

    private func pruneInvalidCategoryAssignments() throws {
        guard !statsGroups.isEmpty else { return }
        let validMap = Dictionary(grouping: categories, by: { $0.kind })
            .mapValues { Set($0.map(\.key)) }
        var didChange = false
        for group in statsGroups {
            let validKeys = validMap[group.kind] ?? []
            let filtered = group.categoryKeys.filter { validKeys.contains($0) }
            if filtered.count != group.categoryKeys.count {
                group.categoryKeys = filtered
                group.updatedAt = Date.now
                didChange = true
            }
        }
        if didChange {
            try context.save()
            try refreshStatsGroups()
        }
    }

    func statsGroups(for kind: PersonalTransactionKind) -> [PersonalStatsGroup] {
        statsGroups
            .filter { $0.kind == kind }
            .sorted {
                if $0.sortIndex == $1.sortIndex {
                    return $0.createdAt < $1.createdAt
                }
                return $0.sortIndex < $1.sortIndex
            }
    }

    func createStatsGroup(name: String,
                          colorHex: String?,
                          kind: PersonalTransactionKind,
                          role: PersonalStatsGroupRole = .custom,
                          categoryKeys: [String]) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PersonalLedgerError.nameRequired }
        let resolvedRole: PersonalStatsGroupRole = kind == .expense ? role : .custom
        let normalizedKeys = normalizeCategoryKeys(categoryKeys, for: kind)
        let sortIndex = statsGroups(for: kind).count
        let group = PersonalStatsGroup(name: trimmed,
                                       colorHex: sanitizedColorHex(colorHex),
                                       isVisibleByDefault: true,
                                       sortIndex: sortIndex,
                                       kind: kind,
                                       role: resolvedRole,
                                       categoryKeys: normalizedKeys)
        context.insert(group)
        try context.save()
        try refreshStatsGroups()
    }

    func updateStatsGroup(id: UUID,
                          name: String,
                          colorHex: String?,
                          categoryKeys: [String],
                          role: PersonalStatsGroupRole) throws {
        guard let group = try findStatsGroup(by: id) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PersonalLedgerError.nameRequired }
        group.name = trimmed
        group.colorHex = sanitizedColorHex(colorHex)
        let normalizedRole: PersonalStatsGroupRole = group.kind == .expense ? role : .custom
        group.role = normalizedRole
        group.categoryKeys = normalizeCategoryKeys(categoryKeys, for: group.kind)
        group.updatedAt = Date.now
        try context.save()
        try refreshStatsGroups()
    }

    func deleteStatsGroup(id: UUID) throws {
        guard let group = try findStatsGroup(by: id) else { return }
        context.delete(group)
        try context.save()
        try refreshStatsGroups()
    }

    private func findStatsGroup(by id: UUID) throws -> PersonalStatsGroup? {
        let predicate = #Predicate<PersonalStatsGroup> { $0.remoteId == id }
        var descriptor = FetchDescriptor<PersonalStatsGroup>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func normalizeCategoryKeys(_ keys: [String], for kind: PersonalTransactionKind) -> [String] {
        let valid = Set(categories.filter { $0.kind == kind }.map { $0.key })
        var seen: Set<String> = []
        var result: [String] = []
        for key in keys {
            guard valid.contains(key), !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(key)
        }
        return result
    }

    private func sanitizedColorHex(_ input: String?) -> String? {
        guard var text = input?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        if !text.hasPrefix("#") {
            text = "#\(text)"
        }
        return text
    }

    func defaultCategoryKey(for kind: PersonalTransactionKind) -> String {
        if let first = categories(for: kind).first {
            return first.key
        }
        return PersonalCategorySeedCatalog.defaultKey(for: kind)
    }

    func categoryExists(key: String, kind: PersonalTransactionKind) -> Bool {
        categories.contains { $0.key == key && $0.kind == kind }
    }

    func isSystemCategory(key: String) -> Bool {
        categories.first(where: { $0.key == key })?.isSystem ?? false
    }

    func createCustomCategory(name: String, iconName: String, colorHex: String?, kind: PersonalTransactionKind) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PersonalLedgerError.nameRequired }
        let key = "custom.\(UUID().uuidString)"
        let sortIndex = categories(for: kind, includeHidden: true).count
        let category = PersonalCategory(key: key,
                                        name: trimmed,
                                        localizationKey: nil,
                                        iconName: iconName,
                                        colorHex: colorHex,
                                        kind: kind,
                                        isSystem: false,
                                        sortIndex: sortIndex)
        context.insert(category)
        try context.save()
        try refreshCategories()
    }

    func updateCustomCategory(id: UUID, name: String, iconName: String, colorHex: String?) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PersonalLedgerError.nameRequired }
        guard let category = try findCategory(by: id), !category.isSystem else { return }
        category.name = trimmed
        category.iconName = iconName
        category.colorHex = colorHex
        category.updatedAt = Date.now
        try context.save()
        try refreshCategories()
    }

    func setCategory(_ id: UUID, hidden: Bool) throws {
        guard let category = try findCategory(by: id) else { return }
        if hidden {
            let visible = categories(for: category.kind).filter { $0.remoteId != id }
            guard !visible.isEmpty else { throw PersonalLedgerError.cannotHideAllCategories }
        }
        category.isHidden = hidden
        category.updatedAt = Date.now
        try context.save()
        try refreshCategories()
    }

    func deleteCustomCategory(id: UUID) throws {
        guard let category = try findCategory(by: id), !category.isSystem else { return }
        let candidates = categories(for: category.kind).filter { $0.key != category.key }
        let fallbackKey = candidates.first?.key ?? PersonalCategorySeedCatalog.defaultKey(for: category.kind)
        try reassignTransactions(from: category.key, to: fallbackKey)
        try removeSharedCategoryMapping(for: category.key)
        context.delete(category)
        try context.save()
        try refreshCategories()
    }

    func reorderCategories(kind: PersonalTransactionKind, orderedIds: [UUID]) throws {
        let map = Dictionary(uniqueKeysWithValues: categories(for: kind, includeHidden: true).map { ($0.remoteId, $0) })
        for (idx, id) in orderedIds.enumerated() {
            if let category = map[id], category.sortIndex != idx {
                category.sortIndex = idx
                category.updatedAt = Date.now
            }
        }
        try context.save()
        try refreshCategories()
    }

    private func findCategory(by id: UUID) throws -> PersonalCategory? {
        let predicate = #Predicate<PersonalCategory> { $0.remoteId == id }
        var descriptor = FetchDescriptor<PersonalCategory>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func reassignTransactions(from key: String, to fallback: String) throws {
        guard key != fallback else { return }
        let predicate = #Predicate<PersonalTransaction> { $0.categoryKey == key }
        let descriptor = FetchDescriptor<PersonalTransaction>(predicate: predicate)
        let results = try context.fetch(descriptor)
        guard !results.isEmpty else { return }
        for transaction in results {
            transaction.categoryKey = fallback
            transaction.updatedAt = Date.now
        }
        try context.save()
    }

    func resolvedCategoryName(for key: String) -> String {
        if let category = categories.first(where: { $0.key == key }) {
            return category.displayName
        }
        if let seed = PersonalCategorySeedCatalog.all.first(where: { $0.key == key }) {
            return seed.displayName
        }
        return key
    }

    func resolvedCategoryIcon(for key: String) -> String {
        if let category = categories.first(where: { $0.key == key }) {
            return category.iconName
        }
        return iconForCategory(key: key)
    }

    func resolvedCategoryColorHex(for key: String) -> String? {
        if let category = categories.first(where: { $0.key == key }) {
            return category.colorHex
        }
        if let seed = PersonalCategorySeedCatalog.all.first(where: { $0.key == key }) {
            return seed.colorHex
        }
        return nil
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
        try refreshCategories()
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
        let categories = try context.fetch(FetchDescriptor<PersonalCategory>())
        for category in categories {
            context.delete(category)
        }
        let groups = try context.fetch(FetchDescriptor<PersonalStatsGroup>())
        for group in groups {
            context.delete(group)
        }
        statsGroups = []
        preferences.lastUsedAccountId = nil
        preferences.lastUsedCategoryKey = nil
        preferences.fxRates = [:]
        preferences.sharedCategoryMappings = [:]
        try context.save()
        try refreshAccounts()
        try refreshCategories()
        try refreshStatsGroups()
        try ensureDefaultStatsGroups()
    }

    // MARK: - Export / Import Snapshot

    func exportSnapshot() throws -> PersonalLedgerSnapshot {
        let accountDescriptor = FetchDescriptor<PersonalAccount>()
        let transactionDescriptor = FetchDescriptor<PersonalTransaction>()
        let transferDescriptor = FetchDescriptor<AccountTransfer>()
        let categoryDescriptor = FetchDescriptor<PersonalCategory>()
        let groupDescriptor = FetchDescriptor<PersonalStatsGroup>()

        let accounts = try context.fetch(accountDescriptor)
        let transactions = try context.fetch(transactionDescriptor)
        let transfers = try context.fetch(transferDescriptor)
        let categories = try context.fetch(categoryDescriptor)
        let groups = try context.fetch(groupDescriptor)

        let snapshot = PersonalLedgerSnapshot(
            preferences: .init(from: preferences),
            accounts: accounts.map(PersonalLedgerSnapshot.Account.init(from:)),
            transactions: transactions.map(PersonalLedgerSnapshot.Transaction.init(from:)),
            transfers: transfers.map(PersonalLedgerSnapshot.Transfer.init(from:)),
            categories: categories.map(PersonalLedgerSnapshot.Category.init(from:)),
            statsGroups: groups.map(PersonalLedgerSnapshot.StatsGroup.init(from:))
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
            prefs.sharedCategoryMappings = snapshot.preferences.sharedCategoryMappings
        }

        for category in snapshot.categories {
            let model = PersonalCategory(remoteId: category.remoteId,
                                         key: category.key,
                                         name: category.name,
                                         localizationKey: category.localizationKey,
                                         iconName: category.iconName,
                                         colorHex: category.colorHex,
                                         kind: category.kind,
                                         isSystem: category.isSystem,
                                         isHidden: category.isHidden,
                                         sortIndex: category.sortIndex,
                                         createdAt: category.createdAt,
                                         updatedAt: category.updatedAt)
            context.insert(model)
        }

        for group in snapshot.statsGroups {
            let model = PersonalStatsGroup(remoteId: group.remoteId,
                                           name: group.name,
                                           colorHex: group.colorHex,
                                           isVisibleByDefault: group.isVisibleByDefault,
                                           sortIndex: group.sortIndex,
                                           createdAt: group.createdAt,
                                           updatedAt: group.updatedAt,
                                           kind: group.kind,
                                           role: group.role,
                                           categoryKeys: group.categoryKeys)
            context.insert(model)
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
        try refreshCategories()
        try refreshStatsGroups()
        try ensureDefaultStatsGroups()
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
