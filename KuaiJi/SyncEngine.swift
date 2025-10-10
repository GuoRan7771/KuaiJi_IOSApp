//
//  SyncEngine.swift
//  KuaiJi
//
//  数据同步引擎 - 处理账本和支出的同步逻辑
//

import Foundation
import SwiftData

@MainActor
struct SyncEngine {
    
    // MARK: - 准备同步数据
    
    static func prepareSyncData(
        from dataManager: PersistentDataManager,
        currentUserId: String
    ) -> SyncPackage? {
        guard let currentUser = dataManager.currentUser else { 
            return nil 
        }
        
        
        var syncLedgers: [SyncLedger] = []
        
        // 遍历所有账本
        for ledger in dataManager.allLedgers {
            let members = dataManager.getLedgerMembers(ledgerId: ledger.remoteId)
            
            members.forEach { member in
            }
            
            // 检查当前用户是否是该账本的成员（使用 remoteId 比较更可靠）
            let isMember = members.contains(where: { $0.remoteId == currentUser.remoteId })
            
            
            guard isMember else {
                continue  // 跳过不相关的账本
            }
            
            
            // 获取账本的所有支出（排除清账记录）
            let expenses = dataManager.getLedgerExpenses(ledgerId: ledger.remoteId)
                .filter { $0.isSettlement != true }  // 不同步清账记录
            
            
            // 转换为同步格式
            let syncExpenses = expenses.map { expense -> SyncExpense in
                let participants = dataManager.getExpenseParticipants(expenseId: expense.remoteId)
                
                // 计算实际的分摊金额（避免重新计算导致不一致）
                let expenseInput = ExpenseInput(
                    id: expense.remoteId,
                    ledgerId: expense.ledgerId,
                    payerId: expense.payerId,
                    title: expense.title,
                    note: expense.note,
                    category: expense.category,
                    amountMinorUnits: expense.amountMinorUnits,
                    currency: expense.currency,
                    date: expense.date,
                    splitStrategy: expense.splitStrategy,
                    metadata: expense.metadata,
                    participants: participants.map { p in
                        ExpenseParticipantShare(userId: p.userId, shareType: p.shareType, shareValue: p.shareValue)
                    },
                    isSettlement: expense.isSettlement == true
                )
                
                // 使用SettlementCalculator计算实际分摊
                let settings = LedgerSettings(defaultCurrency: ledger.currency)
                let actualShares = (try? SettlementCalculator.shareDistribution(
                    for: expenseInput,
                    convertedTotalMinor: expense.amountMinorUnits,
                    includePayer: expense.metadata.includePayer ?? true,
                    converter: CurrencyConverter(ledgerCurrency: ledger.currency, rule: .forbid, scale: 2),
                    settings: settings
                )) ?? [:]
                let syncParticipants = participants.map { participant in
                    SyncParticipant(
                        userId: participant.userId,
                        shareType: participant.shareType,
                        shareValue: participant.shareValue,
                        actualShareMinorUnits: actualShares[participant.userId]
                    )
                }
                
                return SyncExpense(
                    remoteId: expense.remoteId,
                    ledgerId: expense.ledgerId,
                    payerId: expense.payerId,
                    title: expense.title,
                    amountMinorUnits: expense.amountMinorUnits,
                    currency: expense.currency,
                    date: expense.date,
                    note: expense.note,
                    category: expense.category,
                    createdAt: expense.createdAt,
                    updatedAt: expense.updatedAt,
                    splitStrategy: expense.splitStrategy,
                    isSettlement: expense.isSettlement == true,
                    metadata: expense.metadata,
                    participants: syncParticipants
                )
            }
            
            // 转换成员信息
            let syncMembers = members.compactMap { member -> SyncUserProfile? in
                // 只同步有 userId 的成员（过滤掉自建朋友）
                guard !member.userId.isEmpty else { return nil }
                
                return SyncUserProfile(
                    userId: member.userId,
                    remoteId: member.remoteId,
                    name: member.name,
                    avatarEmoji: member.avatarEmoji,
                    currency: member.currency
                )
            }
            
            let syncLedger = SyncLedger(
                ledgerId: ledger.remoteId,
                ledgerName: ledger.name,
                currency: ledger.currency,
                createdAt: ledger.createdAt,
                updatedAt: ledger.updatedAt,
                expenses: syncExpenses,
                members: syncMembers
            )
            
            syncLedgers.append(syncLedger)
        }
        
        return SyncPackage(
            senderUserId: currentUserId,
            senderName: currentUser.name,
            senderAvatarEmoji: currentUser.avatarEmoji,
            senderCurrency: currentUser.currency,
            timestamp: Date(),
            ledgers: syncLedgers
        )
    }
    
    // MARK: - 合并同步数据
    
    static func mergeSyncData(
        _ syncPackage: SyncPackage,
        into dataManager: PersistentDataManager,
        currentUserId: String
    ) -> SyncResult {
        var result = SyncResult()
        
        
        guard let currentUser = dataManager.currentUser else {
            return result
        }

        // 0. 与发送方互加/更新好友（如果不是自己）
        if syncPackage.senderUserId != currentUser.userId {
            let senderExists = dataManager.allFriends.contains { $0.userId == syncPackage.senderUserId }
            // 使用对方提供的资料；若缺失币种则回退为本机当前用户币种
            let senderCurrency = syncPackage.senderCurrency ?? currentUser.currency
            let didAddOrUpdate = dataManager.addFriendFromQRCode(
                userId: syncPackage.senderUserId,
                name: syncPackage.senderName,
                emoji: syncPackage.senderAvatarEmoji,
                currency: senderCurrency
            )
            if didAddOrUpdate && !senderExists {
                result.addedFriends += 1
            }
        }
        
        for syncLedger in syncPackage.ledgers {
            syncLedger.members.forEach { member in
            }
            
            // 检查账本是否包含当前用户（使用 userId 字符串比较）
            let includesCurrentUser = syncLedger.members.contains { $0.userId == currentUser.userId }
            
            
            guard includesCurrentUser else {
                continue
            }
            
            
            // 1. 添加缺失的朋友
            var friendsAdded = false
            for member in syncLedger.members {
                // 跳过自己
                guard member.userId != currentUserId else { continue }
                
                // 检查朋友是否已存在（基于 userId）
                let friendExists = dataManager.allFriends.contains { $0.userId == member.userId }
                
                // 无论是否已存在，都调用带更新逻辑的方法；存在则更新资料，不存在则新增
                let didAddOrUpdate = dataManager.addFriendFromQRCode(
                    userId: member.userId,
                    name: member.name,
                    emoji: member.avatarEmoji,
                    currency: member.currency
                )
                if didAddOrUpdate && !friendExists {
                    result.addedFriends += 1
                    friendsAdded = true
                }
            }
            
            // 如果添加了新朋友，需要重新加载以确保后续逻辑能找到这些朋友
            if friendsAdded {
                dataManager.loadData()
            }
            
            // 创建成员映射表：同步数据中的remoteId → 本地的remoteId
            var memberMapping: [UUID: UUID] = [:]
            for syncMember in syncLedger.members {
                if syncMember.userId == currentUser.userId {
                    // 当前用户
                    memberMapping[syncMember.remoteId] = currentUser.remoteId
                } else {
                    // 朋友用户
                    if let friend = dataManager.allFriends.first(where: { $0.userId == syncMember.userId }) {
                        memberMapping[syncMember.remoteId] = friend.remoteId
                    } else {
                    }
                }
            }
            
            // 2. 检查账本是否存在
            let ledgerExists = dataManager.allLedgers.contains { $0.remoteId == syncLedger.ledgerId }
            
            if ledgerExists {
                // 账本已存在，合并支出记录
                let addedCount = mergeExpenses(syncLedger.expenses, into: dataManager, memberMapping: memberMapping)
                result.addedExpenses += addedCount
                if addedCount > 0 {
                    result.updatedLedgers += 1
                }
            } else {
                // 账本不存在，创建新账本
                let (success, mapping) = createLedgerFromSync(syncLedger, into: dataManager, currentUserId: currentUserId)
                if success {
                    result.addedLedgers += 1
                    // 创建账本后，使用返回的映射来添加支出
                    let expenseCount = addExpensesWithMapping(syncLedger.expenses, into: dataManager, memberMapping: mapping)
                    result.addedExpenses += expenseCount
                } else {
                    result.errors.append("创建账本失败: \(syncLedger.ledgerName)")
                }
            }
        }
        
        return result
    }
    
    // MARK: - 私有辅助方法
    
    private static func mergeExpenses(_ syncExpenses: [SyncExpense], into dataManager: PersistentDataManager, memberMapping: [UUID: UUID]) -> Int {
        var addedCount = 0
        
        for syncExpense in syncExpenses {
            // 检查支出是否已存在（基于 remoteId）
            let exists = dataManager.expenseExists(expenseId: syncExpense.remoteId)
            
            if !exists {
                // 映射payerId到本地UUID
                let localPayerId = memberMapping[syncExpense.payerId] ?? syncExpense.payerId
                
                
                // 映射参与者UUID到本地UUID，并使用实际分摊金额
                let participants = syncExpense.participants.map { participant in
                    let localUserId = memberMapping[participant.userId] ?? participant.userId
                    
                    // 使用实际分摊金额，避免重新计算导致不一致
                    if let actualShare = participant.actualShareMinorUnits {
                        let shareDecimal = SettlementMath.decimal(fromMinorUnits: actualShare, scale: 2)
                        return ExpenseParticipantShare(
                            userId: localUserId,
                            shareType: .custom,  // 使用custom类型
                            shareValue: shareDecimal  // 精确的分摊金额
                        )
                    } else {
                        return ExpenseParticipantShare(
                            userId: localUserId,
                            shareType: participant.shareType,
                            shareValue: participant.shareValue
                        )
                    }
                }
                
                dataManager.addExpenseFromSync(
                    expenseId: syncExpense.remoteId,
                    ledgerId: syncExpense.ledgerId,
                    payerId: localPayerId,  // 使用映射后的本地UUID
                    title: syncExpense.title,
                    amount: SettlementMath.decimal(fromMinorUnits: syncExpense.amountMinorUnits, scale: 2),
                    currency: syncExpense.currency,
                    date: syncExpense.date,
                    category: syncExpense.category,
                    note: syncExpense.note,
                    splitStrategy: syncExpense.splitStrategy,
                    includePayer: syncExpense.metadata.includePayer ?? true,
                    participants: participants,
                    isSettlement: syncExpense.isSettlement,
                    createdAt: syncExpense.createdAt,
                    updatedAt: syncExpense.updatedAt
                )
                
                addedCount += 1
            }
        }
        
        return addedCount
    }
    
    private static func createLedgerFromSync(
        _ syncLedger: SyncLedger,
        into dataManager: PersistentDataManager,
        currentUserId: String
    ) -> (success: Bool, memberMapping: [UUID: UUID]) {
        
        guard let currentUser = dataManager.currentUser else {
            return (false, [:])
        }
        
        // 映射成员：将同步数据中的remoteId转换为本地的remoteId
        var memberIds: [UUID] = []
        var memberMapping: [UUID: UUID] = [:]
        
        for syncMember in syncLedger.members {
            // 查找本地对应的用户
            if syncMember.userId == currentUser.userId {
                // 当前用户
                memberIds.append(currentUser.remoteId)
                memberMapping[syncMember.remoteId] = currentUser.remoteId
            } else {
                // 朋友用户 - 通过userId查找
                if let friend = dataManager.allFriends.first(where: { $0.userId == syncMember.userId }) {
                    memberIds.append(friend.remoteId)
                    memberMapping[syncMember.remoteId] = friend.remoteId
                } else {
                    // 理论上不应该走到这里，因为之前应该已经添加过朋友了
                    memberIds.append(syncMember.remoteId)
                    memberMapping[syncMember.remoteId] = syncMember.remoteId
                }
            }
        }
        
        guard !memberIds.isEmpty else {
            return (false, [:])
        }
        
        
        // 创建账本（使用原始ID和时间戳）
        dataManager.createLedgerFromSync(
            ledgerId: syncLedger.ledgerId,
            name: syncLedger.ledgerName,
            memberIds: memberIds,
            currency: syncLedger.currency,
            createdAt: syncLedger.createdAt,
            updatedAt: syncLedger.updatedAt
        )
        
        
        return (true, memberMapping)
    }
    
    private static func addExpensesWithMapping(
        _ syncExpenses: [SyncExpense],
        into dataManager: PersistentDataManager,
        memberMapping: [UUID: UUID]
    ) -> Int {
        var addedCount = 0
        
        for syncExpense in syncExpenses {
            // 映射payerId到本地UUID
            let localPayerId = memberMapping[syncExpense.payerId] ?? syncExpense.payerId
            
            
            // 映射参与者UUID到本地UUID，并使用实际分摊金额
            let participants = syncExpense.participants.map { participant in
                let localUserId = memberMapping[participant.userId] ?? participant.userId
                
                // 使用实际分摊金额，避免重新计算导致不一致
                if let actualShare = participant.actualShareMinorUnits {
                    let shareDecimal = SettlementMath.decimal(fromMinorUnits: actualShare, scale: 2)
                    return ExpenseParticipantShare(
                        userId: localUserId,
                        shareType: .custom,  // 使用custom类型
                        shareValue: shareDecimal  // 精确的分摊金额
                    )
                } else {
                    return ExpenseParticipantShare(
                        userId: localUserId,
                        shareType: participant.shareType,
                        shareValue: participant.shareValue
                    )
                }
            }
            
            dataManager.addExpenseFromSync(
                expenseId: syncExpense.remoteId,
                ledgerId: syncExpense.ledgerId,
                payerId: localPayerId,
                title: syncExpense.title,
                amount: SettlementMath.decimal(fromMinorUnits: syncExpense.amountMinorUnits, scale: 2),
                currency: syncExpense.currency,
                date: syncExpense.date,
                category: syncExpense.category,
                note: syncExpense.note,
                splitStrategy: syncExpense.splitStrategy,
                includePayer: syncExpense.metadata.includePayer ?? true,
                participants: participants,
                isSettlement: syncExpense.isSettlement,
                createdAt: syncExpense.createdAt,
                updatedAt: syncExpense.updatedAt
            )
            
            addedCount += 1
        }
        
        return addedCount
    }
}

