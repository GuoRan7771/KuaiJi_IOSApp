//
//  PersistentDataManager.swift
//  KuaiJi
//
//  持久化数据管理器
//

import Foundation
import SwiftData
import Combine

@MainActor
class PersistentDataManager: ObservableObject {
    let modelContext: ModelContext
    
    @Published var currentUser: UserProfile?
    @Published var allLedgers: [Ledger] = []
    @Published var allFriends: [UserProfile] = []
    
    // 用于标识是否已完成首次设置的 UserDefaults key
    private let hasCompletedOnboardingKey = "hasCompletedOnboarding"
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadData()
    }
    
    // MARK: - 首次设置检查
    
    /// 检查是否已完成首次设置
    func hasCompletedOnboarding() -> Bool {
        return UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey)
    }
    
    /// 完成首次设置，创建当前用户
    func completeOnboarding(name: String, emoji: String, currency: CurrencyCode) {
        // 删除可能存在的旧用户（以防万一）
        let oldUserDescriptor = FetchDescriptor<UserProfile>()
        if let oldUsers = try? modelContext.fetch(oldUserDescriptor) {
            for oldUser in oldUsers {
                modelContext.delete(oldUser)
            }
        }
        
        // 创建新用户，生成唯一的用户ID
        let createdAt = Date()
        let userId = UserProfile.generateUserId(name: name, createdAt: createdAt)
        let newUser = UserProfile(
            userId: userId,
            name: name,
            avatarEmoji: emoji,
            localeIdentifier: "zh_CN",
            currency: currency,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        modelContext.insert(newUser)
        try? modelContext.save()
        currentUser = newUser
        
        // 标记已完成设置
        UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
    }
    
    // MARK: - 加载数据
    
    func loadData() {
        // 如果未完成首次设置，不加载用户数据
        guard hasCompletedOnboarding() else {
            currentUser = nil
            allLedgers = []
            allFriends = []
            return
        }
        
        // 加载当前用户（第一个创建的用户）
        let userDescriptor = FetchDescriptor<UserProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        
        if let users = try? modelContext.fetch(userDescriptor), let user = users.first {
            currentUser = user
            
            // 加载所有朋友（除了当前用户）
            let currentUserId = user.remoteId
            let friendDescriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate { friend in
                    friend.remoteId != currentUserId
                },
                sortBy: [SortDescriptor(\.name)]
            )
            allFriends = (try? modelContext.fetch(friendDescriptor)) ?? []
        } else {
            currentUser = nil
            allFriends = []
        }
        
        // 加载所有账本
        let ledgerDescriptor = FetchDescriptor<Ledger>(
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        allLedgers = (try? modelContext.fetch(ledgerDescriptor)) ?? []
    }
    
    // MARK: - 朋友管理
    
    /// 添加朋友（手动输入）
    func addFriend(name: String, emoji: String?, currency: CurrencyCode) {
        // 手动添加时生成userId
        let createdAt = Date()
        let userId = UserProfile.generateUserId(name: name, createdAt: createdAt)
        
        let friend = UserProfile(
            userId: userId,
            name: name,
            avatarEmoji: emoji,
            localeIdentifier: "zh_CN",
            currency: currency,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        modelContext.insert(friend)
        try? modelContext.save()
        loadData()
    }
    
    /// 添加朋友（通过二维码扫描）
    /// 如果朋友已存在，则更新其最新信息（昵称、头像、货币）
    func addFriendFromQRCode(userId: String, name: String, emoji: String?, currency: CurrencyCode) -> Bool {
        // 检查是否是自己
        if let currentUser = currentUser, currentUser.userId == userId {
            return false  // 不能添加自己为朋友
        }
        
        // 检查是否已存在
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { user in
                user.userId == userId
            }
        )
        
        if let existingFriends = try? modelContext.fetch(descriptor), let existingFriend = existingFriends.first {
            // 朋友已存在，更新其最新信息
            existingFriend.name = name
            existingFriend.avatarEmoji = emoji
            existingFriend.currency = currency
            existingFriend.updatedAt = Date()
            
            try? modelContext.save()
            loadData()
            return true  // 更新成功
        }
        
        // 朋友不存在，添加新朋友
        let createdAt = Date()
        let friend = UserProfile(
            userId: userId,
            name: name,
            avatarEmoji: emoji,
            localeIdentifier: "zh_CN",
            currency: currency,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        modelContext.insert(friend)
        try? modelContext.save()
        loadData()
        return true  // 添加成功
    }
    
    func updateFriend(id: UUID, name: String, emoji: String?, currency: CurrencyCode) {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate<UserProfile> { user in
                user.remoteId == id
            }
        )
        
        if let users = try? modelContext.fetch(descriptor), let friend = users.first {
            friend.name = name
            friend.avatarEmoji = emoji
            friend.currency = currency
            friend.updatedAt = Date()
            try? modelContext.save()
            loadData()
        }
    }
    
    func deleteFriend(id: UUID) {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate<UserProfile> { user in
                user.remoteId == id
            }
        )
        
        if let users = try? modelContext.fetch(descriptor), let friend = users.first {
            modelContext.delete(friend)
            try? modelContext.save()
            loadData()
        }
    }
    
    // MARK: - 账本管理
    
    func createLedger(name: String, memberIds: [UUID], currency: CurrencyCode) {
        guard let currentUser = currentUser else { return }
        
        let ledger = Ledger(
            name: name,
            ownerId: currentUser.remoteId,
            currency: currency,
            settings: LedgerSettings(
                defaultCurrency: currency,
                defaultLocale: "zh_CN",
                includePayerInAA: true,
                roundingScale: 2,
                crossCurrencyRule: .forbid
            )
        )
        
        modelContext.insert(ledger)
        
        // 创建成员关系
        for memberId in memberIds {
            let membership = Membership(
                userId: memberId,
                role: memberId == currentUser.remoteId ? .owner : .editor,
                ledger: ledger
            )
            modelContext.insert(membership)
        }
        
        try? modelContext.save()
        loadData()
    }
    
    func deleteLedger(id: UUID) {
        let descriptor = FetchDescriptor<Ledger>(
            predicate: #Predicate<Ledger> { ledger in
                ledger.remoteId == id
            }
        )
        
        if let ledgers = try? modelContext.fetch(descriptor), let ledger = ledgers.first {
            modelContext.delete(ledger)
            try? modelContext.save()
            loadData()
        }
    }
    
    // MARK: - 支出管理
    
    func addExpense(
        ledgerId: UUID,
        payerId: UUID,
        title: String,
        amount: Decimal,
        currency: CurrencyCode,
        date: Date,
        category: ExpenseCategory,
        note: String,
        splitStrategy: SplitStrategy,
        includePayer: Bool,
        participants: [ExpenseParticipantShare]
    ) {
        let descriptor = FetchDescriptor<Ledger>(
            predicate: #Predicate<Ledger> { ledger in
                ledger.remoteId == ledgerId
            }
        )
        
        guard let ledgers = try? modelContext.fetch(descriptor),
              let ledger = ledgers.first else { return }
        
        let amountMinor = SettlementMath.minorUnits(from: amount, scale: 2)
        
        let expense = Expense(
            ledgerId: ledgerId,
            payerId: payerId,
            title: title,
            amountMinorUnits: amountMinor,
            currency: currency,
            date: date,
            note: note,
            category: category,
            metadata: ExpenseMetadata(includePayer: includePayer),
            splitStrategy: splitStrategy,
            ledger: ledger
        )
        
        modelContext.insert(expense)
        
        // 添加参与者
        for participant in participants {
            let expenseParticipant = ExpenseParticipant(
                expenseId: expense.remoteId,
                userId: participant.userId,
                shareType: participant.shareType,
                shareValue: participant.shareValue,
                expense: expense
            )
            modelContext.insert(expenseParticipant)
        }
        
        ledger.updatedAt = Date()
        try? modelContext.save()
        loadData()
    }
    
    // MARK: - 删除支出
    
    func deleteExpense(expenseId: UUID) {
        let descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate<Expense> { expense in
                expense.remoteId == expenseId
            }
        )
        
        guard let expenses = try? modelContext.fetch(descriptor),
              let expense = expenses.first else { return }
        
        // 删除支出（级联删除会自动删除关联的参与者记录）
        modelContext.delete(expense)
        
        // 更新账本的更新时间
        if let ledger = expense.ledger {
            ledger.updatedAt = Date()
        }
        
        try? modelContext.save()
        loadData()
    }
    
    // MARK: - 一键清账
    
    func clearLedgerBalances(ledgerId: UUID) {
        // 1. 获取账本信息
        let ledgerDescriptor = FetchDescriptor<Ledger>(
            predicate: #Predicate<Ledger> { ledger in
                ledger.remoteId == ledgerId
            }
        )
        
        guard let ledgers = try? modelContext.fetch(ledgerDescriptor),
              let ledger = ledgers.first else { return }
        
        // 2. 获取账本的所有支出
        let expenseDescriptor = FetchDescriptor<Expense>(
            predicate: #Predicate<Expense> { expense in
                expense.ledgerId == ledgerId
            }
        )
        
        guard let expenses = try? modelContext.fetch(expenseDescriptor) else { return }
        
        // 3. 将支出转换为 ExpenseInput 格式
        let expenseInputs: [ExpenseInput] = expenses.compactMap { expense in
            let expenseId = expense.remoteId  // 捕获到局部变量
            let participantDescriptor = FetchDescriptor<ExpenseParticipant>(
                predicate: #Predicate<ExpenseParticipant> { participant in
                    participant.expenseId == expenseId
                }
            )
            
            guard let participants = try? modelContext.fetch(participantDescriptor) else { return nil }
            
            let shares = participants.map { participant in
                ExpenseParticipantShare(
                    userId: participant.userId,
                    shareType: participant.shareType,
                    shareValue: participant.shareValue
                )
            }
            
            return ExpenseInput(
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
                participants: shares
            )
        }
        
        // 4. 计算净额
        let settings = LedgerSettings(
            defaultCurrency: ledger.currency,
            defaultLocale: "zh_CN",
            includePayerInAA: true,
            roundingScale: 2,
            crossCurrencyRule: .forbid
        )
        
        guard let netBalances = try? SettlementCalculator.computeNetBalances(
            ledgerCurrency: ledger.currency,
            expenses: expenseInputs,
            settings: settings
        ) else { return }
        
        // 5. 生成转账方案
        let transferPlan = TransferPlanner.greedyMinTransfers(from: netBalances)
        
        // 6. 获取用户信息用于生成标题
        let userDescriptor = FetchDescriptor<UserProfile>()
        let allUsers = (try? modelContext.fetch(userDescriptor)) ?? []
        let userLookup = Dictionary(uniqueKeysWithValues: allUsers.map { ($0.remoteId, $0) })
        
        // 7. 将每笔转账作为支出记录添加到账本
        let now = Date()
        for transfer in transferPlan.transfers {
            let fromUser = userLookup[transfer.from]
            let toUser = userLookup[transfer.to]
            let fromName = fromUser?.name ?? L.defaultUnknown.localized
            let toName = toUser?.name ?? L.defaultUnknown.localized
            let title = String(format: L.defaultClearBalanceTransfer.localized, fromName, toName)
            
            // 创建支出记录：from 付款，to 承担
            // 这样会导致：from 的付款增加，to 的应付增加，从而修正净额
            let settlementExpense = Expense(
                ledgerId: ledgerId,
                payerId: transfer.from,  // 付款人
                title: title,
                amountMinorUnits: transfer.amountMinorUnits,
                currency: ledger.currency,
                date: now,
                note: L.defaultClearBalanceNote.localized,
                category: .other,
                metadata: ExpenseMetadata(includePayer: false),
                splitStrategy: .actorAA,  // 收款人独自承担
                ledger: ledger,
                isSettlement: true  // 标记为清账记录
            )
            
            modelContext.insert(settlementExpense)
            
            // 添加参与者：只有 to，使用 AA 方式独自承担这笔金额
            let participant = ExpenseParticipant(
                expenseId: settlementExpense.remoteId,
                userId: transfer.to,  // 收款人承担
                shareType: .aa,  // 使用 AA 类型，让 to 承担这笔金额
                shareValue: nil,
                expense: settlementExpense
            )
            
            modelContext.insert(participant)
        }
        
        // 8. 更新账本的更新时间
        ledger.updatedAt = Date()
        
        try? modelContext.save()
        loadData()
    }
    
    // MARK: - 获取账本成员
    
    func getLedgerMembers(ledgerId: UUID) -> [UserProfile] {
        let descriptor = FetchDescriptor<Membership>(
            predicate: #Predicate<Membership> { membership in
                membership.ledger?.remoteId == ledgerId
            }
        )
        
        guard let memberships = try? modelContext.fetch(descriptor) else { return [] }
        
        let userIds = memberships.map { $0.userId }
        
        let userDescriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate<UserProfile> { user in
                userIds.contains(user.remoteId)
            }
        )
        
        return (try? modelContext.fetch(userDescriptor)) ?? []
    }
    
    // MARK: - 更新用户信息
    
    func updateUserProfile(name: String, emoji: String, currency: CurrencyCode) {
        guard let user = currentUser else { return }
        
        user.name = name
        user.avatarEmoji = emoji
        user.currency = currency
        user.updatedAt = Date()
        
        try? modelContext.save()
        loadData()
    }
    
    // MARK: - 数据同步辅助方法
    
    func getLedgerExpenses(ledgerId: UUID) -> [Expense] {
        let ledgerId = ledgerId
        let descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate<Expense> { expense in
                expense.ledgerId == ledgerId
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func getExpenseParticipants(expenseId: UUID) -> [ExpenseParticipant] {
        let expenseId = expenseId
        let descriptor = FetchDescriptor<ExpenseParticipant>(
            predicate: #Predicate<ExpenseParticipant> { participant in
                participant.expenseId == expenseId
            }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func expenseExists(expenseId: UUID) -> Bool {
        let expenseId = expenseId
        let descriptor = FetchDescriptor<Expense>(
            predicate: #Predicate<Expense> { expense in
                expense.remoteId == expenseId
            }
        )
        let expenses = (try? modelContext.fetch(descriptor)) ?? []
        return !expenses.isEmpty
    }
    
    func createLedgerFromSync(
        ledgerId: UUID,
        name: String,
        memberIds: [UUID],
        currency: CurrencyCode,
        createdAt: Date,
        updatedAt: Date
    ) {
        let ledger = Ledger(
            remoteId: ledgerId,
            name: name,
            ownerId: memberIds.first ?? UUID(),
            currency: currency,
            createdAt: createdAt,
            updatedAt: updatedAt,
            settings: LedgerSettings(defaultCurrency: currency)
        )
        modelContext.insert(ledger)
        
        // 获取所有用户（包括当前用户和朋友）
        let userDescriptor = FetchDescriptor<UserProfile>()
        let allUsers = (try? modelContext.fetch(userDescriptor)) ?? []
        
        // 创建成员关系，并关联到对应的UserProfile
        for memberId in memberIds {
            // 查找对应的UserProfile
            let userProfile = allUsers.first { $0.remoteId == memberId }
            
            let membership = Membership(
                userId: memberId,
                role: memberId == memberIds.first ? .owner : .editor,
                ledger: ledger,
                user: userProfile  // 关联UserProfile
            )
            modelContext.insert(membership)
        }
        
        try? modelContext.save()
        loadData()
    }
    
    func addExpenseFromSync(
        expenseId: UUID,
        ledgerId: UUID,
        payerId: UUID,
        title: String,
        amount: Decimal,
        currency: CurrencyCode,
        date: Date,
        category: ExpenseCategory,
        note: String,
        splitStrategy: SplitStrategy,
        includePayer: Bool,
        participants: [ExpenseParticipantShare],
        isSettlement: Bool,
        createdAt: Date,
        updatedAt: Date
    ) {
        let ledgerId = ledgerId
        let ledgerDescriptor = FetchDescriptor<Ledger>(
            predicate: #Predicate<Ledger> { ledger in
                ledger.remoteId == ledgerId
            }
        )
        
        guard let ledgers = try? modelContext.fetch(ledgerDescriptor),
              let ledger = ledgers.first else { return }
        
        let amountMinor = SettlementMath.minorUnits(from: amount, scale: 2)
        
        let expense = Expense(
            remoteId: expenseId,
            ledgerId: ledgerId,
            payerId: payerId,
            title: title,
            amountMinorUnits: amountMinor,
            currency: currency,
            date: date,
            note: note,
            category: category,
            createdAt: createdAt,
            updatedAt: updatedAt,
            metadata: ExpenseMetadata(includePayer: includePayer),
            splitStrategy: splitStrategy,
            ledger: ledger,
            isSettlement: isSettlement
        )
        
        modelContext.insert(expense)
        
        for participant in participants {
            let expenseParticipant = ExpenseParticipant(
                expenseId: expenseId,
                userId: participant.userId,
                shareType: participant.shareType,
                shareValue: participant.shareValue,
                expense: expense
            )
            modelContext.insert(expenseParticipant)
        }
        
        try? modelContext.save()
        loadData()
    }
    
    // MARK: - 清除所有数据
    
    func clearAllData() {
        // 删除所有账本（级联删除会处理相关数据）
        let ledgerDescriptor = FetchDescriptor<Ledger>()
        if let allLedgers = try? modelContext.fetch(ledgerDescriptor) {
            for ledger in allLedgers {
                modelContext.delete(ledger)
            }
        }
        
        // 删除所有用户（包括当前用户和朋友）
        let userDescriptor = FetchDescriptor<UserProfile>()
        if let allUsers = try? modelContext.fetch(userDescriptor) {
            for user in allUsers {
                modelContext.delete(user)
            }
        }
        
        try? modelContext.save()
        
        // 重置首次设置标记
        UserDefaults.standard.set(false, forKey: hasCompletedOnboardingKey)
        
        // 清空内存中的数据
        currentUser = nil
        allLedgers = []
        allFriends = []
    }
}

