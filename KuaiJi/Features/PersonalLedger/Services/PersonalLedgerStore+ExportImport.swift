//
//  PersonalLedgerStore+ExportImport.swift
//  KuaiJi
//

import Foundation
import Combine
import SwiftData
import SwiftUI

extension PersonalLedgerStore {
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
}
