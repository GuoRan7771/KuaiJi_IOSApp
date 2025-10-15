//
//  DomainModels.swift
//  KuaiJi
//
//  Created for shared ledger architecture and settlement algorithms.
//

import Foundation
import SwiftData

// MARK: - Enumerations & Value Types

enum CurrencyCode: String, Codable, CaseIterable, Identifiable, Sendable {
    case eur = "EUR"
    case usd = "USD"
    case cny = "CNY"
    case gbp = "GBP"
    case hkd = "HKD"
    case jpy = "JPY"

    var id: String { rawValue }
}

struct Money: Codable, Hashable, Sendable {
    var currency: CurrencyCode
    /// Stored in minor units (e.g., cents). Guarantees 0.01 precision.
    var minorUnits: Int

    init(currency: CurrencyCode, minorUnits: Int) {
        self.currency = currency
        self.minorUnits = minorUnits
    }

    init(currency: CurrencyCode, amount: Decimal) {
        self.currency = currency
        self.minorUnits = SettlementMath.minorUnits(from: amount, scale: 2)
    }

    var decimalValue: Decimal { SettlementMath.decimal(fromMinorUnits: minorUnits, scale: 2) }
}

enum LedgerRole: String, Codable, CaseIterable, Sendable {
    case owner
    case editor
    case viewer
}

enum ShareType: String, Codable, CaseIterable, Sendable {
    case aa
    case weight
    case custom
    case treat
}

enum SplitStrategy: String, Codable, CaseIterable, Sendable {
    case payerTreat
    case actorTreat
    case payerAA
    case actorAA
    case weighted
    case custom
    case fixedPlusEqual
    case helpPay  // 谁帮谁付（代付/垫付）
}

enum ExpenseCategory: String, Codable, CaseIterable, Sendable {
    case food
    case transport
    case accommodation
    case entertainment
    case utilities
    case selfImprovement
    case school
    case medical
    case clothing
    case investment
    case social
    case other
}

enum CrossCurrencyRuleMode: String, Codable, Sendable {
    case forbid
    case fixedRate
}

struct CrossCurrencyRule: Codable, Hashable, Sendable {
    var mode: CrossCurrencyRuleMode
    /// Mapping from expense currency to ledger currency conversion rate.
    var rates: [CurrencyCode: Decimal]

    nonisolated static let forbid = CrossCurrencyRule(mode: .forbid, rates: [:])
}

struct LedgerSettings: Codable, Hashable, Sendable {
    var defaultCurrency: CurrencyCode
    var defaultLocale: String
    var includePayerInAA: Bool
    var roundingScale: Int
    var crossCurrencyRule: CrossCurrencyRule

    nonisolated init(defaultCurrency: CurrencyCode = .eur,
                     defaultLocale: String = "fr_FR",
                     includePayerInAA: Bool = false,
                     roundingScale: Int = 2,
                     crossCurrencyRule: CrossCurrencyRule = .forbid) {
        self.defaultCurrency = defaultCurrency
        self.defaultLocale = defaultLocale
        self.includePayerInAA = includePayerInAA
        self.roundingScale = roundingScale
        self.crossCurrencyRule = crossCurrencyRule
    }
}

extension LedgerSettings {
    private enum CodingKeys: String, CodingKey {
        case defaultCurrency, defaultLocale, includePayerInAA, roundingScale, crossCurrencyRule
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaultCurrency = try container.decode(CurrencyCode.self, forKey: .defaultCurrency)
        let defaultLocale = try container.decode(String.self, forKey: .defaultLocale)
        let includePayerInAA = try container.decode(Bool.self, forKey: .includePayerInAA)
        let roundingScale = try container.decode(Int.self, forKey: .roundingScale)
        let crossCurrencyRule = try container.decode(CrossCurrencyRule.self, forKey: .crossCurrencyRule)
        self.init(defaultCurrency: defaultCurrency,
                  defaultLocale: defaultLocale,
                  includePayerInAA: includePayerInAA,
                  roundingScale: roundingScale,
                  crossCurrencyRule: crossCurrencyRule)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(defaultCurrency, forKey: .defaultCurrency)
        try container.encode(defaultLocale, forKey: .defaultLocale)
        try container.encode(includePayerInAA, forKey: .includePayerInAA)
        try container.encode(roundingScale, forKey: .roundingScale)
        try container.encode(crossCurrencyRule, forKey: .crossCurrencyRule)
    }
}

struct ExpenseMetadata: Codable, Hashable, Sendable {
    var includePayer: Bool?
    var location: String?
    var tags: [String]
    var tipMinorUnits: Int
    var taxMinorUnits: Int

    nonisolated init(includePayer: Bool? = nil,
                     location: String? = nil,
                     tags: [String] = [],
                     tipMinorUnits: Int = 0,
                     taxMinorUnits: Int = 0) {
        self.includePayer = includePayer
        self.location = location
        self.tags = tags
        self.tipMinorUnits = tipMinorUnits
        self.taxMinorUnits = taxMinorUnits
    }
}

extension ExpenseMetadata {
    private enum CodingKeys: String, CodingKey {
        case includePayer, location, tags, tipMinorUnits, taxMinorUnits
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let includePayer = try container.decodeIfPresent(Bool.self, forKey: .includePayer)
        let location = try container.decodeIfPresent(String.self, forKey: .location)
        let tags = try container.decode([String].self, forKey: .tags)
        let tipMinorUnits = try container.decode(Int.self, forKey: .tipMinorUnits)
        let taxMinorUnits = try container.decode(Int.self, forKey: .taxMinorUnits)
        self.init(includePayer: includePayer,
                  location: location,
                  tags: tags,
                  tipMinorUnits: tipMinorUnits,
                  taxMinorUnits: taxMinorUnits)
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(includePayer, forKey: .includePayer)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encode(tags, forKey: .tags)
        try container.encode(tipMinorUnits, forKey: .tipMinorUnits)
        try container.encode(taxMinorUnits, forKey: .taxMinorUnits)
    }
}

// MARK: - SwiftData Models

@Model
final class UserProfile {
    @Attribute(.unique) var remoteId: UUID
    @Attribute(.unique) var userId: String  // 唯一用户ID：昵称_时间戳，创建后不可修改
    var name: String
    var avatarEmoji: String?
    var localeIdentifier: String
    var currency: CurrencyCode
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Membership.user) var memberships: [Membership]

    init(remoteId: UUID = UUID(),
         userId: String,
         name: String,
         avatarEmoji: String? = nil,
         localeIdentifier: String,
         currency: CurrencyCode,
         createdAt: Date = .now,
         updatedAt: Date = .now) {
        self.remoteId = remoteId
        self.userId = userId
        self.name = name
        self.avatarEmoji = avatarEmoji
        self.localeIdentifier = localeIdentifier
        self.currency = currency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.memberships = []
    }
    
    /// 生成用户ID：昵称_时间戳
    static func generateUserId(name: String, createdAt: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let timestamp = formatter.string(from: createdAt)
        return "\(name)_\(timestamp)"
    }
}

@Model
final class Ledger {
    @Attribute(.unique) var remoteId: UUID
    var name: String
    var ownerId: UUID
    var currency: CurrencyCode
    var createdAt: Date
    var updatedAt: Date
    var settings: LedgerSettings

    @Relationship(deleteRule: .cascade, inverse: \Membership.ledger) var memberships: [Membership]
    @Relationship(deleteRule: .cascade, inverse: \Expense.ledger) var expenses: [Expense]
    @Relationship(deleteRule: .cascade, inverse: \BalanceSnapshot.ledger) var balanceSnapshots: [BalanceSnapshot]
    @Relationship(deleteRule: .cascade, inverse: \TransferPlan.ledger) var transferPlans: [TransferPlan]

    init(remoteId: UUID = UUID(),
         name: String,
         ownerId: UUID,
         currency: CurrencyCode,
         createdAt: Date = .now,
         updatedAt: Date = .now,
         settings: LedgerSettings = LedgerSettings()) {
        self.remoteId = remoteId
        self.name = name
        self.ownerId = ownerId
        self.currency = currency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.settings = settings
        self.memberships = []
        self.expenses = []
        self.balanceSnapshots = []
        self.transferPlans = []
    }
}

@Model
final class Membership {
    @Attribute(.unique) var remoteId: UUID
    var userId: UUID
    var role: LedgerRole
    var joinedAt: Date

    @Relationship var ledger: Ledger?
    @Relationship var user: UserProfile?

    init(remoteId: UUID = UUID(),
         userId: UUID,
         role: LedgerRole,
         joinedAt: Date = .now,
         ledger: Ledger? = nil,
         user: UserProfile? = nil) {
        self.remoteId = remoteId
        self.userId = userId
        self.role = role
        self.joinedAt = joinedAt
        self.ledger = ledger
        self.user = user
    }
}

@Model
final class Expense {
    @Attribute(.unique) var remoteId: UUID
    var ledgerId: UUID
    var payerId: UUID
    var title: String
    var amountMinorUnits: Int
    var currency: CurrencyCode
    var date: Date
    var note: String
    var category: ExpenseCategory
    var createdAt: Date
    var updatedAt: Date
    var metadata: ExpenseMetadata
    var splitStrategy: SplitStrategy
    var isSettlement: Bool?  // 标记是否为清账记录（可选，以支持数据迁移）

    @Relationship(deleteRule: .cascade, inverse: \ExpenseParticipant.expense) var participants: [ExpenseParticipant]
    @Relationship var ledger: Ledger?

    init(remoteId: UUID = UUID(),
         ledgerId: UUID,
         payerId: UUID,
         title: String,
         amountMinorUnits: Int,
         currency: CurrencyCode,
         date: Date,
         note: String = "",
         category: ExpenseCategory = .other,
         createdAt: Date = .now,
         updatedAt: Date = .now,
         metadata: ExpenseMetadata = ExpenseMetadata(),
         splitStrategy: SplitStrategy,
         ledger: Ledger? = nil,
         isSettlement: Bool = false) {
        self.remoteId = remoteId
        self.ledgerId = ledgerId
        self.payerId = payerId
        self.title = title
        self.amountMinorUnits = amountMinorUnits
        self.currency = currency
        self.date = date
        self.note = note
        self.category = category
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        self.splitStrategy = splitStrategy
        self.participants = []
        self.ledger = ledger
        self.isSettlement = isSettlement ? true : nil  // nil 表示 false，true 表示是清账记录
    }
}

@Model
final class ExpenseParticipant {
    @Attribute(.unique) var remoteId: UUID
    var expenseId: UUID
    var userId: UUID
    var shareType: ShareType
    /// Currency amount for custom share or weight value; nil when not applicable.
    var shareValue: Decimal?

    @Relationship var expense: Expense?

    init(remoteId: UUID = UUID(),
         expenseId: UUID,
         userId: UUID,
         shareType: ShareType,
         shareValue: Decimal? = nil,
         expense: Expense? = nil) {
        self.remoteId = remoteId
        self.expenseId = expenseId
        self.userId = userId
        self.shareType = shareType
        self.shareValue = shareValue
        self.expense = expense
    }
}

@Model
final class BalanceSnapshot {
    @Attribute(.unique) var remoteId: UUID
    var ledgerId: UUID
    var userId: UUID
    var netMinorUnits: Int
    var capturedAt: Date

    @Relationship var ledger: Ledger?

    init(remoteId: UUID = UUID(), ledgerId: UUID, userId: UUID, netMinorUnits: Int, capturedAt: Date = .now, ledger: Ledger? = nil) {
        self.remoteId = remoteId
        self.ledgerId = ledgerId
        self.userId = userId
        self.netMinorUnits = netMinorUnits
        self.capturedAt = capturedAt
        self.ledger = ledger
    }
}

@Model
final class TransferPlan {
    @Attribute(.unique) var remoteId: UUID
    var ledgerId: UUID
    var fromUserId: UUID
    var toUserId: UUID
    var amountMinorUnits: Int
    var createdAt: Date

    @Relationship var ledger: Ledger?

    init(remoteId: UUID = UUID(), ledgerId: UUID, fromUserId: UUID, toUserId: UUID, amountMinorUnits: Int, createdAt: Date = .now, ledger: Ledger? = nil) {
        self.remoteId = remoteId
        self.ledgerId = ledgerId
        self.fromUserId = fromUserId
        self.toUserId = toUserId
        self.amountMinorUnits = amountMinorUnits
        self.createdAt = createdAt
        self.ledger = ledger
    }
}

@Model
final class AuditLog {
    @Attribute(.unique) var remoteId: UUID
    var entity: String
    var entityId: UUID
    var actorId: UUID
    var diffJSON: Data
    var happenedAt: Date

    init(remoteId: UUID = UUID(), entity: String, entityId: UUID, actorId: UUID, diffJSON: Data, happenedAt: Date = .now) {
        self.remoteId = remoteId
        self.entity = entity
        self.entityId = entityId
        self.actorId = actorId
        self.diffJSON = diffJSON
        self.happenedAt = happenedAt
    }
}

// MARK: - Settlement Logic

enum SettlementError: LocalizedError, Equatable {
    case crossCurrencyDisabled(expenseCurrency: CurrencyCode)
    case missingExchangeRate(expenseCurrency: CurrencyCode)
    case invalidShares(message: String)
    case emptyParticipants

    var errorDescription: String? {
        switch self {
        case .crossCurrencyDisabled(let currency):
            return "Currency \(currency.rawValue) is not allowed for this ledger."
        case .missingExchangeRate(let currency):
            return "Missing fixed exchange rate for \(currency.rawValue)."
        case .invalidShares(let message):
            return "Invalid expense shares: \(message)."
        case .emptyParticipants:
            return "Expense has no participants."
        }
    }
    static func == (lhs: SettlementError, rhs: SettlementError) -> Bool {
        switch (lhs, rhs) {
        case (.crossCurrencyDisabled(let a), .crossCurrencyDisabled(let b)): return a == b
        case (.missingExchangeRate(let a), .missingExchangeRate(let b)): return a == b
        case (.invalidShares(let a), .invalidShares(let b)): return a == b
        case (.emptyParticipants, .emptyParticipants): return true
        default: return false
        }
    }
}

struct ExpenseParticipantShare: Hashable, Sendable {
    var userId: UUID
    var shareType: ShareType
    var shareValue: Decimal?

    init(userId: UUID, shareType: ShareType, shareValue: Decimal? = nil) {
        self.userId = userId
        self.shareType = shareType
        self.shareValue = shareValue
    }
}

struct ExpenseInput: Hashable, Sendable {
    var id: UUID
    var ledgerId: UUID
    var payerId: UUID
    var title: String
    var note: String
    var category: ExpenseCategory
    var amountMinorUnits: Int
    var currency: CurrencyCode
    var date: Date
    var splitStrategy: SplitStrategy
    var metadata: ExpenseMetadata
    var participants: [ExpenseParticipantShare]
    var isSettlement: Bool  // 标记是否为清账记录
    
    // 计算属性：判断是否为清账记录
    var isSettlementRecord: Bool {
        return isSettlement
    }

    init(id: UUID = UUID(),
         ledgerId: UUID,
         payerId: UUID,
         title: String,
         note: String = "",
         category: ExpenseCategory = .other,
         amountMinorUnits: Int,
         currency: CurrencyCode,
         date: Date,
         splitStrategy: SplitStrategy,
         metadata: ExpenseMetadata = ExpenseMetadata(),
         participants: [ExpenseParticipantShare],
         isSettlement: Bool = false) {
        self.id = id
        self.ledgerId = ledgerId
        self.payerId = payerId
        self.title = title
        self.note = note
        self.category = category
        self.amountMinorUnits = amountMinorUnits
        self.currency = currency
        self.date = date
        self.splitStrategy = splitStrategy
        self.metadata = metadata
        self.participants = participants
        self.isSettlement = isSettlement
    }
}

struct TransferRecord: Identifiable, Hashable, Sendable {
    var id: UUID = UUID()
    var from: UUID
    var to: UUID
    var amountMinorUnits: Int
}

struct TransferPlanResult: Hashable, Sendable {
    var transfers: [TransferRecord]

    var totalMinorUnits: Int {
        transfers.reduce(0) { $0 + $1.amountMinorUnits }
    }
}

struct CurrencyConverter {
    let ledgerCurrency: CurrencyCode
    let rule: CrossCurrencyRule
    let scale: Int

    func convertToLedger(amount: Decimal, from currency: CurrencyCode) throws -> Decimal {
        if currency == ledgerCurrency { return amount }
        switch rule.mode {
        case .forbid:
            throw SettlementError.crossCurrencyDisabled(expenseCurrency: currency)
        case .fixedRate:
            guard let rate = rule.rates[currency] else {
                throw SettlementError.missingExchangeRate(expenseCurrency: currency)
            }
            return amount * rate
        }
    }

    func convertToLedger(minorUnits: Int, from currency: CurrencyCode) throws -> Int {
        let decimalAmount = SettlementMath.decimal(fromMinorUnits: minorUnits, scale: scale)
        let converted = try convertToLedger(amount: decimalAmount, from: currency)
        return SettlementMath.minorUnits(from: converted, scale: scale)
    }
}

enum SettlementCalculator {
    static func computeNetBalances(ledgerCurrency: CurrencyCode,
                                   expenses: [ExpenseInput],
                                   settings: LedgerSettings) throws -> [UUID: Int] {
        guard !expenses.isEmpty else { return [:] }
        let converter = CurrencyConverter(ledgerCurrency: ledgerCurrency,
                                          rule: settings.crossCurrencyRule,
                                          scale: settings.roundingScale)
        var net: [UUID: Int] = [:]
        for expense in expenses {
            guard !expense.participants.isEmpty else { throw SettlementError.emptyParticipants }
            
            // 检查是否为"请客"交易：所有参与者的 shareType 都是 .treat
            let isTreatTransaction = expense.participants.allSatisfy { $0.shareType == .treat }
            
            // 请客交易不改变余额，仅记录流水
            if isTreatTransaction {
                continue
            }
            
            let includePayer = expense.metadata.includePayer ?? settings.includePayerInAA
            let totalMinor = try converter.convertToLedger(minorUnits: expense.amountMinorUnits + expense.metadata.tipMinorUnits + expense.metadata.taxMinorUnits,
                                                           from: expense.currency)
            net[expense.payerId, default: 0] += totalMinor
            let shares = try shareDistribution(for: expense,
                                               convertedTotalMinor: totalMinor,
                                               includePayer: includePayer,
                                               converter: converter,
                                               settings: settings)
            for (userId, amount) in shares {
                net[userId, default: 0] -= amount
            }
        }
        return net.filter { $0.value != 0 }
    }

    static func shareDistribution(for expense: ExpenseInput,
                                   convertedTotalMinor: Int,
                                   includePayer: Bool,
                                   converter: CurrencyConverter,
                                   settings: LedgerSettings) throws -> [UUID: Int] {
        let scale = settings.roundingScale
        let totalDecimal = SettlementMath.decimal(fromMinorUnits: convertedTotalMinor, scale: scale)
        var customTotal = Decimal(0)
        var variableParticipants: [(id: UUID, weight: Decimal)] = []
        var provisional: [UUID: Decimal] = [:]

        for participant in expense.participants {
            switch participant.shareType {
            case .custom:
                guard let value = participant.shareValue else {
                    throw SettlementError.invalidShares(message: "Missing custom value for participant")
                }
                let converted = try converter.convertToLedger(amount: value, from: expense.currency)
                provisional[participant.userId, default: Decimal(0)] += converted
                customTotal += converted
            case .weight:
                guard let weight = participant.shareValue, weight > 0 else {
                    throw SettlementError.invalidShares(message: "Weight must be > 0")
                }
                variableParticipants.append((participant.userId, weight))
            case .aa:
                if participant.userId == expense.payerId && !includePayer {
                    provisional[participant.userId, default: Decimal(0)] = Decimal(0)
                } else {
                    variableParticipants.append((participant.userId, Decimal(1)))
                }
            case .treat:
                provisional[participant.userId, default: Decimal(0)] = Decimal(0)
            }
        }

        if customTotal > totalDecimal + Decimal(0.0001) {
            throw SettlementError.invalidShares(message: "Custom shares exceed total amount")
        }

        let remainder = max(totalDecimal - customTotal, Decimal(0))
        if remainder > 0 {
            let totalWeight = variableParticipants.reduce(Decimal(0)) { $0 + $1.weight }
            guard totalWeight > 0 else {
                throw SettlementError.invalidShares(message: "No participants available to consume remainder")
            }
            for entry in variableParticipants {
                let proportionalShare = remainder * entry.weight / totalWeight
                provisional[entry.id, default: Decimal(0)] += proportionalShare
            }
        }

        let rounded = SettlementMath.roundAndDistribute(original: provisional,
                                                         targetMinorUnits: convertedTotalMinor,
                                                         scale: scale,
                                                         expenseId: expense.id)

        // Ensure every declared participant has an entry.
        var result = rounded
        for participant in expense.participants {
            if result[participant.userId] == nil {
                result[participant.userId] = 0
            }
        }
        return result
    }
}

enum TransferPlanner {
    static func greedyMinTransfers(from netBalances: [UUID: Int]) -> TransferPlanResult {
        struct BalanceItem { var userId: UUID; var amount: Int }
        var creditors: [BalanceItem] = netBalances.compactMap { (key, value) in
            value > 0 ? BalanceItem(userId: key, amount: value) : nil
        }.sorted { $0.amount > $1.amount }

        var debtors: [BalanceItem] = netBalances.compactMap { (key, value) in
            value < 0 ? BalanceItem(userId: key, amount: -value) : nil
        }.sorted { $0.amount > $1.amount }

        var transfers: [TransferRecord] = []
        var creditorIndex = 0
        var debtorIndex = 0

        while creditorIndex < creditors.count && debtorIndex < debtors.count {
            var creditor = creditors[creditorIndex]
            var debtor = debtors[debtorIndex]
            let settlement = min(creditor.amount, debtor.amount)
            if settlement > 0 {
                let record = TransferRecord(from: debtor.userId, to: creditor.userId, amountMinorUnits: settlement)
                if let last = transfers.last, last.from == record.from, last.to == record.to {
                    transfers[transfers.count - 1].amountMinorUnits += settlement
                } else {
                    transfers.append(record)
                }
            }
            creditor.amount -= settlement
            debtor.amount -= settlement

            if creditor.amount == 0 {
                creditorIndex += 1
            } else {
                creditors[creditorIndex].amount = creditor.amount
            }

            if debtor.amount == 0 {
                debtorIndex += 1
            } else {
                debtors[debtorIndex].amount = debtor.amount
            }
        }

        return TransferPlanResult(transfers: transfers)
    }
}

// MARK: - Math Helpers

enum SettlementMath {
    static func pow10(_ exponent: Int) -> Decimal {
        guard exponent > 0 else { return Decimal(1) }
        return (0..<exponent).reduce(Decimal(1)) { value, _ in value * Decimal(10) }
    }

    static func decimal(fromMinorUnits minor: Int, scale: Int) -> Decimal {
        let factor = pow10(scale)
        return Decimal(minor) / factor
    }

    static func minorUnits(from value: Decimal, scale: Int) -> Int {
        let factor = pow10(scale)
        var scaled = value * factor
        var rounded = Decimal()
        NSDecimalRound(&rounded, &scaled, 0, .plain)
        return (rounded as NSDecimalNumber).intValue
    }

    static func roundDecimal(_ value: Decimal, scale: Int) -> Decimal {
        var mutable = value
        var result = Decimal()
        NSDecimalRound(&result, &mutable, scale, .plain)
        return result
    }

    static func roundAndDistribute(original: [UUID: Decimal], targetMinorUnits: Int, scale: Int, expenseId: UUID) -> [UUID: Int] {
        var rounded: [UUID: Int] = [:]
        for (key, value) in original {
            let roundedValue = roundDecimal(value, scale: scale)
            rounded[key] = minorUnits(from: roundedValue, scale: scale)
        }

        let currentTotal = rounded.values.reduce(0, +)
        var diff = targetMinorUnits - currentTotal
        if diff == 0 { return rounded }

        // 按UUID字母顺序排序，确保稳定性
        let sortedByUserId = original.sorted { lhs, rhs in
            lhs.key.uuidString < rhs.key.uuidString
        }

        guard !sortedByUserId.isEmpty else { return rounded }
        
        // 使用expenseId的UUID字节值来计算起始索引，确保不同支出的余额轮流分配给不同参与者
        // 将UUID转换为字节数组，对所有字节求和，然后取模
        var uuidBytes: [UInt8] = []
        withUnsafeBytes(of: expenseId.uuid) { bytes in
            uuidBytes = Array(bytes)
        }
        let byteSum = uuidBytes.reduce(0) { Int($0) + Int($1) }
        let startIndex = byteSum % sortedByUserId.count
        var index = startIndex
        
        while diff != 0 {
            let target = sortedByUserId[index % sortedByUserId.count].key
            if diff > 0 {
                rounded[target, default: 0] += 1
                diff -= 1
            } else {
                rounded[target, default: 0] -= 1
                diff += 1
            }
            index += 1
        }
        return rounded
    }
}

