//
//  PersonalLedgerModels.swift
//  KuaiJi
//
//  Defines SwiftData models and supporting enums for the personal ledger domain.
//

import Foundation
import SwiftData

// MARK: - Enumerations

enum PersonalAccountType: String, Codable, CaseIterable, Identifiable, Sendable {
    case bankCard
    case mobilePayment
    case cash
    case creditCard
    case prepaid
    case other

    var id: String { rawValue }
}

enum PersonalAccountStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case active
    case archived

    var id: String { rawValue }
}

enum PersonalTransactionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case income
    case expense
    case fee

    var id: String { rawValue }
}

enum PersonalTransferFeeSide: String, Codable, CaseIterable, Identifiable, Sendable {
    case from
    case to

    var id: String { rawValue }
}

enum PersonalFXSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case manual
    case fixed

    var id: String { rawValue }
}

// MARK: - SwiftData Models

@Model
final class PersonalAccount {
    @Attribute(.unique) var remoteId: UUID
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

    init(remoteId: UUID = UUID(),
         name: String,
         type: PersonalAccountType,
         currency: CurrencyCode,
         includeInNetWorth: Bool = true,
         balanceMinorUnits: Int = 0,
         note: String? = nil,
         status: PersonalAccountStatus = .active,
         creditLimitMinorUnits: Int? = nil,
         createdAt: Date = .now,
         updatedAt: Date = .now) {
        self.remoteId = remoteId
        self.name = name
        self.type = type
        self.currency = currency
        self.includeInNetWorth = includeInNetWorth
        self.balanceMinorUnits = balanceMinorUnits
        self.note = note
        self.status = status
        self.creditLimitMinorUnits = creditLimitMinorUnits
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class PersonalTransaction {
    @Attribute(.unique) var remoteId: UUID
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

    init(remoteId: UUID = UUID(),
         kind: PersonalTransactionKind,
         accountId: UUID,
         categoryKey: String,
         amountMinorUnits: Int,
         occurredAt: Date,
         note: String = "",
         attachmentPath: String? = nil,
         createdAt: Date = .now,
         updatedAt: Date = .now,
         displayCurrency: CurrencyCode? = nil,
         fxRate: Decimal? = nil) {
        self.remoteId = remoteId
        self.kind = kind
        self.accountId = accountId
        self.categoryKey = categoryKey
        self.amountMinorUnits = amountMinorUnits
        self.occurredAt = occurredAt
        self.note = note
        self.attachmentPath = attachmentPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.displayCurrency = displayCurrency
        self.fxRate = fxRate
    }
}

@Model
final class AccountTransfer {
    @Attribute(.unique) var remoteId: UUID
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

    init(remoteId: UUID = UUID(),
         fromAccountId: UUID,
         toAccountId: UUID,
         amountFromMinorUnits: Int,
         fxRate: Decimal,
         amountToMinorUnits: Int,
         feeMinorUnits: Int? = nil,
         feeCurrency: CurrencyCode? = nil,
         feeChargedOn: PersonalTransferFeeSide? = nil,
         occurredAt: Date,
         note: String = "",
         createdAt: Date = .now,
         updatedAt: Date = .now,
         feeTransactionId: UUID? = nil) {
        self.remoteId = remoteId
        self.fromAccountId = fromAccountId
        self.toAccountId = toAccountId
        self.amountFromMinorUnits = amountFromMinorUnits
        self.fxRate = fxRate
        self.amountToMinorUnits = amountToMinorUnits
        self.feeMinorUnits = feeMinorUnits
        self.feeCurrency = feeCurrency
        self.feeChargedOn = feeChargedOn
        self.occurredAt = occurredAt
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.feeTransactionId = feeTransactionId
    }
}

@Model
final class PersonalPreferences {
    @Attribute(.unique) var remoteId: UUID
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

    init(remoteId: UUID = UUID(),
         primaryDisplayCurrency: CurrencyCode = .cny,
         fxSource: PersonalFXSource = .manual,
         defaultFXRate: Decimal? = nil,
         fxRates: [CurrencyCode: Decimal] = [:],
         defaultFXPrecision: Int = 4,
         countFeeInStats: Bool = true,
         lastUsedAccountId: UUID? = nil,
         lastUsedCategoryKey: String? = nil,
         defaultFeeCategoryKey: String? = "fees",
         defaultConversionFee: Decimal? = nil,
         lastBackupAt: Date? = nil) {
        self.remoteId = remoteId
        self.primaryDisplayCurrency = primaryDisplayCurrency
        self.fxSource = fxSource
        self.defaultFXRate = defaultFXRate
        self.fxRates = fxRates
        self.defaultFXPrecision = defaultFXPrecision
        self.countFeeInStats = countFeeInStats
        self.lastUsedAccountId = lastUsedAccountId
        self.lastUsedCategoryKey = lastUsedCategoryKey
        self.defaultFeeCategoryKey = defaultFeeCategoryKey
        self.defaultConversionFee = defaultConversionFee
        self.lastBackupAt = lastBackupAt
    }
}
