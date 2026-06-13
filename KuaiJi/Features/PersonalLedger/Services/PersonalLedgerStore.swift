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

@MainActor
final class PersonalLedgerStore: ObservableObject {
    let context: ModelContext
    let calendar: Calendar
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

    func transactionCount(forCategoryKey key: String) throws -> Int {
        let predicate = #Predicate<PersonalTransaction> { $0.categoryKey == key }
        let descriptor = FetchDescriptor<PersonalTransaction>(predicate: predicate)
        return try context.fetchCount(descriptor)
    }

    func reassignTransactions(from oldKey: String, to newKey: String) throws {
        let predicate = #Predicate<PersonalTransaction> { $0.categoryKey == oldKey }
        let descriptor = FetchDescriptor<PersonalTransaction>(predicate: predicate)
        let transactions = try context.fetch(descriptor)
        for transaction in transactions {
            transaction.categoryKey = newKey
            transaction.updatedAt = Date.now
        }
        try context.save()
        objectWillChange.send()
    }

    func transactionCount(forCategoryId id: UUID) throws -> Int {
        guard let category = try findCategory(by: id) else { return 0 }
        return try transactionCount(forCategoryKey: category.key)
    }

    func reassignTransactions(fromCategoryId id: UUID, toCategoryKey newKey: String) throws {
        guard let category = try findCategory(by: id) else { return }
        try reassignTransactions(from: category.key, to: newKey)
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


    func currency(for accountId: UUID) -> CurrencyCode {
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
}
