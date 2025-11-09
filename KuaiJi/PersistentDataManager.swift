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
        let localeIdentifier = LocaleManager.preferredLocaleIdentifier ?? Locale.current.identifier
        let newUser = UserProfile(
            userId: userId,
            name: name,
            avatarEmoji: emoji,
            localeIdentifier: localeIdentifier,
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
        
        let localeIdentifier = currentUser?.localeIdentifier ?? LocaleManager.preferredLocaleIdentifier ?? Locale.current.identifier
        let friend = UserProfile(
            userId: userId,
            name: name,
            avatarEmoji: emoji,
            localeIdentifier: localeIdentifier,
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
        let localeIdentifier = currentUser?.localeIdentifier ?? LocaleManager.preferredLocaleIdentifier ?? Locale.current.identifier
        let friend = UserProfile(
            userId: userId,
            name: name,
            avatarEmoji: emoji,
            localeIdentifier: localeIdentifier,
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
        let ownerId = currentUser?.remoteId
        // 删除所有账本（级联删除会处理相关数据）
        let ledgerDescriptor = FetchDescriptor<Ledger>()
        if let allLedgers = try? modelContext.fetch(ledgerDescriptor) {
            for ledger in allLedgers {
                modelContext.delete(ledger)
            }
        }
        
        // 删除所有朋友信息（保留当前用户资料）
        if let ownerId {
            let friendDescriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate<UserProfile> { user in
                    user.remoteId != ownerId
                }
            )
            if let friends = try? modelContext.fetch(friendDescriptor) {
                for friend in friends {
                    modelContext.delete(friend)
                }
            }
        }
        
        try? modelContext.save()
        
        // 重新加载数据以更新内存状态
        loadData()
    }
    
    // MARK: - 数据导出/导入
    
    func exportSnapshot() -> ExportData? {
        guard let currentUser = currentUser else { return nil }

        let allUsersDescriptor = FetchDescriptor<UserProfile>()
        let allLedgersDescriptor = FetchDescriptor<Ledger>()

        guard let users = try? modelContext.fetch(allUsersDescriptor),
              let ledgers = try? modelContext.fetch(allLedgersDescriptor) else {
            return nil
        }

        return ExportData(
            version: "1.0",
            exportDate: Date(),
            currentUserId: currentUser.remoteId,
            hasCompletedOnboarding: hasCompletedOnboarding(),
            users: users.map { ExportUserProfile(from: $0) },
            ledgers: ledgers.map { ExportLedger(from: $0) }
        )
    }

    /// 导出所有数据到 JSON 文件
    func exportAllData() -> URL? {
        guard let exportData = exportSnapshot() else { return nil }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let jsonData = try? encoder.encode(exportData) else {
            return nil
        }

        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "KuaiJi_Backup_\(timestamp).json"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        do {
            try jsonData.write(to: tempURL)
            return tempURL
        } catch {
            debugLog("❌ 导出数据失败:", error)
            return nil
        }
    }
    
    func importSharedData(_ importData: ExportData) throws {
        clearAllDataWithoutResettingOnboarding()

        var userMapping: [UUID: UserProfile] = [:]
        for exportUser in importData.users {
            let user = UserProfile(
                remoteId: exportUser.remoteId,
                userId: exportUser.userId,
                name: exportUser.name,
                avatarEmoji: exportUser.avatarEmoji,
                localeIdentifier: exportUser.localeIdentifier,
                currency: exportUser.currency,
                createdAt: exportUser.createdAt,
                updatedAt: exportUser.updatedAt
            )
            modelContext.insert(user)
            userMapping[exportUser.remoteId] = user

            if exportUser.remoteId == importData.currentUserId {
                currentUser = user
            }
        }

        for exportLedger in importData.ledgers {
            let ledger = Ledger(
                remoteId: exportLedger.remoteId,
                name: exportLedger.name,
                ownerId: exportLedger.ownerId,
                currency: exportLedger.currency,
                createdAt: exportLedger.createdAt,
                updatedAt: exportLedger.updatedAt,
                settings: exportLedger.settings
            )
            modelContext.insert(ledger)

            for exportMembership in exportLedger.memberships {
                let membership = Membership(
                    remoteId: exportMembership.remoteId,
                    userId: exportMembership.userId,
                    role: exportMembership.role,
                    joinedAt: exportMembership.joinedAt,
                    ledger: ledger,
                    user: userMapping[exportMembership.userId]
                )
                modelContext.insert(membership)
            }

            for exportExpense in exportLedger.expenses {
                let expense = Expense(
                    remoteId: exportExpense.remoteId,
                    ledgerId: exportExpense.ledgerId,
                    payerId: exportExpense.payerId,
                    title: exportExpense.title,
                    amountMinorUnits: exportExpense.amountMinorUnits,
                    currency: exportExpense.currency,
                    date: exportExpense.date,
                    note: exportExpense.note,
                    category: exportExpense.category,
                    createdAt: exportExpense.createdAt,
                    updatedAt: exportExpense.updatedAt,
                    metadata: exportExpense.metadata,
                    splitStrategy: exportExpense.splitStrategy,
                    ledger: ledger,
                    isSettlement: exportExpense.isSettlement ?? false
                )
                modelContext.insert(expense)

                for exportParticipant in exportExpense.participants {
                    let participant = ExpenseParticipant(
                        remoteId: exportParticipant.remoteId,
                        expenseId: exportParticipant.expenseId,
                        userId: exportParticipant.userId,
                        shareType: exportParticipant.shareType,
                        shareValue: exportParticipant.shareValue,
                        expense: expense
                    )
                    modelContext.insert(participant)
                }
            }
        }

        try modelContext.save()

        if importData.hasCompletedOnboarding {
            UserDefaults.standard.set(true, forKey: hasCompletedOnboardingKey)
        }

        loadData()
    }
    
    /// 从 JSON 文件导入所有数据
    func importAllData(from url: URL) throws {
        // 读取文件
        let jsonData = try Data(contentsOf: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let importData = try decoder.decode(ExportData.self, from: jsonData)
        try importSharedData(importData)
    }
    
    /// 清空所有数据但不重置 onboarding 标记（用于导入前清理）
    private func clearAllDataWithoutResettingOnboarding() {
        // 删除 AuditLog
        let auditLogDesc = FetchDescriptor<AuditLog>()
        if let items = try? modelContext.fetch(auditLogDesc) {
            for item in items { modelContext.delete(item) }
        }
        
        // 删除 TransferPlan
        let transferPlanDesc = FetchDescriptor<TransferPlan>()
        if let items = try? modelContext.fetch(transferPlanDesc) {
            for item in items { modelContext.delete(item) }
        }
        
        // 删除 BalanceSnapshot
        let balanceSnapshotDesc = FetchDescriptor<BalanceSnapshot>()
        if let items = try? modelContext.fetch(balanceSnapshotDesc) {
            for item in items { modelContext.delete(item) }
        }
        
        // 删除 ExpenseParticipant
        let expenseParticipantDesc = FetchDescriptor<ExpenseParticipant>()
        if let items = try? modelContext.fetch(expenseParticipantDesc) {
            for item in items { modelContext.delete(item) }
        }
        
        // 删除 Expense
        let expenseDesc = FetchDescriptor<Expense>()
        if let items = try? modelContext.fetch(expenseDesc) {
            for item in items { modelContext.delete(item) }
        }
        
        // 删除 Membership
        let membershipDesc = FetchDescriptor<Membership>()
        if let items = try? modelContext.fetch(membershipDesc) {
            for item in items { modelContext.delete(item) }
        }
        
        // 删除 Ledger
        let ledgerDesc = FetchDescriptor<Ledger>()
        if let items = try? modelContext.fetch(ledgerDesc) {
            for item in items { modelContext.delete(item) }
        }
        
        // 删除 UserProfile
        let userProfileDesc = FetchDescriptor<UserProfile>()
        if let items = try? modelContext.fetch(userProfileDesc) {
            for item in items { modelContext.delete(item) }
        }

        // 个人账本相关：删除 PersonalTransaction
        let pTxDesc = FetchDescriptor<PersonalTransaction>()
        if let items = try? modelContext.fetch(pTxDesc) {
            for item in items { modelContext.delete(item) }
        }
        // 删除 AccountTransfer
        let pTransferDesc = FetchDescriptor<AccountTransfer>()
        if let items = try? modelContext.fetch(pTransferDesc) {
            for item in items { modelContext.delete(item) }
        }
        // 删除 PersonalAccount
        let pAccountDesc = FetchDescriptor<PersonalAccount>()
        if let items = try? modelContext.fetch(pAccountDesc) {
            for item in items { modelContext.delete(item) }
        }
        // 删除 PersonalPreferences（将由首次访问时自动重建）
        let pPrefsDesc = FetchDescriptor<PersonalPreferences>()
        if let items = try? modelContext.fetch(pPrefsDesc) {
            for item in items { modelContext.delete(item) }
        }
        // 删除 PersonalCategory
        let pCategoryDesc = FetchDescriptor<PersonalCategory>()
        if let items = try? modelContext.fetch(pCategoryDesc) {
            for item in items { modelContext.delete(item) }
        }
        
        try? modelContext.save()
        
        // 清空内存
        currentUser = nil
        allLedgers = []
        allFriends = []
    }

    /// 彻底抹除应用的所有数据与偏好设置（共享账本、朋友、个人账本与所有设置）
    func eraseAbsolutelyAllDataAndPreferences() {
        // 1) 清空数据库所有实体
        clearAllDataWithoutResettingOnboarding()
        
        // 2) 重置所有与功能相关的用户偏好与标记
        let defaults = UserDefaults.standard
        let keysToReset: [String] = [
            hasCompletedOnboardingKey,              // 首次设置完成标记
            "hasSeenWelcomeGuide",                // 欢迎引导已查看
            "defaultLedgerIdForQuickAction",      // 旧版默认账本ID
            "defaultQuickActionTarget",           // 快速操作目标
            "showSharedLedgerTab",                // Tab 显示偏好
            "showPersonalLedgerTab",
            "sharedLandingPref",                  // 共享账本落地页偏好
            "SuppressSyncWarning",                // 同步警告不再提示
            "com.kuaiji.shortcut.pendingQuickAdd" // 快捷指令挂起标记
        ]
        for key in keysToReset { defaults.removeObject(forKey: key) }
        defaults.synchronize()
        
        // 3) 内存态复位
        currentUser = nil
        allLedgers = []
        allFriends = []
    }
}

// MARK: - Export Data Structures

struct ExportData: Codable {
    let version: String
    let exportDate: Date
    let currentUserId: UUID
    let hasCompletedOnboarding: Bool
    let users: [ExportUserProfile]
    let ledgers: [ExportLedger]
}

struct FeatureVisibilitySnapshot: Codable {
    let showSharedAndFriends: Bool
    let showPersonal: Bool
    private let quickActionIdentifier: String?

    init(showSharedAndFriends: Bool, showPersonal: Bool, quickAction: QuickActionTarget?) {
        self.showSharedAndFriends = showSharedAndFriends
        self.showPersonal = showPersonal
        switch quickAction {
        case .personal:
            quickActionIdentifier = "personal"
        case .shared(let id):
            quickActionIdentifier = id.uuidString
        case .none:
            quickActionIdentifier = nil
        }
    }

    func quickActionTarget() -> QuickActionTarget? {
        guard let value = quickActionIdentifier, !value.isEmpty else { return nil }
        if value == "personal" { return .personal }
        if let uuid = UUID(uuidString: value) { return .shared(uuid) }
        return nil
    }
}

struct FullAppExportData: Codable {
    let version: String
    let shared: ExportData
    let personal: PersonalLedgerSnapshot
    let visibility: FeatureVisibilitySnapshot
}

struct ExportUserProfile: Codable {
    let remoteId: UUID
    let userId: String
    let name: String
    let avatarEmoji: String?
    let localeIdentifier: String
    let currency: CurrencyCode
    let createdAt: Date
    let updatedAt: Date
    
    init(from user: UserProfile) {
        self.remoteId = user.remoteId
        self.userId = user.userId
        self.name = user.name
        self.avatarEmoji = user.avatarEmoji
        self.localeIdentifier = user.localeIdentifier
        self.currency = user.currency
        self.createdAt = user.createdAt
        self.updatedAt = user.updatedAt
    }
}

struct ExportLedger: Codable {
    let remoteId: UUID
    let name: String
    let ownerId: UUID
    let currency: CurrencyCode
    let createdAt: Date
    let updatedAt: Date
    let settings: LedgerSettings
    let memberships: [ExportMembership]
    let expenses: [ExportExpense]
    
    init(from ledger: Ledger) {
        self.remoteId = ledger.remoteId
        self.name = ledger.name
        self.ownerId = ledger.ownerId
        self.currency = ledger.currency
        self.createdAt = ledger.createdAt
        self.updatedAt = ledger.updatedAt
        self.settings = ledger.settings
        self.memberships = ledger.memberships.map { ExportMembership(from: $0) }
        self.expenses = ledger.expenses.map { ExportExpense(from: $0) }
    }
}

struct ExportMembership: Codable {
    let remoteId: UUID
    let userId: UUID
    let role: LedgerRole
    let joinedAt: Date
    
    init(from membership: Membership) {
        self.remoteId = membership.remoteId
        self.userId = membership.userId
        self.role = membership.role
        self.joinedAt = membership.joinedAt
    }
}

struct ExportExpense: Codable {
    let remoteId: UUID
    let ledgerId: UUID
    let payerId: UUID
    let title: String
    let amountMinorUnits: Int
    let currency: CurrencyCode
    let date: Date
    let note: String
    let category: ExpenseCategory
    let createdAt: Date
    let updatedAt: Date
    let metadata: ExpenseMetadata
    let splitStrategy: SplitStrategy
    let isSettlement: Bool?
    let participants: [ExportExpenseParticipant]
    
    init(from expense: Expense) {
        self.remoteId = expense.remoteId
        self.ledgerId = expense.ledgerId
        self.payerId = expense.payerId
        self.title = expense.title
        self.amountMinorUnits = expense.amountMinorUnits
        self.currency = expense.currency
        self.date = expense.date
        self.note = expense.note
        self.category = expense.category
        self.createdAt = expense.createdAt
        self.updatedAt = expense.updatedAt
        self.metadata = expense.metadata
        self.splitStrategy = expense.splitStrategy
        self.isSettlement = expense.isSettlement
        self.participants = expense.participants.map { ExportExpenseParticipant(from: $0) }
    }
}

struct ExportExpenseParticipant: Codable {
    let remoteId: UUID
    let expenseId: UUID
    let userId: UUID
    let shareType: ShareType
    let shareValue: Decimal?
    
    init(from participant: ExpenseParticipant) {
        self.remoteId = participant.remoteId
        self.expenseId = participant.expenseId
        self.userId = participant.userId
        self.shareType = participant.shareType
        self.shareValue = participant.shareValue
    }
}
