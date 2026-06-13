//
//  SyncModels.swift
//  KuaiJi
//
//  数据同步模型定义
//

import Foundation

// MARK: - 同步数据包

struct SyncPackage: Codable {
    var version: String = "1.2"
    // 消息去重与防 Ping-Pong
    var exchangeId: UUID = UUID()      // 本次交换的唯一ID
    var replyTo: UUID? = nil           // 若为响应，指向请求的 exchangeId
    var senderUserId: String  // 发送方的唯一用户ID
    var senderName: String    // 发送方姓名（用于显示）
    // 新增：发送方资料（可选，兼容旧版本）
    var senderAvatarEmoji: String? = nil
    var senderCurrency: CurrencyCode? = nil
    var timestamp: Date
    var ledgers: [SyncLedger]
}

struct SyncLedger: Codable {
    var ledgerId: UUID
    var ledgerName: String
    var currency: CurrencyCode
    var createdAt: Date
    var updatedAt: Date
    var expenses: [SyncExpense]
    var members: [SyncUserProfile]  // 账本所有成员的信息
}

struct SyncExpense: Codable {
    var remoteId: UUID
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
    var splitStrategy: SplitStrategy
    var isSettlement: Bool
    var metadata: ExpenseMetadata
    var participants: [SyncParticipant]
}

// 兼容旧版本字段缺失的自定义解码
extension SyncExpense {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        remoteId = try container.decode(UUID.self, forKey: .remoteId)
        ledgerId = try container.decode(UUID.self, forKey: .ledgerId)
        payerId = try container.decode(UUID.self, forKey: .payerId)
        title = try container.decode(String.self, forKey: .title)
        amountMinorUnits = try container.decode(Int.self, forKey: .amountMinorUnits)
        currency = try container.decode(CurrencyCode.self, forKey: .currency)
        date = try container.decode(Date.self, forKey: .date)
        note = try container.decode(String.self, forKey: .note)
        category = try container.decode(ExpenseCategory.self, forKey: .category)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        splitStrategy = try container.decode(SplitStrategy.self, forKey: .splitStrategy)
        // isSettlement 在更早版本可能缺失，缺省为 false
        isSettlement = (try? container.decode(Bool.self, forKey: .isSettlement)) ?? false
        metadata = try container.decode(ExpenseMetadata.self, forKey: .metadata)
        participants = try container.decode([SyncParticipant].self, forKey: .participants)
    }
}

struct SyncParticipant: Codable {
    var userId: UUID
    var shareType: ShareType
    var shareValue: Decimal?
    var actualShareMinorUnits: Int?  // 实际分摊金额（包含四舍五入后的结果）
}

struct SyncUserProfile: Codable {
    var userId: String  // 唯一用户ID
    var remoteId: UUID
    var name: String
    var avatarEmoji: String?
    var currency: CurrencyCode
}

// MARK: - 同步结果

struct SyncResult {
    var addedLedgers: Int = 0
    var updatedLedgers: Int = 0
    var addedExpenses: Int = 0
    var addedFriends: Int = 0
    var errors: [String] = []
    
    var isSuccess: Bool {
        return errors.isEmpty
    }
    
    var summary: String {
        var lines: [String] = []
        if addedLedgers > 0 { lines.append(L.syncResultAddedLedgers.localized(addedLedgers)) }
        if updatedLedgers > 0 { lines.append(L.syncResultUpdatedLedgers.localized(updatedLedgers)) }
        if addedExpenses > 0 { lines.append(L.syncResultAddedExpenses.localized(addedExpenses)) }
        if addedFriends > 0 { lines.append(L.syncResultAddedFriends.localized(addedFriends)) }
        if !errors.isEmpty { lines.append(L.syncResultErrors.localized(errors.count)) }
        return lines.isEmpty ? L.syncResultNoUpdates.localized : lines.joined(separator: "\n")
    }
}

