//
//  SharedLedgerScreenModels.swift
//  KuaiJi
//
//  Concrete shared ledger screen models.
//

import Foundation
import Combine

// MARK: - Screen ViewModels

@MainActor
final class LedgerListScreenModel: ObservableObject, LedgerListViewModelProtocol {
    @Published private(set) var ledgers: [LedgerSummaryViewData]
    @Published private(set) var archivedLedgers: [LedgerSummaryViewData]
    @Published private(set) var availableMembers: [MemberSummaryViewData]
    private weak var root: AppRootViewModel?
    private var cancellables: Set<AnyCancellable> = []

    var currentUser: MemberSummaryViewData {
        root?.currentUser ?? MemberSummaryViewData(id: UUID(), name: L.createLedgerMe.localized, avatarSystemName: "person.fill", currency: .cny, avatarEmoji: "👤")
    }

    init(root: AppRootViewModel) {
        self.root = root
        let summaries = root.ledgerSummaries
        self.ledgers = summaries.filter { !$0.isArchived }
        self.archivedLedgers = summaries.filter { $0.isArchived }
        self.availableMembers = root.friends

        root.$ledgerSummaries
            .receive(on: RunLoop.main)
            .sink { [weak self] summaries in
                self?.ledgers = summaries.filter { !$0.isArchived }
                self?.archivedLedgers = summaries.filter { $0.isArchived }
            }
            .store(in: &cancellables)

        root.$friends
            .receive(on: RunLoop.main)
            .sink { [weak self] friends in
                self?.availableMembers = friends
            }
            .store(in: &cancellables)
    }

    func createLedger(name: String, memberIds: [UUID], currency: CurrencyCode) {
        root?.createLedger(name: name, memberIds: memberIds, currency: currency)
    }

    func deleteLedgers(at offsets: IndexSet) {
        guard let root else { return }
        let ids = offsets.compactMap { ledgers.indices.contains($0) ? ledgers[$0].id : nil }
        ledgers.remove(atOffsets: offsets)
        ids.forEach { root.deleteLedger(ledgerId: $0) }
    }

    func deleteLedger(id: UUID) {
        root?.deleteLedger(ledgerId: id)
    }

    func archiveLedger(id: UUID) {
        root?.archiveLedger(id: id)
    }

    func unarchiveLedger(id: UUID) {
        root?.unarchiveLedger(id: id)
    }
}

@MainActor
final class FriendListScreenModel: ObservableObject, FriendListViewModelProtocol {
    @Published private(set) var friends: [MemberSummaryViewData]
    private weak var root: AppRootViewModel?
    private var cancellables: Set<AnyCancellable> = []

    init(root: AppRootViewModel) {
        self.root = root
        self.friends = root.friends

        root.$friends
            .receive(on: RunLoop.main)
            .sink { [weak self] friends in
                self?.friends = friends
            }
            .store(in: &cancellables)
    }

    func addFriend(named name: String, emoji: String?, currency: CurrencyCode) {
        root?.addFriend(named: name, emoji: emoji, currency: currency)
    }
    
    func addFriendFromQRCode(userId: String, named name: String, emoji: String?, currency: CurrencyCode) -> Bool {
        return root?.addFriendFromQRCode(userId: userId, named: name, emoji: emoji, currency: currency) ?? false
    }

    func deleteFriend(at offsets: IndexSet) {
        guard let root else { return }
        let ids = offsets.compactMap { friends.indices.contains($0) ? friends[$0].id : nil }
        friends.remove(atOffsets: offsets)
        root.deleteFriends(ids: ids)
    }

    func updateFriend(id: UUID, name: String, currency: CurrencyCode, emoji: String?) {
        root?.updateFriend(id: id, name: name, currency: currency, emoji: emoji)
    }
}

@MainActor
final class RecordsScreenModel: ObservableObject, RecordsViewModelProtocol {
    @Published private(set) var records: [LedgerRecordViewData]
    private weak var root: AppRootViewModel?
    private var cancellables: Set<AnyCancellable> = []

    init(root: AppRootViewModel) {
        self.root = root
        self.records = root.allLedgerRecords()

        root.$ledgerSummaries
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    func refresh() {
        guard let root else { return }
        records = root.allLedgerRecords()
    }
}

@MainActor
final class LedgerOverviewScreenModel: ObservableObject, LedgerOverviewViewModelProtocol {
    @Published private(set) var ledger: LedgerDetailViewData
    @Published var filters: LedgerFilterState
    @Published private(set) var balances: [NetBalanceViewData]
    @Published private(set) var members: [MemberSummaryViewData]
    @Published private(set) var memberExpenses: [MemberExpenseViewData]
    @Published private(set) var records: [LedgerRecordViewData]
    @Published private(set) var transferPlan: [TransferRecordViewData]

    private weak var root: AppRootViewModel?
    private let ledgerId: UUID
    private var cancellables: Set<AnyCancellable> = []

    init(root: AppRootViewModel, ledgerId: UUID) {
        let initialFilters = LedgerFilterState()
        self.root = root
        self.ledgerId = ledgerId
        self.filters = initialFilters
        self.members = root.ledgerMembers(ledgerId: ledgerId)
        self.records = root.ledgerRecords(ledgerId: ledgerId)
        self.ledger = root.ledgerDetailData(ledgerId: ledgerId, filters: initialFilters)
        self.balances = root.netBalancesViewData(ledgerId: ledgerId, filters: initialFilters)
        self.transferPlan = root.transferPlanViewData(ledgerId: ledgerId, filters: initialFilters)
        self.memberExpenses = Self.computeMemberExpenses(root: root, ledgerId: ledgerId)

        root.$friends
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshMembers()
                self?.refreshRecords()
            }
            .store(in: &cancellables)

        root.$ledgerSummaries
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    func refresh() {
        guard let root else { return }
        ledger = root.ledgerDetailData(ledgerId: ledgerId, filters: filters)
        balances = root.netBalancesViewData(ledgerId: ledgerId, filters: filters)
        transferPlan = root.transferPlanViewData(ledgerId: ledgerId, filters: filters)
        refreshMembers()
        refreshRecords()
        memberExpenses = Self.computeMemberExpenses(root: root, ledgerId: ledgerId)
    }

    func member(for userId: UUID) -> MemberSummaryViewData? {
        root?.member(with: userId)
    }

    private func refreshMembers() {
        guard let root else { return }
        members = root.ledgerMembers(ledgerId: ledgerId)
    }

    private func refreshRecords() {
        guard let root else { return }
        records = root.ledgerRecords(ledgerId: ledgerId)
    }
    
    func deleteExpense(at offsets: IndexSet) {
        guard let root else { return }
        for index in offsets {
            let record = records[index]
            root.deleteExpense(expenseId: record.id)
        }
        refresh()
    }
    
    func clearAllBalances() {
        guard let root else { return }
        root.clearLedgerBalances(ledgerId: ledgerId)
        refresh()
    }
    
    private static func computeMemberExpenses(root: AppRootViewModel, ledgerId: UUID) -> [MemberExpenseViewData] {
        guard let ledgerInfo = root.ledgerInfos[ledgerId] else { return [] }
        
        let locale = Locale(identifier: root.localeIdentifier)
        var memberTotals: [UUID: Int] = [:]
        
        // 统计每个成员作为付款人的总支出（包括清账记录）
        // 清账会影响成员的实际支出：付款人支出增加，承担人支出减少（收到转账）
        for expense in ledgerInfo.expenses {
            let totalMinor = expense.amountMinorUnits + expense.metadata.tipMinorUnits + expense.metadata.taxMinorUnits
            
            if expense.isSettlement {
                // 清账记录：付款人支出增加，承担人支出减少
                memberTotals[expense.payerId, default: 0] += totalMinor  // 付款人支出增加
                
                // 承担人支出减少（收到转账）
                for participant in expense.participants {
                    memberTotals[participant.userId, default: 0] -= totalMinor
                }
            } else {
                // 普通支出：只统计付款人
                memberTotals[expense.payerId, default: 0] += totalMinor
            }
        }
        
        // 转换为视图数据
        return memberTotals.map { userId, totalMinor in
            let member = root.member(with: userId)
            let display = AmountFormatter.string(minorUnits: totalMinor, currency: ledgerInfo.currency, locale: locale)
            return MemberExpenseViewData(
                id: userId,
                name: member?.name ?? L.defaultUnknownMember.localized,
                avatarEmoji: member?.avatarEmoji,
                totalSpentMinorUnits: totalMinor,
                totalSpentDisplay: display
            )
        }.sorted { $0.totalSpentMinorUnits > $1.totalSpentMinorUnits }  // 按支出金额降序排列
    }
}

@MainActor
final class ExpenseFormScreenModel: ObservableObject, ExpenseFormViewModelProtocol {
    @Published var draft: ExpenseDraftViewData
    @Published private(set) var splitPreview: [NetBalanceViewData]
    @Published var splitOption: ExpenseSplitOption
    @Published private(set) var selectedOtherPayerId: UUID?
    @Published private(set) var selectedHelpPayPayerId: UUID?  // 谁帮谁付：付款人
    @Published private(set) var selectedBeneficiaryId: UUID?  // 谁帮谁付：受益人（被帮付的人）
    @Published private(set) var availableMembers: [MemberSummaryViewData]
    @Published var validationError: String?  // 验证错误信息

    private weak var root: AppRootViewModel?
    private let ledgerId: UUID
    private let currentUserId: UUID
    private let ledgerCurrency: CurrencyCode
    private var cancellables: Set<AnyCancellable> = []

    var currencyCode: String { ledgerCurrency.rawValue }

    var participantNames: String {
        guard let root else { return "" }
        let names = draft.participantShares.compactMap { root.member(with: $0.userId)?.name }
        return names.isEmpty ? "暂无成员" : names.joined(separator: "、")
    }

    var selectableOtherPayers: [MemberSummaryViewData] {
        availableMembers.filter { $0.id != currentUserId }
    }
    
    // 谁帮谁付：可选的付款人（所有成员）
    var selectableHelpPayPayers: [MemberSummaryViewData] {
        availableMembers
    }
    
    // 谁帮谁付：可选的受益人（除了当前选中的付款人外的所有成员）
    var selectableBeneficiaries: [MemberSummaryViewData] {
        guard let payerId = selectedHelpPayPayerId else { return availableMembers }
        return availableMembers.filter { $0.id != payerId }
    }

    init(root: AppRootViewModel, ledgerId: UUID) {
        let currentUser = root.currentUser
        let members = root.ledgerMembers(ledgerId: ledgerId)
        let detail = root.ledgerDetailData(ledgerId: ledgerId, filters: LedgerFilterState())
        
        // 先初始化所有存储属性
        self.root = root
        self.ledgerId = ledgerId
        self.currentUserId = currentUser.id
        self.availableMembers = members
        self.ledgerCurrency = detail.currency
        self.splitOption = .meAllAA
        self.draft = ExpenseDraftViewData(title: "",
                                     amount: Decimal(0),
                                     date: Date(),
                                          payerId: currentUser.id,
                                     splitStrategy: .payerAA,
                                          includePayer: true,
                                          participantShares: [],
                                     note: "",
                                     category: .other)
        self.splitPreview = []
        
        // 初始化完成后，再访问计算属性
        self.selectedOtherPayerId = selectableOtherPayers.first?.id
        self.selectedHelpPayPayerId = availableMembers.first?.id
        self.selectedBeneficiaryId = availableMembers.count > 1 ? availableMembers[1].id : nil

        applySplitConfiguration()
        regeneratePreview()

        root.$ledgerSummaries
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, let root = self.root else { return }
                self.availableMembers = root.ledgerMembers(ledgerId: self.ledgerId)
                if !self.selectableOtherPayers.contains(where: { $0.id == self.selectedOtherPayerId }) {
                    self.selectedOtherPayerId = self.selectableOtherPayers.first?.id
                }
                self.applySplitConfiguration()
            }
            .store(in: &cancellables)

        root.$friends
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, let root = self.root else { return }
                self.availableMembers = root.ledgerMembers(ledgerId: self.ledgerId)
                if !self.selectableOtherPayers.contains(where: { $0.id == self.selectedOtherPayerId }) {
                    self.selectedOtherPayerId = self.selectableOtherPayers.first?.id
                }
                self.applySplitConfiguration()
            }
            .store(in: &cancellables)
    }

    func selectSplitOption(_ option: ExpenseSplitOption) {
        splitOption = option
        applySplitConfiguration()
    }

    func selectOtherPayer(id: UUID) {
        guard selectableOtherPayers.contains(where: { $0.id == id }) else { return }
        selectedOtherPayerId = id
        applySplitConfiguration()
    }

    func regeneratePreview() {
        guard let root else { return }
        guard !draft.participantShares.isEmpty else {
            splitPreview = []
            return
        }
        let amountMinor = SettlementMath.minorUnits(from: draft.amount, scale: root.settings.roundingScale)
        let expense = ExpenseInput(ledgerId: ledgerId,
                                   payerId: draft.payerId,
                                   title: draft.title.isEmpty ? L.defaultPreview.localized : draft.title,
                                   note: draft.note,
                                   category: draft.category,
                                   amountMinorUnits: amountMinor,
                                   currency: ledgerCurrency,
                                   date: draft.date,
                                   splitStrategy: draft.splitStrategy,
                                   metadata: ExpenseMetadata(includePayer: draft.includePayer),
                                   participants: draft.participantShares)
        let converter = CurrencyConverter(ledgerCurrency: ledgerCurrency,
                                          rule: root.settings.crossCurrencyRule,
                                          scale: root.settings.roundingScale)
        let shares = (try? SettlementCalculator.shareDistribution(for: expense,
                                                                   convertedTotalMinor: amountMinor,
                                                                   includePayer: draft.includePayer,
                                                                   converter: converter,
                                                                   settings: root.settings)) ?? [:]
        let locale = Locale(identifier: root.localeIdentifier)
        splitPreview = shares.compactMap { userId, amount in
            guard let member = root.member(with: userId) else { return nil }
            let display = AmountFormatter.string(minorUnits: amount, currency: ledgerCurrency, locale: locale)
            return NetBalanceViewData(id: userId, userName: member.name, amountMinorUnits: amount, amountDisplay: display)
        }.sorted { $0.userName < $1.userName }
        
        // 生成预览后验证
        _ = validateSplitAmounts()
    }
    
    func validateSplitAmounts() -> Bool {
        guard draft.amount > 0 else {
            validationError = nil  // 金额为0时不显示错误（由保存按钮的disabled控制）
            return false
        }
        
        guard !draft.participantShares.isEmpty else {
            validationError = "请至少选择一位参与者"
            return false
        }
        
        // 计算需要分账的参与者数量（排除"请客"类型）
        let participantCount = draft.participantShares.filter { share in
            share.shareType != .treat
        }.count
        
        guard participantCount > 0 else {
            // 全部是"请客"，不需要验证
            validationError = nil
            return true
        }
        
        // 计算金额的最小单位（分）
        let amountMinor = SettlementMath.minorUnits(from: draft.amount, scale: 2)
        
        // 最小总金额 = 参与人数 * 1分
        let minRequiredMinorUnits = participantCount
        
        if amountMinor < minRequiredMinorUnits {
            let locale = Locale(identifier: root?.localeIdentifier ?? "zh_CN")
            let formattedMin = AmountFormatter.string(
                minorUnits: minRequiredMinorUnits,
                currency: ledgerCurrency,
                locale: locale
            )
            validationError = "金额太小！至少需要 \(formattedMin) 才能让 \(participantCount) 位参与者每人分摊至少 0.01 元"
            return false
        }
        
        validationError = nil
        return true
    }

    func saveDraft() {
        applySplitConfiguration()
        guard let root else { return }
        guard !draft.participantShares.isEmpty else { return }
        root.addExpense(from: draft, to: ledgerId)
    }

    private func applySplitConfiguration() {
        guard !availableMembers.isEmpty else {
            draft.participantShares = []
            return
        }
        
        // 如果没有其他成员，自动切换到"我"的选项
        if selectableOtherPayers.isEmpty {
            if splitOption == .otherAllAA { splitOption = .meAllAA }
            if splitOption == .otherTreat { splitOption = .meTreat }
        }
        
        switch splitOption {
        case .meAllAA:
            // 选项1：我付的钱，所有人AA
            // 逻辑：我支付金额A，账本N人（含我），每人分摊 A÷N，其他(N-1)人各欠我 A÷N
            draft.payerId = currentUserId
            draft.splitStrategy = .payerAA
            draft.includePayer = true  // AA时包含付款人（我）
            // 所有成员（包括我）都参与AA分摊
            draft.replaceParticipantShares(availableMembers.map { 
                ExpenseParticipantShare(userId: $0.id, shareType: .aa) 
            })
            
        case .otherAllAA:
            // 选项2：别人付的钱，所有人AA
            // 逻辑：X支付金额A，账本N人（含X），每人分摊 A÷N，其他(N-1)人各欠X A÷N
            let payerId = selectedOtherPayerId ?? selectableOtherPayers.first?.id ?? currentUserId
            selectedOtherPayerId = payerId == currentUserId ? selectableOtherPayers.first?.id : payerId
            draft.payerId = selectedOtherPayerId ?? currentUserId
            draft.splitStrategy = .payerAA
            draft.includePayer = true  // AA时包含付款人
            // 所有成员（包括付款人）都参与AA分摊
            draft.replaceParticipantShares(availableMembers.map { 
                ExpenseParticipantShare(userId: $0.id, shareType: .aa) 
            })
            
        case .meTreat:
            // 选项3：我请客
            // 逻辑：我支付金额A，没有人欠我钱，仅记录流水
            draft.payerId = currentUserId
            draft.splitStrategy = .payerTreat
            draft.includePayer = false  // 请客时不分摊
            // 只有我自己参与，标记为treat（不分摊）
            draft.replaceParticipantShares([
                ExpenseParticipantShare(userId: currentUserId, shareType: .treat)
            ])
            
        case .otherTreat:
            // 选项4：别人请客
            // 逻辑：X支付金额A，没有人欠X钱，仅记录流水
            let payerId = selectedOtherPayerId ?? selectableOtherPayers.first?.id ?? currentUserId
            selectedOtherPayerId = payerId == currentUserId ? selectableOtherPayers.first?.id : payerId
            draft.payerId = selectedOtherPayerId ?? currentUserId
            draft.splitStrategy = .actorTreat
            draft.includePayer = false  // 请客时不分摊
            // 只有付款人参与，标记为treat（不分摊）
            draft.replaceParticipantShares([
                ExpenseParticipantShare(userId: draft.payerId, shareType: .treat)
            ])
            
        case .helpPay:
            // 选项5：谁帮谁付（代付/垫付）
            // 逻辑：A帮B支付金额M，B欠A金额M
            // 付款人：A（实际掏钱的人）
            // 受益人/参与人：B（被帮付的人，承担100%费用）
            let payerId = selectedHelpPayPayerId ?? availableMembers.first?.id ?? currentUserId
            var beneficiaryId = selectedBeneficiaryId ?? availableMembers.first?.id ?? currentUserId
            
            // 确保受益人和付款人不是同一个人
            if beneficiaryId == payerId {
                beneficiaryId = availableMembers.first(where: { $0.id != payerId })?.id ?? beneficiaryId
            }
            
            selectedHelpPayPayerId = payerId
            selectedBeneficiaryId = beneficiaryId
            
            draft.payerId = payerId
            draft.splitStrategy = .helpPay
            draft.includePayer = false  // 付款人不参与分摊
            // 只有受益人参与，使用AA类型（只有一个参与人时AA就是全额承担）
            draft.replaceParticipantShares([
                ExpenseParticipantShare(userId: beneficiaryId, shareType: .aa)
            ])
        }
        
        regeneratePreview()
    }
    
    func selectHelpPayPayer(id: UUID) {
        selectedHelpPayPayerId = id
        // 如果受益人和付款人相同，自动选择另一个人
        if selectedBeneficiaryId == id {
            selectedBeneficiaryId = selectableBeneficiaries.first?.id
        }
        applySplitConfiguration()
    }
    
    func selectBeneficiary(id: UUID) {
        selectedBeneficiaryId = id
        applySplitConfiguration()
    }
}
