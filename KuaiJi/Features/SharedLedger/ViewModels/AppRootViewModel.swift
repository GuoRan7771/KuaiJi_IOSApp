//
//  AppRootViewModel.swift
//  KuaiJi
//
//  Shared ledger root state and persistence adapter.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Root ViewModel & Factories

@MainActor
final class AppRootViewModel: ObservableObject {
    struct LedgerInfo {
        var id: UUID
        var name: String
        var currency: CurrencyCode
        var createdAt: Date
        var updatedAt: Date
        var expenses: [ExpenseInput]
        var memberIds: [UUID]
    }

    @Published var ledgerInfos: [UUID: LedgerInfo]
    @Published private(set) var ledgerSummaries: [LedgerSummaryViewData]
    @Published private(set) var settings: LedgerSettings
    @Published private(set) var friends: [MemberSummaryViewData]
    private var archivedLedgerIds: Set<UUID>
    private var archivedLedgerVersion: [UUID: Date]
    private var archivedLedgerExpenseCounts: [UUID: Int]
    private var dataChangeObserver: NSObjectProtocol?
    private var dataManagerCancellables: Set<AnyCancellable> = []

    @Published private(set) var localeIdentifier: String
    @Published private(set) var currentUser: MemberSummaryViewData
    private var memberLookup: [UUID: MemberSummaryViewData]
    
    var dataManager: PersistentDataManager?
    weak var appStateRef: AppState?

    var members: [MemberSummaryViewData] { [currentUser] + friends }

    init() {
        // 使用系统语言
        let systemLocale = Locale.current.identifier
        let initialSettings = LedgerSettings(defaultCurrency: .cny,
                                             defaultLocale: systemLocale,
                                   includePayerInAA: true,
                                   roundingScale: 2,
                                   crossCurrencyRule: .forbid)

        // 初始化空数据，等待setDataManager调用后加载真实数据
        let me = MemberSummaryViewData(id: UUID(), name: L.createLedgerMe.localized, avatarSystemName: "person.fill", currency: .cny, avatarEmoji: "👤")

        self.localeIdentifier = systemLocale
        self.settings = initialSettings
        self.currentUser = me
        self.friends = []
        self.memberLookup = [me.id: me]
        self.ledgerInfos = [:]
        self.ledgerSummaries = []
        self.archivedLedgerIds = Self.loadArchivedLedgerIds()
        self.archivedLedgerVersion = Self.loadArchivedLedgerVersions()
        self.archivedLedgerExpenseCounts = Self.loadArchivedLedgerExpenseCounts()

        dataChangeObserver = NotificationCenter.default.addObserver(forName: .persistentDataDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.loadFromPersistence()
            }
        }
    }
    
    func setDataManager(_ manager: PersistentDataManager) {
        dataManagerCancellables.removeAll()
        self.dataManager = manager

        manager.$allLedgers
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.loadFromPersistence()
                }
            }
            .store(in: &dataManagerCancellables)

        manager.$allFriends
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.loadFromPersistence()
                }
            }
            .store(in: &dataManagerCancellables)

        manager.$currentUser
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.loadFromPersistence()
                }
            }
            .store(in: &dataManagerCancellables)

        // 监听数据版本号，确保任何 loadData 调用后都刷新汇总（包括待结算）
        manager.$dataRevision
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.loadFromPersistence()
                }
            }
            .store(in: &dataManagerCancellables)

        loadFromPersistence()
    }

    func bind(appState: AppState) {
        self.appStateRef = appState
    }

    func notifyEraseAll() {
        // 抹除后刷新内存并要求 AppState 重新进入首次设置/引导
        ledgerInfos = [:]
        ledgerSummaries = []
        friends = []
        memberLookup = [:]
        appStateRef?.dataManager = dataManager
        appStateRef?.showOnboarding = false
        appStateRef?.showWelcomeGuide = false
        appStateRef?.isCheckingOnboarding = true
        appStateRef?.checkOnboardingStatus()
        appStateRef?.isCheckingOnboarding = false
    }

    deinit {
        if let observer = dataChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        dataManagerCancellables.removeAll()
    }
    
    func loadFromPersistence() {
        guard let dataManager = dataManager else { return }
        
        // 加载朋友
        friends = dataManager.allFriends.map { userProfile in
            MemberSummaryViewData(
                id: userProfile.remoteId,
                name: userProfile.name,
                avatarSystemName: "person.crop.circle",
                currency: userProfile.currency,
                avatarEmoji: userProfile.avatarEmoji
            )
        }
        
        // 更新当前用户
        if let currentUserProfile = dataManager.currentUser {
            currentUser = MemberSummaryViewData(
                id: currentUserProfile.remoteId,
                name: currentUserProfile.name,
                avatarSystemName: "person.fill",
                currency: currentUserProfile.currency,
                avatarEmoji: currentUserProfile.avatarEmoji ?? "👤"
            )
            memberLookup = [currentUser.id: currentUser]
            localeIdentifier = currentUserProfile.localeIdentifier
        }
        
        // 加载账本
        var newLedgerInfos: [UUID: LedgerInfo] = [:]
        for ledger in dataManager.allLedgers {
            let members = dataManager.getLedgerMembers(ledgerId: ledger.remoteId)
            let memberIds = members.map { $0.remoteId }
            
            // 更新memberLookup
            for member in members {
                let viewData = MemberSummaryViewData(
                    id: member.remoteId,
                    name: member.name,
                    avatarSystemName: "person.crop.circle",
                    currency: member.currency,
                    avatarEmoji: member.avatarEmoji
                )
                memberLookup[member.remoteId] = viewData
            }
            
            // 加载支出
            // 强制从数据库重新获取支出列表，解决 SwiftData 关联属性可能不刷新的问题
            let rawExpenses = dataManager.getLedgerExpenses(ledgerId: ledger.remoteId)
            let expenses = rawExpenses.map { expense in
                let rawParticipants = dataManager.getExpenseParticipants(expenseId: expense.remoteId)
                let participants = rawParticipants.map { participant in
                    ExpenseParticipantShare(
                        userId: participant.userId,
                        shareType: participant.shareType,
                        shareValue: participant.shareValue
                    )
                }
                
                return ExpenseInput(
                    id: expense.remoteId,
                    ledgerId: ledger.remoteId,
                    payerId: expense.payerId,
                    title: expense.title,
                    note: expense.note,
                    category: expense.category,
                    amountMinorUnits: expense.amountMinorUnits,
                    currency: expense.currency,
                    date: expense.date,
                    splitStrategy: expense.splitStrategy,
                    metadata: expense.metadata,
                    participants: participants,
                    isSettlement: expense.isSettlement == true  // nil 或 false 都视为非清账记录
                )
            }
            
            newLedgerInfos[ledger.remoteId] = LedgerInfo(
                id: ledger.remoteId,
                name: ledger.name,
                currency: ledger.currency,
                createdAt: ledger.createdAt,
                updatedAt: ledger.updatedAt,
                expenses: expenses,
                memberIds: memberIds
            )
        }
        
        ledgerInfos = newLedgerInfos
        refreshSummaries()
    }

    func makeLedgerListViewModel() -> LedgerListScreenModel {
        LedgerListScreenModel(root: self)
    }

    func makeLedgerOverviewViewModel(ledgerId: UUID) -> LedgerOverviewScreenModel {
        LedgerOverviewScreenModel(root: self, ledgerId: ledgerId)
    }

    func makeExpenseFormViewModel(ledgerId: UUID) -> ExpenseFormScreenModel {
        ExpenseFormScreenModel(root: self, ledgerId: ledgerId)
    }

    func makeSettlementViewModel(ledgerId: UUID) -> SettlementScreenModel {
        SettlementScreenModel(root: self, ledgerId: ledgerId)
    }

    func makeMemberDetailViewModel(memberId: UUID, ledgerId: UUID) -> MemberDetailScreenModel {
        MemberDetailScreenModel(root: self, ledgerId: ledgerId, memberId: memberId)
    }

    func makeFriendListViewModel() -> FriendListScreenModel {
        FriendListScreenModel(root: self)
    }

    func makeRecordsViewModel() -> RecordsScreenModel {
        RecordsScreenModel(root: self)
    }

    func makeSettingsViewModel() -> SettingsScreenModel {
        SettingsScreenModel(root: self)
    }

    func archiveLedger(id: UUID) {
        guard ledgerInfos[id] != nil else { return }
        archivedLedgerIds.insert(id)
        archivedLedgerVersion[id] = ledgerInfos[id]?.updatedAt
        archivedLedgerExpenseCounts[id] = ledgerInfos[id]?.expenses.count ?? 0
        refreshSummaries()
    }

    func unarchiveLedger(id: UUID) {
        archivedLedgerIds.remove(id)
        archivedLedgerVersion[id] = nil
        archivedLedgerExpenseCounts[id] = nil
        refreshSummaries()
    }

    func ledgerMembers(ledgerId: UUID) -> [MemberSummaryViewData] {
        guard let info = ledgerInfos[ledgerId] else { return [] }
        return info.memberIds.compactMap { memberLookup[$0] }
    }

    func addFriend(named name: String, emoji: String? = nil, currency: CurrencyCode) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        guard let dataManager = dataManager else { return }
        dataManager.addFriend(name: trimmed, emoji: emoji, currency: currency)
        loadFromPersistence()
    }
    
    func addFriendFromQRCode(userId: String, named name: String, emoji: String?, currency: CurrencyCode) -> Bool {
        guard let dataManager = dataManager else { return false }
        let success = dataManager.addFriendFromQRCode(userId: userId, name: name, emoji: emoji, currency: currency)
        if success {
            loadFromPersistence()
        }
        return success
    }

    func deleteFriends(at offsets: IndexSet) {
        let ids = offsets.compactMap { friends.indices.contains($0) ? friends[$0].id : nil }
        deleteFriends(ids: ids)
    }

    func deleteFriends(ids: [UUID]) {
        guard let dataManager = dataManager else { return }
        for id in ids {
            dataManager.deleteFriend(id: id)
        }
        loadFromPersistence()
    }

    func updateFriend(id: UUID, name: String, currency: CurrencyCode, emoji: String? = nil) {
        guard let dataManager = dataManager else { return }
        dataManager.updateFriend(id: id, name: name, emoji: emoji, currency: currency)
        loadFromPersistence()
    }

    func createLedger(name: String, memberIds: [UUID], currency: CurrencyCode) {
        guard let dataManager = dataManager else { return }
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmedName.isEmpty ? L.defaultNewLedger.localized : trimmedName
        
        // 去重
        var uniqueMemberIds = [UUID]()
        var seen = Set<UUID>()
        for id in memberIds {
            if !seen.contains(id) {
                uniqueMemberIds.append(id)
                seen.insert(id)
            }
        }
        
        guard uniqueMemberIds.count >= 2 else { return }
        
        dataManager.createLedger(name: finalName, memberIds: uniqueMemberIds, currency: currency)
        loadFromPersistence()
    }

    func deleteLedger(ledgerId: UUID) {
        guard let dataManager = dataManager else { return }
        archivedLedgerIds.remove(ledgerId)
        archivedLedgerVersion[ledgerId] = nil
        persistArchiveState()
        dataManager.deleteLedger(id: ledgerId)
        loadFromPersistence()
    }

    func member(with id: UUID) -> MemberSummaryViewData? {
        memberLookup[id]
    }

    func ledgerDetailData(ledgerId: UUID, filters: LedgerFilterState) -> LedgerDetailViewData {
        guard let info = ledgerInfos[ledgerId] else {
            return LedgerDetailViewData(id: ledgerId, name: L.defaultUnknown.localized, currency: settings.defaultCurrency, totalSpentDisplay: "-", filterSummary: filters.summaryDescription)
        }
        let locale = Locale(identifier: localeIdentifier)
        let filtered = apply(filters: filters, to: info.expenses)
        // 计算总支出时排除清账记录
        let totalMinor = filtered.filter { !$0.isSettlement }.reduce(0) { partial, expense in
            let sum = expense.amountMinorUnits + expense.metadata.tipMinorUnits + expense.metadata.taxMinorUnits
            return partial + sum
        }
        let totalDisplay = AmountFormatter.string(minorUnits: totalMinor, currency: info.currency, locale: locale)
        return LedgerDetailViewData(id: info.id,
                                    name: info.name,
                                    currency: info.currency,
                                    totalSpentDisplay: totalDisplay,
                                    filterSummary: filters.summaryDescription)
    }

    func netBalancesViewData(ledgerId: UUID, filters: LedgerFilterState) -> [NetBalanceViewData] {
        guard let info = ledgerInfos[ledgerId] else { return [] }
        let locale = Locale(identifier: localeIdentifier)
        let netDict = (try? computeNetBalances(ledgerId: ledgerId, filters: filters)) ?? [:]
        return netDict.compactMap { userId, amount in
            guard let member = memberLookup[userId] else { return nil }
            let display = AmountFormatter.string(minorUnits: amount, currency: info.currency, locale: locale)
            return NetBalanceViewData(id: userId, userName: member.name, amountMinorUnits: amount, amountDisplay: display)
        }.sorted { $0.userName < $1.userName }
    }

    func transferPlanViewData(ledgerId: UUID, filters: LedgerFilterState) -> [TransferRecordViewData] {
        guard let info = ledgerInfos[ledgerId] else { return [] }
        let locale = Locale(identifier: localeIdentifier)
        let net = (try? computeNetBalances(ledgerId: ledgerId, filters: filters)) ?? [:]
        let plan = TransferPlanner.greedyMinTransfers(from: net)
        return plan.transfers.compactMap { transfer in
            guard let fromMember = memberLookup[transfer.from], let toMember = memberLookup[transfer.to] else { return nil }
            let display = AmountFormatter.string(minorUnits: transfer.amountMinorUnits, currency: info.currency, locale: locale)
            return TransferRecordViewData(fromName: fromMember.name, toName: toMember.name, amountDisplay: display)
        }
    }

    func ledgerRecords(ledgerId: UUID) -> [LedgerRecordViewData] {
        guard let info = ledgerInfos[ledgerId] else { return [] }
        return records(from: info)
    }

    func resolvedTitle(for expense: ExpenseInput) -> String {
        let fallback = expense.title.isEmpty ? L.defaultUntitledExpense.localized : expense.title
        guard expense.isSettlement else { return fallback }

        let payerName = memberLookup[expense.payerId]?.name ?? L.defaultUnknownMember.localized
        let participantNames = expense.participants.map { participant in
            memberLookup[participant.userId]?.name ?? L.defaultUnknownMember.localized
        }

        guard let firstReceiver = participantNames.first else { return fallback }
        let receiverDisplay = participantNames.count == 1 ? firstReceiver : participantNames.joined(separator: ", ")
        return String(format: L.defaultClearBalanceTransfer.localized, payerName, receiverDisplay)
    }

    func allLedgerRecords() -> [LedgerRecordViewData] {
        ledgerInfos.values.flatMap { records(from: $0) }.sorted { $0.date > $1.date }
    }

    private func records(from info: LedgerInfo) -> [LedgerRecordViewData] {
        let locale = Locale(identifier: localeIdentifier)
        return info.expenses.map { expense in
            let totalMinor = expense.amountMinorUnits + expense.metadata.tipMinorUnits + expense.metadata.taxMinorUnits
            let amountDisplay = AmountFormatter.string(minorUnits: totalMinor, currency: info.currency, locale: locale)
            let payerName = memberLookup[expense.payerId]?.name ?? L.defaultUnknownMember.localized
            let title = resolvedTitle(for: expense)
            let beneficiaryName: String? = {
                guard expense.splitStrategy == .helpPay else { return nil }
                guard let beneficiaryId = expense.participants.first?.userId else { return nil }
                return memberLookup[beneficiaryId]?.name ?? L.defaultUnknownMember.localized
            }()
            let splitLabel = expense.splitStrategy.displayLabel(beneficiaryName: beneficiaryName)
            return LedgerRecordViewData(id: expense.id,
                                        ledgerId: info.id,
                                        ledgerName: info.name,
                                        title: title,
                                        amountDisplay: amountDisplay,
                                        amountMinorUnits: totalMinor,
                                        date: expense.date,
                                        category: expense.category,
                                        payerName: payerName,
                                        splitModeDisplay: splitLabel)
        }.sorted { $0.date > $1.date }
    }

    func addExpense(from draft: ExpenseDraftViewData, to ledgerId: UUID) {
        guard let dataManager = dataManager,
              let info = ledgerInfos[ledgerId] else { return }
        
        dataManager.addExpense(
            ledgerId: ledgerId,
            payerId: draft.payerId,
            title: draft.title,
            amount: draft.amount,
            currency: info.currency,
            date: draft.date,
            category: draft.category,
            note: draft.note,
            splitStrategy: draft.splitStrategy,
            includePayer: draft.includePayer,
            participants: draft.participantShares
        )
        
        loadFromPersistence()
    }

    func updateSettings(with state: SettingsViewState) {
        // 语言始终跟随系统，不做任何语言设置更新
        objectWillChange.send()
    }
    
    func clearAllData() {
        guard let dataManager = dataManager else { return }
        dataManager.clearAllData()
        loadFromPersistence()
    }
    
    func deleteExpense(expenseId: UUID) {
        guard let dataManager = dataManager else { return }
        dataManager.deleteExpense(expenseId: expenseId)
        loadFromPersistence()
    }
    
    func clearLedgerBalances(ledgerId: UUID) {
        guard let dataManager = dataManager else { return }
        dataManager.clearLedgerBalances(ledgerId: ledgerId)
        loadFromPersistence()
    }
    
    func updateUserProfile(name: String, emoji: String, currency: CurrencyCode) {
        guard let dataManager = dataManager else { return }
        dataManager.updateUserProfile(name: name, emoji: emoji, currency: currency)
        loadFromPersistence()
    }

    private func refreshSummaries() {
        guard let dataManager = dataManager else { return }
        let existingIds = Set(ledgerInfos.keys)
        archivedLedgerIds = archivedLedgerIds.intersection(existingIds)
        archivedLedgerVersion = archivedLedgerVersion.filter { existingIds.contains($0.key) }
        archivedLedgerExpenseCounts = archivedLedgerExpenseCounts.filter { existingIds.contains($0.key) }

        var didUnarchive = false
        for (id, info) in ledgerInfos {
            let hasNewerUpdate: Bool = {
                if let archivedVersion = archivedLedgerVersion[id] {
                    // 允许 0.1 秒的误差，避免因序列化精度丢失导致误判为有更新
                    return info.updatedAt.timeIntervalSince1970 > archivedVersion.timeIntervalSince1970 + 0.1
                }
                return false
            }()
            let hasMoreExpenses: Bool = {
                if let archivedCount = archivedLedgerExpenseCounts[id] {
                    return info.expenses.count > archivedCount
                }
                return false
            }()

            if hasNewerUpdate || hasMoreExpenses {
                archivedLedgerIds.remove(id)
                archivedLedgerVersion[id] = nil
                archivedLedgerExpenseCounts[id] = nil
                didUnarchive = true
            }
        }
        archivedLedgerVersion = archivedLedgerVersion.filter { archivedLedgerIds.contains($0.key) }
        archivedLedgerExpenseCounts = archivedLedgerExpenseCounts.filter { archivedLedgerIds.contains($0.key) }
        if didUnarchive {
            debugLog("📦 自动取消归档有更新的账本")
        }

        let localeId = LocaleManager.preferredLocaleIdentifier ?? dataManager.currentUser?.localeIdentifier ?? localeIdentifier
        localeIdentifier = localeId
        let locale = Locale(identifier: localeIdentifier)
        ledgerSummaries = ledgerInfos.values.sorted { $0.updatedAt > $1.updatedAt }.map { info in
            let net = (try? computeNetBalances(ledgerId: info.id, filters: LedgerFilterState())) ?? [:]
            let outstanding = net.values.reduce(0) { partial, value in
                value > 0 ? partial + value : partial
            }
            let outstandingDisplay = AmountFormatter.string(minorUnits: outstanding, currency: info.currency, locale: locale)
            return LedgerSummaryViewData(id: info.id,
                                         name: info.name,
                                         memberCount: info.memberIds.count,
                                         currency: info.currency,
                                         outstandingDisplay: outstandingDisplay,
                                         updatedAt: info.updatedAt,
                                         isArchived: archivedLedgerIds.contains(info.id))
        }
        persistArchiveState()
    }

    private func computeNetBalances(ledgerId: UUID, filters: LedgerFilterState) throws -> [UUID: Int] {
        guard let info = ledgerInfos[ledgerId] else { return [:] }
        let filtered = apply(filters: filters, to: info.expenses)
        return try SettlementCalculator.computeNetBalances(ledgerCurrency: info.currency,
                                                            expenses: filtered,
                                                            settings: settings)
    }

    private func apply(filters: LedgerFilterState, to expenses: [ExpenseInput]) -> [ExpenseInput] {
        expenses.filter { expense in
            if let from = filters.fromDate, expense.date < from { return false }
            if let to = filters.toDate, expense.date > to { return false }
            if !filters.categories.isEmpty && !filters.categories.contains(expense.category) { return false }
            if !filters.memberIds.isEmpty {
                let participantIDs = Set(expense.participants.map { $0.userId })
                if !participantIDs.union([expense.payerId]).isSuperset(of: filters.memberIds) {
                    return false
                }
            }
            return true
        }
    }

    private static let archivedLedgerKey = "archivedLedgerIds"
    private static let archivedLedgerVersionKey = "archivedLedgerVersions"
    private static let archivedLedgerExpenseCountKey = "archivedLedgerExpenseCounts"

    private static let archivedDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func loadArchivedLedgerIds() -> Set<UUID> {
        let defaults = UserDefaults.standard
        let raw = defaults.stringArray(forKey: archivedLedgerKey) ?? []
        let ids = raw.compactMap { UUID(uuidString: $0) }
        return Set(ids)
    }

    private static func loadArchivedLedgerVersions() -> [UUID: Date] {
        let defaults = UserDefaults.standard
        guard let dict = defaults.dictionary(forKey: archivedLedgerVersionKey) as? [String: String] else {
            return [:]
        }
        var result: [UUID: Date] = [:]
        for (key, value) in dict {
            if let id = UUID(uuidString: key),
               let date = archivedDateFormatter.date(from: value) {
                result[id] = date
            }
        }
        return result
    }

    private static func loadArchivedLedgerExpenseCounts() -> [UUID: Int] {
        let defaults = UserDefaults.standard
        guard let dict = defaults.dictionary(forKey: archivedLedgerExpenseCountKey) as? [String: Int] else {
            return [:]
        }
        var result: [UUID: Int] = [:]
        for (key, value) in dict {
            if let id = UUID(uuidString: key) {
                result[id] = value
            }
        }
        return result
    }

    private func persistArchiveState() {
        let defaults = UserDefaults.standard
        defaults.set(Array(archivedLedgerIds).map { $0.uuidString }, forKey: Self.archivedLedgerKey)
        let dict: [String: String] = archivedLedgerVersion.reduce(into: [:]) { result, entry in
            result[entry.key.uuidString] = Self.archivedDateFormatter.string(from: entry.value)
        }
        defaults.set(dict, forKey: Self.archivedLedgerVersionKey)
        let countDict: [String: Int] = archivedLedgerExpenseCounts.reduce(into: [:]) { result, entry in
            result[entry.key.uuidString] = entry.value
        }
        defaults.set(countDict, forKey: Self.archivedLedgerExpenseCountKey)
    }
    
    func memberBreakdown(ledgerId: UUID, memberId: UUID) -> (breakdown: [CategoryBreakdown], timeline: [TimeSeriesPoint]) {
        guard let info = ledgerInfos[ledgerId] else { return ([], []) }
        let expenses = info.expenses.filter { expense in
            expense.payerId == memberId || expense.participants.contains(where: { $0.userId == memberId })
        }
        let totalMinor = expenses.reduce(0) { $0 + $1.amountMinorUnits }
        
        let categoryGroups = Dictionary(grouping: expenses, by: { $0.category })
        let breakdown = categoryGroups.map { (category: ExpenseCategory, categoryExpenses: [ExpenseInput]) -> CategoryBreakdown in
            let subtotal = categoryExpenses.reduce(0) { $0 + $1.amountMinorUnits }
            let percentage = totalMinor == 0 ? 0 : Double(subtotal) / Double(totalMinor)
            return CategoryBreakdown(category: category, totalMinorUnits: subtotal, percentage: percentage)
        }.sorted { $0.totalMinorUnits > $1.totalMinorUnits }

        let calendar = Calendar.current
        let dateGroups = Dictionary(grouping: expenses) { (expense: ExpenseInput) -> Date in
            calendar.startOfDay(for: expense.date)
        }
        let timeline = dateGroups.map { (date: Date, dateExpenses: [ExpenseInput]) -> TimeSeriesPoint in
            let amount = dateExpenses.reduce(0) { $0 + $1.amountMinorUnits }
            return TimeSeriesPoint(date: date, amountMinorUnits: amount)
        }.sorted { $0.date < $1.date }
        
        return (breakdown, timeline)
    }
}
