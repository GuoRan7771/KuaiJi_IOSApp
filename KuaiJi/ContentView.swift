//
//  ContentView.swift
//  KuaiJi
//
//  Shared ledger UI skeleton with view model protocols and SwiftUI structure.
//

import SwiftUI
import Combine

// MARK: - View Data Models

struct LedgerSummaryViewData: Identifiable, Hashable {
    var id: UUID
    var name: String
    var memberCount: Int
    var currency: CurrencyCode
    var outstandingDisplay: String
    var updatedAt: Date
}

struct LedgerDetailViewData: Hashable {
    var id: UUID
    var name: String
    var currency: CurrencyCode
    var totalSpentDisplay: String
    var filterSummary: String
}

struct LedgerRecordViewData: Identifiable, Hashable {
    var id: UUID
    var ledgerId: UUID
    var ledgerName: String
    var title: String
    var amountDisplay: String
    var date: Date
    var category: ExpenseCategory
    var payerName: String
}

struct NetBalanceViewData: Identifiable, Hashable {
    var id: UUID
    var userName: String
    var amountMinorUnits: Int
    var amountDisplay: String

    var isPositive: Bool { amountMinorUnits >= 0 }
}

struct LedgerFilterState: Hashable {
    var fromDate: Date?
    var toDate: Date?
    var categories: Set<ExpenseCategory>
    var memberIds: Set<UUID>

    init(fromDate: Date? = nil, toDate: Date? = nil, categories: Set<ExpenseCategory> = [], memberIds: Set<UUID> = []) {
        self.fromDate = fromDate
        self.toDate = toDate
        self.categories = categories
        self.memberIds = memberIds
    }

    var isEmpty: Bool {
        fromDate == nil && toDate == nil && categories.isEmpty && memberIds.isEmpty
    }

    var summaryDescription: String {
        var components: [String] = []
        if let fromDate { components.append("从 \(formatted(date: fromDate))") }
        if let toDate { components.append("到 \(formatted(date: toDate))") }
        if !categories.isEmpty { components.append("分类: \(categories.map { $0.rawValue }.joined(separator: ", "))") }
        if !memberIds.isEmpty { components.append("成员筛选 x\(memberIds.count)") }
        return components.isEmpty ? "" : components.joined(separator: " • ")
    }

    private func formatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct MemberSummaryViewData: Identifiable, Hashable {
    var id: UUID
    var name: String
    var avatarSystemName: String
    var currency: CurrencyCode
    var avatarEmoji: String?
    
    var displayAvatar: String {
        avatarEmoji ?? "👤"
    }
}

struct MemberExpenseViewData: Identifiable, Hashable {
    var id: UUID
    var name: String
    var avatarEmoji: String?
    var totalSpentMinorUnits: Int
    var totalSpentDisplay: String
    
    var displayAvatar: String {
        avatarEmoji ?? "👤"
    }
}

struct CategoryBreakdown: Identifiable, Hashable {
    var id: UUID = UUID()
    var category: ExpenseCategory
    var totalMinorUnits: Int
    var percentage: Double
}

struct TimeSeriesPoint: Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var amountMinorUnits: Int
}

struct ExpenseDraftViewData: Hashable {
    var title: String
    var amount: Decimal
    var date: Date
    var payerId: UUID
    var splitStrategy: SplitStrategy
    var includePayer: Bool
    var participantShares: [ExpenseParticipantShare]
    var note: String
    var category: ExpenseCategory

    mutating func replaceParticipantShares(_ shares: [ExpenseParticipantShare]) {
        participantShares = shares
    }
}

enum ExpenseSplitOption: String, CaseIterable, Identifiable {
    case meAllAA
    case otherAllAA
    case meTreat
    case otherTreat
    case helpPay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .meAllAA: return L.splitMeAllAA.localized
        case .otherAllAA: return L.splitOtherAllAA.localized
        case .meTreat: return L.splitMeTreat.localized
        case .otherTreat: return L.splitOtherTreat.localized
        case .helpPay: return L.splitHelpPay.localized
        }
    }
    
    var description: String {
        switch self {
        case .meAllAA: return L.splitMeAllAADesc.localized
        case .otherAllAA: return L.splitOtherAllAADesc.localized
        case .meTreat: return L.splitMeTreatDesc.localized
        case .otherTreat: return L.splitOtherTreatDesc.localized
        case .helpPay: return L.splitHelpPayDesc.localized
        }
    }
}

struct TransferRecordViewData: Identifiable, Hashable {
    var id: UUID = UUID()
    var fromName: String
    var toName: String
    var amountDisplay: String
}

enum LanguageOption: String, CaseIterable, Identifiable {
    case system
    case zh
    case en
    case fr

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return L.languageSystem.localized
        case .zh: return L.languageChinese.localized
        case .en: return L.languageEnglish.localized
        case .fr: return L.languageFrench.localized
        }
    }

    var localeIdentifier: String? {
        switch self {
        case .system: return nil
        case .zh: return "zh_CN"
        case .en: return "en_US"
        case .fr: return "fr_FR"
        }
    }

    static func from(localeIdentifier: String) -> LanguageOption {
        switch localeIdentifier {
        case "zh_CN": return .zh
        case "en_US": return .en
        case "fr_FR": return .fr
        default: return .system
        }
    }
}

struct SettingsViewState: Hashable {
    var language: LanguageOption
}

// MARK: - ViewModel Protocols

protocol LedgerListViewModelProtocol: ObservableObject {
    var ledgers: [LedgerSummaryViewData] { get }
    var availableMembers: [MemberSummaryViewData] { get }
    var currentUser: MemberSummaryViewData { get }
    func createLedger(name: String, memberIds: [UUID], currency: CurrencyCode)
    func deleteLedgers(at offsets: IndexSet)
}

protocol LedgerOverviewViewModelProtocol: ObservableObject {
    var ledger: LedgerDetailViewData { get }
    var filters: LedgerFilterState { get set }
    var balances: [NetBalanceViewData] { get }
    var members: [MemberSummaryViewData] { get }
    var memberExpenses: [MemberExpenseViewData] { get }
    var records: [LedgerRecordViewData] { get }
    func refresh()
    func member(for userId: UUID) -> MemberSummaryViewData?
    func deleteExpense(at offsets: IndexSet)
    func clearAllBalances()
}

protocol ExpenseFormViewModelProtocol: ObservableObject {
    var draft: ExpenseDraftViewData { get set }
    var splitPreview: [NetBalanceViewData] { get }
    var currencyCode: String { get }
    var participantNames: String { get }
    var splitOption: ExpenseSplitOption { get }
    var availableMembers: [MemberSummaryViewData] { get }
    var selectableOtherPayers: [MemberSummaryViewData] { get }
    var selectedOtherPayerId: UUID? { get }
    var selectableHelpPayPayers: [MemberSummaryViewData] { get }
    var selectedHelpPayPayerId: UUID? { get }
    var selectableBeneficiaries: [MemberSummaryViewData] { get }
    var selectedBeneficiaryId: UUID? { get }
    var validationError: String? { get }  // 新增：验证错误信息
    func selectSplitOption(_ option: ExpenseSplitOption)
    func selectOtherPayer(id: UUID)
    func selectHelpPayPayer(id: UUID)
    func selectBeneficiary(id: UUID)
    func regeneratePreview()
    func saveDraft()
    func validateSplitAmounts() -> Bool  // 新增：验证分账金额
}

protocol SettlementViewModelProtocol: ObservableObject {
    var netBalances: [NetBalanceViewData] { get }
    var transferPlan: [TransferRecordViewData] { get }
    func generatePlan()
    func clearAllBalances()
}

protocol MemberDetailViewModelProtocol: ObservableObject {
    var member: MemberSummaryViewData { get }
    var breakdown: [CategoryBreakdown] { get }
    var timeline: [TimeSeriesPoint] { get }
}

protocol FriendListViewModelProtocol: ObservableObject {
    var friends: [MemberSummaryViewData] { get }
    func addFriend(named name: String, emoji: String?, currency: CurrencyCode)
    func addFriendFromQRCode(userId: String, named name: String, emoji: String?, currency: CurrencyCode) -> Bool
    func deleteFriend(at offsets: IndexSet)
    func updateFriend(id: UUID, name: String, currency: CurrencyCode, emoji: String?)
}

protocol RecordsViewModelProtocol: ObservableObject {
    var records: [LedgerRecordViewData] { get }
    func refresh()
}

protocol SettingsViewModelProtocol: ObservableObject {
    var uiState: SettingsViewState { get set }
    func persist()
    func clearAllData()
    func getCurrentUser() -> UserProfile?
    func updateUserProfile(name: String, emoji: String, currency: CurrencyCode)
}

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

    @Published fileprivate var ledgerInfos: [UUID: LedgerInfo]
    @Published private(set) var ledgerSummaries: [LedgerSummaryViewData]
    @Published private(set) var settings: LedgerSettings
    @Published private(set) var friends: [MemberSummaryViewData]

    @Published private(set) var localeIdentifier: String
    @Published private(set) var currentUser: MemberSummaryViewData
    private var memberLookup: [UUID: MemberSummaryViewData]
    
    var dataManager: PersistentDataManager?

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
    }
    
    func setDataManager(_ manager: PersistentDataManager) {
        self.dataManager = manager
        loadFromPersistence()
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
            let expenses = ledger.expenses.map { expense in
                let participants = expense.participants.map { participant in
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

    func allLedgerRecords() -> [LedgerRecordViewData] {
        ledgerInfos.values.flatMap { records(from: $0) }.sorted { $0.date > $1.date }
    }

    private func records(from info: LedgerInfo) -> [LedgerRecordViewData] {
        let locale = Locale(identifier: localeIdentifier)
        return info.expenses.map { expense in
            let totalMinor = expense.amountMinorUnits + expense.metadata.tipMinorUnits + expense.metadata.taxMinorUnits
            let amountDisplay = AmountFormatter.string(minorUnits: totalMinor, currency: info.currency, locale: locale)
            let payerName = memberLookup[expense.payerId]?.name ?? L.defaultUnknownMember.localized
            let title = expense.title.isEmpty ? L.defaultUntitledExpense.localized : expense.title
            return LedgerRecordViewData(id: expense.id,
                                        ledgerId: info.id,
                                        ledgerName: info.name,
                                        title: title,
                                        amountDisplay: amountDisplay,
                                        date: expense.date,
                                        category: expense.category,
                                        payerName: payerName)
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
                                         updatedAt: info.updatedAt)
        }
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

// MARK: - Screen ViewModels

@MainActor
final class LedgerListScreenModel: ObservableObject, LedgerListViewModelProtocol {
    @Published private(set) var ledgers: [LedgerSummaryViewData]
    @Published private(set) var availableMembers: [MemberSummaryViewData]
    private weak var root: AppRootViewModel?
    private var cancellables: Set<AnyCancellable> = []

    var currentUser: MemberSummaryViewData {
        root?.currentUser ?? MemberSummaryViewData(id: UUID(), name: L.createLedgerMe.localized, avatarSystemName: "person.fill", currency: .cny, avatarEmoji: "👤")
    }

    init(root: AppRootViewModel) {
        self.root = root
        self.ledgers = root.ledgerSummaries
        self.availableMembers = root.friends

        root.$ledgerSummaries
            .receive(on: RunLoop.main)
            .sink { [weak self] summaries in
                self?.ledgers = summaries
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

struct ExpenseFormView<Model: ExpenseFormViewModelProtocol>: View {
    @ObservedObject var viewModel: Model
    @State private var showingOtherPayerSheet = false
    @State private var showingHelpPayPayerSheet = false
    @State private var showingBeneficiarySheet = false
    @State private var amountText: String = ""
    @FocusState private var isAmountFocused: Bool
    
    private var selectedHelpPayPayerName: String {
        guard let id = viewModel.selectedHelpPayPayerId else { return "" }
        return viewModel.selectableHelpPayPayers.first(where: { $0.id == id })?.name ?? ""
    }
    
    private var selectedBeneficiaryName: String {
        guard let id = viewModel.selectedBeneficiaryId else { return "" }
        return viewModel.selectableBeneficiaries.first(where: { $0.id == id })?.name ?? ""
    }

    var body: some View {
        Form {
            // 第一栏：支出金额
            Section {
                HStack(spacing: 8) {
                    Text(viewModel.currencyCode)
                        .foregroundStyle(.secondary)
                        .font(.title3)
                        .fontWeight(.medium)
                     TextField(placeholderText, text: $amountText)
                         .keyboardType(.decimalPad)
                         .multilineTextAlignment(.trailing)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .focused($isAmountFocused)
                        .onChange(of: amountText) { oldValue, newValue in
                            // 实时验证并限制只能输入2位小数
                            let validated = validateDecimalInput(newValue, maxDecimalPlaces: 2, oldValue: oldValue)
                            if validated != newValue {
                                amountText = validated
                            }
                            if let decimal = parseDecimal(from: validated) {
                                viewModel.draft.amount = decimal
                                viewModel.regeneratePreview()
                            }
                        }
                        .onChange(of: isAmountFocused) { oldValue, focused in
                            let separator = decimalSeparator
                            let zeroString = "0\(separator)00"
                            if focused && amountText == zeroString {
                                amountText = ""
                            } else if !focused && amountText.isEmpty {
                                amountText = zeroString
                            }
                        }
                        .onAppear {
                            let separator = decimalSeparator
                            if viewModel.draft.amount == 0 {
                                amountText = "0\(separator)00"
                            } else {
                                // 使用当前区域设置格式化金额
                                amountText = formatAmount(viewModel.draft.amount)
                            }
                        }
                }
                .padding(.vertical, 8)
            } header: {
                Text(L.expenseAmount.localized)
            } footer: {
                // 显示验证错误
                if let error = viewModel.validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(ExpenseSplitOption.allCases) { option in
                        VStack(alignment: .leading, spacing: 4) {
                            Button {
                                viewModel.selectSplitOption(option)
                                if option == .otherAllAA || option == .otherTreat {
                                    if !viewModel.selectableOtherPayers.isEmpty {
                                        showingOtherPayerSheet = true
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: viewModel.splitOption == option ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(viewModel.splitOption == option ? Color.blue : Color.secondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.title)
                                            .font(.headline)
                                            .foregroundStyle(.primary)
                                        
                                        Text(option.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                if viewModel.splitOption == .otherAllAA || viewModel.splitOption == .otherTreat {
                    if viewModel.selectableOtherPayers.isEmpty {
                        Text(L.splitAddOtherMembers.localized)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    } else {
                        HStack {
                            Text(L.splitPayer.localized)
                            Spacer()
                            Text(selectedOtherPayerName)
                                .foregroundStyle(.blue)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingOtherPayerSheet = true
                        }
                        .confirmationDialog(L.splitSelectPayer.localized, isPresented: $showingOtherPayerSheet, titleVisibility: .visible) {
                            ForEach(viewModel.selectableOtherPayers) { member in
                                Button(member.name) {
                                    viewModel.selectOtherPayer(id: member.id)
                                }
                            }
                            Button(L.cancel.localized, role: .cancel) { }
                        }
                    }
                }
                
                if viewModel.splitOption == .helpPay {
                    if viewModel.availableMembers.count < 2 {
                        Text(L.splitAddOtherMembers.localized)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    } else {
                        VStack(spacing: 12) {
                            // 付款人选择器
                            HStack {
                                Text(L.splitPayer.localized)
                                Spacer()
                                Text(selectedHelpPayPayerName)
                                    .foregroundStyle(.blue)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showingHelpPayPayerSheet = true
                            }
                            .confirmationDialog(L.splitSelectPayer.localized, isPresented: $showingHelpPayPayerSheet, titleVisibility: .visible) {
                                ForEach(viewModel.selectableHelpPayPayers) { member in
                                    Button(member.name) {
                                        viewModel.selectHelpPayPayer(id: member.id)
                                    }
                                }
                                Button(L.cancel.localized, role: .cancel) { }
                            }
                            
                            Divider()
                            
                            // 受益人选择器
                            HStack {
                                Text(L.splitBeneficiary.localized)
                                Spacer()
                                Text(selectedBeneficiaryName)
                                    .foregroundStyle(.blue)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showingBeneficiarySheet = true
                            }
                            .confirmationDialog(L.splitSelectBeneficiary.localized, isPresented: $showingBeneficiarySheet, titleVisibility: .visible) {
                                ForEach(viewModel.selectableBeneficiaries) { member in
                                    Button(member.name) {
                                        viewModel.selectBeneficiary(id: member.id)
                                    }
                                }
                                Button(L.cancel.localized, role: .cancel) { }
                            }
                        }
                    }
                }
            } header: {
                Text(L.expenseSplitMethod.localized)
            }
            
            // 第四栏：基本信息（可选填写）
            Section {
                TextField(L.expensePurposePlaceholder.localized, text: binding(
                    get: { viewModel.draft.title },
                    set: { viewModel.draft.title = $0 }
                ))
                .submitLabel(.done)
                
                DatePicker(L.expenseDate.localized, selection: binding(
                    get: { viewModel.draft.date },
                    set: { viewModel.draft.date = $0 }
                ), displayedComponents: [.date, .hourAndMinute])
                
                Picker(L.expenseCategory.localized, selection: binding(
                    get: { viewModel.draft.category },
                    set: { viewModel.draft.category = $0 }
                )) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        Text(category.displayName).tag(category)
                    }
                }
            } header: {
                Text(L.expenseBasicInfo.localized)
            } footer: {
                Text(L.expenseOptionalFields.localized)
                    .font(.caption2)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
    }

    private var selectedOtherPayerName: String {
        guard let id = viewModel.selectedOtherPayerId,
              let member = viewModel.selectableOtherPayers.first(where: { $0.id == id }) else {
            return "请选择"
        }
        return member.name
    }

    private func binding<Value>(get: @escaping () -> Value, set: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(get: get, set: { newValue in
            set(newValue)
            viewModel.regeneratePreview()
        })
    }
    
    /// 获取当前区域设置的小数分隔符
    private var decimalSeparator: String {
        Locale.current.decimalSeparator ?? "."
    }
    
    /// 获取当前区域设置的千位分隔符
    private var groupingSeparator: String {
        Locale.current.groupingSeparator ?? ","
    }
    
    /// placeholder 文本（根据地区设置显示）
    private var placeholderText: String {
        "0\(decimalSeparator)00"
    }
    
    /// 使用当前区域设置格式化金额
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
    
    /// 使用当前区域设置解析 Decimal
    private func parseDecimal(from string: String) -> Decimal? {
        // 移除千位分隔符
        let cleanString = string.replacingOccurrences(of: groupingSeparator, with: "")
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        
        if let number = formatter.number(from: cleanString) {
            return number.decimalValue
        }
        return nil
    }
    
    /// 验证并限制小数输入位数（支持不同地区的小数分隔符）
    private func validateDecimalInput(_ input: String, maxDecimalPlaces: Int, oldValue: String) -> String {
        // 允许空字符串
        if input.isEmpty { return input }
        
        let separator = decimalSeparator
        
        // 移除千位分隔符（用户可能复制粘贴了包含千位分隔符的数字）
        let cleanInput = input.replacingOccurrences(of: groupingSeparator, with: "")
        
        // 检查小数点
        let components = cleanInput.split(separator: Character(separator), omittingEmptySubsequences: false)
        
        // 只允许一个小数点
        if components.count > 2 { return oldValue }
        
        // 限制小数位数
        if components.count == 2 {
            let decimalPart = String(components[1])
            if decimalPart.count > maxDecimalPlaces {
                // 截断到最大位数
                return "\(components[0])\(separator)\(decimalPart.prefix(maxDecimalPlaces))"
            }
        }
        
        // 验证是否为有效数字（包括"10."这样的中间状态）
        if cleanInput.last?.description == separator {
            // 允许以小数点结尾（输入中间状态）
            let prefix = String(cleanInput.dropLast())
            if prefix.isEmpty || parseDecimal(from: prefix) != nil {
                return cleanInput
            }
        }
        
        guard parseDecimal(from: cleanInput) != nil else { return oldValue }
        
        return cleanInput
    }
}

struct ExpenseFormHost: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ExpenseFormScreenModel

    init(rootViewModel: AppRootViewModel, ledgerId: UUID) {
        _viewModel = StateObject(wrappedValue: rootViewModel.makeExpenseFormViewModel(ledgerId: ledgerId))
    }

    var body: some View {
        NavigationStack {
            ExpenseFormView(viewModel: viewModel)
                .navigationTitle(L.expenseTitle.localized)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L.cancel.localized, action: dismiss.callAsFunction)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L.save.localized) {
                            // 先验证，验证通过才保存
                            if viewModel.validateSplitAmounts() {
                                viewModel.saveDraft()
                                dismiss()
                            }
                            // 如果验证失败，validationError 会自动显示在UI上
                        }
                        .disabled(viewModel.draft.amount <= .zero)
                    }
                }
        }
    }
}

struct SettlementHost: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SettlementScreenModel

    init(rootViewModel: AppRootViewModel, ledgerId: UUID) {
        _viewModel = StateObject(wrappedValue: rootViewModel.makeSettlementViewModel(ledgerId: ledgerId))
    }

    var body: some View {
        NavigationStack {
            SettlementView(viewModel: viewModel)
                .navigationTitle(L.settlementTitle.localized)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L.close.localized, action: dismiss.callAsFunction) }
                }
        }
    }
}

struct SettlementView<Model: SettlementViewModelProtocol>: View {
    @ObservedObject var viewModel: Model
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirmation = false

    var body: some View {
        List {
            Section(L.settlementCurrentNet.localized) {
                ForEach(viewModel.netBalances) { balance in
                    HStack {
                        Text(balance.userName)
                        Spacer()
                        Text(balance.amountDisplay)
                            .foregroundStyle(balance.isPositive ? Color.green : Color.red)
                    }
                }
            }

            Section(L.settlementMinTransfers.localized) {
                if viewModel.transferPlan.isEmpty {
                    Text(L.settlementAllSettled.localized)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.transferPlan) { transfer in
                        VStack(alignment: .leading) {
                            Text("\(transfer.fromName) → \(transfer.toName)")
                            Text(transfer.amountDisplay)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // 一键清账按钮
                if !viewModel.transferPlan.isEmpty {
                    Button(action: { showClearConfirmation = true }) {
                        HStack {
                            Label(L.ledgerCardClearBalances.localized, systemImage: "checkmark.circle")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.1)))
                        .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
        }
        .onAppear(perform: viewModel.generatePlan)
        .alert(L.clearBalancesConfirmTitle.localized, isPresented: $showClearConfirmation) {
            Button(L.cancel.localized, role: .cancel) { }
            Button(L.clearBalancesConfirmButton.localized) {
                viewModel.clearAllBalances()
                dismiss()
            }
        } message: {
            Text(L.clearBalancesConfirmMessage.localized)
        }
    }
}

struct MemberDetailHost: View {
    @StateObject private var viewModel: MemberDetailScreenModel

    init(rootViewModel: AppRootViewModel, ledgerId: UUID, member: MemberSummaryViewData) {
        _viewModel = StateObject(wrappedValue: rootViewModel.makeMemberDetailViewModel(memberId: member.id, ledgerId: ledgerId))
    }

    var body: some View {
        MemberDetailView(viewModel: viewModel)
            .navigationTitle(viewModel.member.name)
    }
}

struct MemberDetailView<Model: MemberDetailViewModelProtocol>: View {
    @ObservedObject var viewModel: Model

    var body: some View {
        List {
            Section("分类占比") {
                ForEach(viewModel.breakdown) { item in
                    HStack {
                        Text(item.category.displayName)
                        Spacer()
                        Text(String(format: "%.0f%%", item.percentage * 100))
                    }
                }
            }

            Section("时间走势") {
                ForEach(viewModel.timeline) { point in
                    HStack {
                        Text(point.date, style: .date)
                        Spacer()
                        Text(AmountFormatter.string(minorUnits: point.amountMinorUnits, currency: .eur, locale: Locale.current))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct SettingsView<Model: SettingsViewModelProtocol>: View {
    @ObservedObject var viewModel: Model
    @ObservedObject var rootViewModel: AppRootViewModel
    @EnvironmentObject var appState: AppState
    @State private var showingContactSheet = false
    @State private var showingClearDataAlert = false
    @State private var showingProfileEdit = false
    @State private var showingGuide = false
    @State private var selectedLedgerId: UUID?

    var body: some View {
        Form {
            // 个人信息
            Section {
                if let currentUser = viewModel.getCurrentUser() {
                    Button {
                        showingProfileEdit = true
                    } label: {
                        HStack(spacing: 12) {
                            Text(currentUser.avatarEmoji ?? "👤")
                                .font(.largeTitle)
                                .frame(width: 50, height: 50)
                                .background(Circle().fill(Color.secondary.opacity(0.1)))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentUser.name)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(L.profileUserIdLabel.localized(currentUser.userId))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(L.profileCurrencyLabel.localized(currentUser.currency.rawValue))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text(L.profileTitle.localized)
            } footer: {
                Text(L.profileViewInfo.localized)
                    .font(.caption)
            }
            
            Section {
                Button {
                    openSystemSettings()
                } label: {
                    HStack {
                        Text(L.settingsLanguage.localized)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text(L.settingsLanguageDesc.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // 快速记账默认账本设置
            Section {
                Picker(L.settingsDefaultLedger.localized, selection: $selectedLedgerId) {
                    Text(L.settingsDefaultLedgerNone.localized)
                        .tag(nil as UUID?)
                    
                    ForEach(rootViewModel.ledgerSummaries, id: \.id) { ledger in
                        Text(ledger.name)
                            .tag(ledger.id as UUID?)
                    }
                }
                .onChangeCompat(of: selectedLedgerId) {
                    appState.setDefaultLedgerId(selectedLedgerId)
                }
            } header: {
                Text(L.settingsQuickActionSection.localized)
            } footer: {
                Text(L.settingsDefaultLedgerDesc.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section(L.settingsAbout.localized) {
                Button {
                    showingGuide = true
                } label: {
                    HStack {
                        Text(L.settingsGuide.localized)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Button {
                    showingContactSheet = true
                } label: {
                    HStack {
                        Text(L.settingsContactMe.localized)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Section {
                Button(role: .destructive) {
                    showingClearDataAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Text(L.settingsClearData.localized)
                        Spacer()
                    }
                }
            } footer: {
                Text(L.settingsClearDataWarning.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(L.settingsTitle.localized)
        .onAppear {
            // 初始化选中的账本ID
            selectedLedgerId = appState.getDefaultLedgerId()
        }
        .sheet(isPresented: $showingContactSheet) {
            ContactView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingProfileEdit) {
            if let currentUser = viewModel.getCurrentUser() {
                ProfileEditView(currentUser: currentUser) { name, emoji, currency in
                    viewModel.updateUserProfile(name: name, emoji: emoji, currency: currency)
                }
            }
        }
        .sheet(isPresented: $showingGuide) {
            WelcomeGuideView {
                showingGuide = false
            }
        }
        .alert(L.settingsConfirmDelete.localized, isPresented: $showingClearDataAlert) {
            Button(L.cancel.localized, role: .cancel) { }
            Button(L.delete.localized, role: .destructive) {
                viewModel.clearAllData()
                // 清除数据后，检查并重新显示首次设置界面
                appState.checkOnboardingStatus()
            }
        } message: {
            Text(L.settingsDeleteMessage.localized)
        }
    }
    
    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }

    private func binding<Value>(get: @escaping () -> Value, set: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(get: get, set: set)
    }
}

struct ContactView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Liquid glass background with animated gradient
            AnimatedLiquidBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Apple Logo with dynamic rainbow effect
                ZStack {
                    // Multiple animated gradient circles for liquid glass effect
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(
                                AngularGradient(
                                    gradient: Gradient(colors: [
                                        Color(red: 1.0, green: 0.0, blue: 0.0),    // Red
                                        Color(red: 1.0, green: 0.6, blue: 0.0),    // Orange
                                        Color(red: 1.0, green: 1.0, blue: 0.0),    // Yellow
                                        Color(red: 0.0, green: 1.0, blue: 0.0),    // Green
                                        Color(red: 0.0, green: 0.6, blue: 1.0),    // Blue
                                        Color(red: 0.4, green: 0.0, blue: 1.0),    // Indigo
                                        Color(red: 0.8, green: 0.0, blue: 1.0),    // Purple
                                        Color(red: 1.0, green: 0.0, blue: 0.0)     // Red
                                    ]),
                                    center: .center,
                                    angle: .degrees(rotationAngle + Double(index * 120))
                                )
                            )
                            .frame(width: 140 + CGFloat(index * 20), height: 140 + CGFloat(index * 20))
                            .blur(radius: 30 + CGFloat(index * 10))
                            .opacity(0.6 - Double(index) * 0.15)
                            .scaleEffect(pulseScale)
                    }
                    
                    Image(systemName: "apple.logo")
                        .font(.system(size: 70, weight: .ultraLight))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .white.opacity(0.5), radius: 10)
                }
                .scaleEffect(pulseScale)
                
                // Text content with liquid glass effect
                VStack(spacing: 16) {
                    Text("Guo")
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .white.opacity(0.5), radius: 8)
                    
                    Text("rwg184849@gmail.com")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.ultraThinMaterial)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(.white.opacity(0.3), lineWidth: 1)
                                )
                        )
                        .shadow(color: .black.opacity(0.2), radius: 10)
                }
                
                Spacer()
                Spacer()
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                rotationAngle = 360
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        }
    }
}

struct AnimatedLiquidBackground: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Base dark background
            Color.black
            
            // Multiple liquid gradient layers
            ForEach(0..<3) { index in
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                rainbowColor(for: index).opacity(0.3),
                                rainbowColor(for: index).opacity(0.15),
                                .clear
                            ],
                            center: .center,
                            startRadius: 50,
                            endRadius: 400
                        )
                    )
                    .frame(width: 500, height: 500)
                    .offset(
                        x: animate ? randomOffset(index) : -randomOffset(index),
                        y: animate ? randomOffset(index + 1) : -randomOffset(index + 1)
                    )
                    .blur(radius: 60)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animate.toggle()
            }
        }
    }
    
    private func rainbowColor(for index: Int) -> Color {
        let colors: [Color] = [
            Color(red: 1.0, green: 0.0, blue: 0.5),    // Pink
            Color(red: 0.0, green: 0.5, blue: 1.0),    // Blue
            Color(red: 0.5, green: 0.0, blue: 1.0)     // Purple
        ]
        return colors[index % colors.count]
    }
    
    private func randomOffset(_ seed: Int) -> CGFloat {
        let offsets: [CGFloat] = [100, -80, 120, -90, 110]
        return offsets[seed % offsets.count]
    }
}


private extension ExpenseCategory {
    var displayName: String {
        switch self {
        case .food: return L.categoryFood.localized
        case .transport: return L.categoryTransport.localized
        case .accommodation: return L.categoryAccommodation.localized
        case .entertainment: return L.categoryEntertainment.localized
        case .utilities: return L.categoryUtilities.localized
        case .other: return L.categoryOther.localized
        }
    }
}


private extension View {
    @ViewBuilder
    func onChangeCompat<Value: Equatable>(of value: Value, perform action: @escaping () -> Void) -> some View {
        if #available(iOS 17, *) {
            onChange(of: value, initial: false) { _, _ in action() }
        } else {
            onChange(of: value) { _ in action() }
        }
    }
}

// MARK: - Main ContentView & Navigation

struct ContentView: View {
    @ObservedObject var viewModel: AppRootViewModel
    @StateObject private var listViewModel: LedgerListScreenModel
    @StateObject private var friendViewModel: FriendListScreenModel
    @StateObject private var settingsViewModel: SettingsScreenModel
    @EnvironmentObject var appState: AppState

    init(viewModel: AppRootViewModel) {
        self.viewModel = viewModel
        _listViewModel = StateObject(wrappedValue: viewModel.makeLedgerListViewModel())
        _friendViewModel = StateObject(wrappedValue: viewModel.makeFriendListViewModel())
        _settingsViewModel = StateObject(wrappedValue: viewModel.makeSettingsViewModel())
    }

    var body: some View {
        TabView {
            LedgerNavigator(rootViewModel: viewModel, listViewModel: listViewModel)
                .tabItem { Label(L.tabLedgers.localized, systemImage: "list.bullet") }

            FriendNavigator(viewModel: friendViewModel, rootViewModel: viewModel)
                .tabItem { Label(L.tabFriends.localized, systemImage: "person.2.fill") }

            SettingsNavigator(viewModel: settingsViewModel, rootViewModel: viewModel)
                .tabItem { Label(L.tabSettings.localized, systemImage: "gearshape") }
        }
    }
}

struct LedgerNavigator: View {
    @ObservedObject var rootViewModel: AppRootViewModel
    @ObservedObject var listViewModel: LedgerListScreenModel
    @EnvironmentObject var appState: AppState
    @State private var showingCreateLedger = false
    @State private var showingShareLedger = false
    @State private var quickActionLedger: LedgerSummaryViewData?
    @State private var showQuickExpenseForm = false

    var body: some View {
        NavigationStack {
            LedgerListView(viewModel: listViewModel)
                .navigationTitle(L.ledgersPageTitle.localized)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showingShareLedger = true }) {
                            Label(L.syncShareLedger.localized, systemImage: "antenna.radiowaves.left.and.right")
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingCreateLedger = true }) {
                            Label(L.ledgersNew.localized, systemImage: "plus")
                        }
                    }
                }
                .navigationDestination(for: LedgerSummaryViewData.self) { summary in
                    LedgerOverviewHost(rootViewModel: rootViewModel, summary: summary)
                }
                .sheet(isPresented: $showingCreateLedger) {
                    CreateLedgerSheet(viewModel: listViewModel)
                }
                .sheet(isPresented: $showingShareLedger) {
                    NearbyDevicesHost(rootViewModel: rootViewModel)
                }
                .sheet(isPresented: $showQuickExpenseForm) {
                    if let ledger = quickActionLedger {
                        ExpenseFormHost(rootViewModel: rootViewModel, ledgerId: ledger.id)
                    }
                }
                .onChangeCompat(of: appState.quickActionLedgerId) {
                    handleQuickAction()
                }
        }
    }
    
    private func handleQuickAction() {
        guard let ledgerId = appState.quickActionLedgerId else {
            print("⚠️ quickActionLedgerId 为空")
            return
        }
        
        print("🔍 处理 Quick Action，账本ID: \(ledgerId.uuidString)")
        print("📋 可用账本: \(rootViewModel.ledgerSummaries.map { "\($0.name) (\($0.id.uuidString))" }.joined(separator: ", "))")
        
        guard let summary = rootViewModel.ledgerSummaries.first(where: { $0.id == ledgerId }) else {
            print("❌ 找不到账本 summary")
            appState.quickActionLedgerId = nil
            return
        }
        
        print("✅ 找到账本: \(summary.name)")
        
        // 清除 Quick Action 状态
        appState.quickActionLedgerId = nil
        
        // 打开记账表单
        quickActionLedger = summary
        showQuickExpenseForm = true
        
        print("✅ 已设置打开记账表单")
    }
}

struct SettingsNavigator: View {
    @ObservedObject var viewModel: SettingsScreenModel
    @ObservedObject var rootViewModel: AppRootViewModel
    
    var body: some View {
        NavigationStack {
            SettingsView(viewModel: viewModel, rootViewModel: rootViewModel)
        }
    }
}

struct FriendNavigator: View {
    @ObservedObject var viewModel: FriendListScreenModel
    @ObservedObject var rootViewModel: AppRootViewModel
    @State private var showingAddFriend = false
    @State private var showingMyQRCode = false
    @State private var showingScanner = false
    @State private var showingDuplicateAlert = false
    @State private var duplicateMessage = ""

    var body: some View {
        NavigationStack {
            FriendListView(viewModel: viewModel)
                .navigationTitle(L.friendsTitle.localized)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Button {
                                showingAddFriend = true
                            } label: {
                                Label(L.friendMenuManualInput.localized, systemImage: "keyboard")
                            }
                            
                            Button {
                                showingMyQRCode = true
                            } label: {
                                Label(L.friendMenuMyQRCode.localized, systemImage: "qrcode")
                            }
                            
                            Button {
                                showingScanner = true
                            } label: {
                                Label(L.friendMenuScanQRCode.localized, systemImage: "qrcode.viewfinder")
                            }
                        } label: {
                            Label(L.friendsAdd.localized, systemImage: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingAddFriend) {
                    AddFriendSheet(viewModel: viewModel)
                }
                .sheet(isPresented: $showingMyQRCode) {
                    if let currentUser = rootViewModel.dataManager?.currentUser {
                        MyQRCodeView(userData: UserQRCodeData(
                            userId: currentUser.userId,
                            name: currentUser.name,
                            emoji: currentUser.avatarEmoji ?? "👤",
                            currency: currentUser.currency.rawValue
                        ))
                    }
                }
                .sheet(isPresented: $showingScanner) {
                    QRCodeScannerView { userData in
                        // 将扫描到的朋友信息添加到朋友列表
                        // 如果朋友已存在，会自动更新其最新信息
                        if let currencyCode = CurrencyCode(rawValue: userData.currency) {
                            let success = viewModel.addFriendFromQRCode(
                                userId: userData.userId,
                                named: userData.name,
                                emoji: userData.emoji,
                                currency: currencyCode
                            )
                            
                            if !success {
                                duplicateMessage = L.qrcodeCannotAddSelf.localized
                                showingDuplicateAlert = true
                            }
                        }
                    }
                }
                .alert(L.qrcodeAlertTitle.localized, isPresented: $showingDuplicateAlert) {
                    Button(L.ok.localized, role: .cancel) { }
                } message: {
                    Text(duplicateMessage)
                }
        }
    }
}

struct LedgerListView<Model: LedgerListViewModelProtocol>: View {
    @ObservedObject var viewModel: Model

    var body: some View {
        List {
            Section(L.ledgersRecentUpdates.localized) {
                ForEach(viewModel.ledgers) { ledger in
                    NavigationLink(value: ledger) {
                        LedgerSummaryRow(ledger: ledger)
                    }
                    .accessibilityLabel("\(ledger.name), \(L.ledgersMemberCount.localized(ledger.memberCount)), \(L.ledgersOutstanding.localized(ledger.outstandingDisplay))")
                }
                .onDelete { indexSet in
                    viewModel.deleteLedgers(at: indexSet)
                }
            }
        }
    }
}

struct FriendListView<Model: FriendListViewModelProtocol>: View {
    @ObservedObject var viewModel: Model
    @State private var editingFriend: MemberSummaryViewData?

    var body: some View {
        List {
            ForEach(viewModel.friends) { friend in
                HStack(spacing: 12) {
                    Text(friend.displayAvatar)
                        .font(.largeTitle)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.secondary.opacity(0.1)))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(friend.name)
                            .font(.headline)
                        Text(L.profileCurrencyLabel.localized(friend.currency.rawValue))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        if let index = viewModel.friends.firstIndex(where: { $0.id == friend.id }) {
                            viewModel.deleteFriend(at: IndexSet(integer: index))
                        }
                    } label: {
                        Label(L.delete.localized, systemImage: "trash")
                    }
                    
                    Button {
                        editingFriend = friend
                    } label: {
                        Label(L.edit.localized, systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .sheet(item: $editingFriend) { friend in
            EditFriendSheet(viewModel: viewModel, friend: friend)
        }
    }
}

struct LedgerSummaryRow: View {
    var ledger: LedgerSummaryViewData

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shared.with.you")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(ledger.name)
                    .font(.headline)
                Text("\(L.ledgersMemberCount.localized(ledger.memberCount)) · \(L.ledgersOutstanding.localized(ledger.outstandingDisplay))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(ledger.currency.rawValue)
                .font(.caption)
                .padding(6)
                .background(Capsule().fill(Color.secondary.opacity(0.1)))
        }
        .padding(.vertical, 6)
    }
}

struct LedgerOverviewHost: View {
    @ObservedObject var rootViewModel: AppRootViewModel
    let summary: LedgerSummaryViewData
    @StateObject private var viewModel: LedgerOverviewScreenModel
    @State private var showExpenseForm = false
    @State private var showSettlement = false
    @State private var showRecords = false

    init(rootViewModel: AppRootViewModel, summary: LedgerSummaryViewData) {
        self.rootViewModel = rootViewModel
        self.summary = summary
        _viewModel = StateObject(wrappedValue: rootViewModel.makeLedgerOverviewViewModel(ledgerId: summary.id))
    }

    var body: some View {
        LedgerOverviewView(viewModel: viewModel,
                           onAddExpense: { showExpenseForm = true },
                           onOpenSettlement: { showSettlement = true },
                           onShowRecords: { showRecords = true })
            .navigationTitle(viewModel.ledger.name)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showExpenseForm) {
                ExpenseFormHost(rootViewModel: rootViewModel, ledgerId: summary.id)
            }
            .sheet(isPresented: $showSettlement) {
                SettlementHost(rootViewModel: rootViewModel, ledgerId: summary.id)
            }
            .sheet(isPresented: $showRecords) {
                RecordsSheet(viewModel: viewModel)
            }
            .navigationDestination(for: MemberSummaryViewData.self) { member in
                MemberDetailHost(rootViewModel: rootViewModel, ledgerId: summary.id, member: member)
            }
    }
}

struct LedgerOverviewView<Model: LedgerOverviewViewModelProtocol>: View {
    @ObservedObject var viewModel: Model
    var onAddExpense: () -> Void
    var onOpenSettlement: () -> Void
    var onShowRecords: () -> Void
    
    @State private var showAllMembers = false
    @State private var showAllRecords = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 第一栏：总支出
                totalExpensesCard
                
                // 第二栏：成员支出
                memberExpensesCard
                
                // 第三栏：流水记录
                recentRecordsCard
                
                // 第五栏：转账方案
                settlementCard
            }
            .padding()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: onAddExpense) {
                    Label(L.ledgerAddExpense.localized, systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showAllMembers) {
            AllMembersSheet(memberExpenses: viewModel.memberExpenses)
        }
        .sheet(isPresented: $showAllRecords) {
            RecordsSheet(viewModel: viewModel)
        }
        .onAppear(perform: viewModel.refresh)
    }

    // 第一栏：总支出
    private var totalExpensesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.ledgerCardTotalExpenses.localized)
                .font(.headline)
            
            Text(viewModel.ledger.totalSpentDisplay)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.1)))
    }
    
    // 第二栏：成员支出
    private var memberExpensesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Text(L.ledgerCardMemberExpenses.localized)
                    .font(.headline)
                Spacer()
                Button(action: { showAllMembers = true }) {
                    Text(L.ledgerCardAllButton.localized)
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            
            // 成员支出列表（最多显示4个）
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(viewModel.memberExpenses.prefix(4))) { member in
                    HStack(spacing: 12) {
                        Text(member.displayAvatar)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.secondary.opacity(0.15)))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(L.ledgerCardMemberTotalSpent.localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(member.totalSpentDisplay)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.1)))
    }

    // 第三栏：最近流水
    private var recentRecordsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L.ledgerCardRecentRecords.localized)
                    .font(.headline)
                Spacer()
                Button(action: { showAllRecords = true }) {
                    Text(L.ledgerCardAllButton.localized)
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
            
            if viewModel.records.isEmpty {
                Text(L.ledgerCardNoRecords.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(viewModel.records.prefix(3))) { record in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(record.payerName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(record.amountDisplay)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.blue)
                                Text(record.date, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.1)))
    }
    
    // 第四栏：转账方案
    private var settlementCard: some View {
        Button(action: onOpenSettlement) {
            HStack {
                Label(L.ledgerCardViewTransferPlan.localized, systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.1)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - All Members Sheet

struct AllMembersSheet: View {
    @Environment(\.dismiss) private var dismiss
    let memberExpenses: [MemberExpenseViewData]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(memberExpenses) { member in
                    HStack {
                        Text(member.displayAvatar)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.secondary.opacity(0.15)))
                        
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.name)
                            .font(.headline)
                        Text(L.allMembersTotalSpent.localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                        
                        Spacer()
                        
                        Text(member.totalSpentDisplay)
                            .font(.headline)
                            .foregroundStyle(.blue)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(L.allMembersTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.close.localized) { dismiss() }
                }
            }
        }
    }
}

// MARK: - Records Sheet

struct RecordsSheet<Model: LedgerOverviewViewModelProtocol>: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: Model

    var body: some View {
        NavigationStack {
            List {
                if viewModel.records.isEmpty {
                    ContentUnavailableView(L.recordsEmpty.localized, 
                                         systemImage: "doc.text",
                                         description: Text(L.recordsEmptyDesc.localized))
                } else {
                    ForEach(viewModel.records) { record in
        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.title)
                .font(.headline)
                                    Text(record.payerName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(record.amountDisplay)
                                        .font(.headline)
                                        .foregroundStyle(.blue)
                                    Text(record.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: categoryIcon(for: record.category))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(record.category.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        viewModel.deleteExpense(at: offsets)
                    }
                }
            }
            .navigationTitle(L.recordsTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                    Button(L.close.localized) { dismiss() }
                }
            }
        }
    }
    
    private func categoryIcon(for category: ExpenseCategory) -> String {
        switch category {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .accommodation: return "bed.double.fill"
        case .entertainment: return "theatermasks.fill"
        case .utilities: return "lightbulb.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Friend Management Sheets

struct AddFriendSheet<Model: FriendListViewModelProtocol>: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: Model
    @State private var name = ""
    @State private var selectedCurrency: CurrencyCode = .cny
    @State private var selectedEmoji = "👤"
    @State private var showAllEmojis = false
    
    // 所有 emoji 选项：黄色表情 + 职位 emoji（与 OnboardingView 一致）
    private let emojiOptions = [
        // 基础黄色表情
        "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "😉", "😊",
        "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙", "🥲", "😋", "😛", "😜",
        "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔", "🤐", "🤨", "😐", "😑", "😶",
        "😏", "😒", "🙄", "😬", "🤥", "😌", "😔", "😪", "🤤", "😴", "😷", "🤒",
        "🤕", "🤢", "🤮", "🤧", "🥵", "🥶", "😶‍🌫️", "🥴", "😵", "🤯", "🤠", "🥳",
        "🥸", "😎", "🤓", "🧐", "😕", "😟", "🙁", "😮", "😯", "😲", "😳", "🥺",
        "😦", "😧", "😨", "😰", "😥", "😢", "😭", "😱", "😖", "😣", "😞", "😓",
        "😩", "😫", "🥱", "😤", "😡", "😠", "🤬",
        // 职位和角色 emoji
        "👨‍⚕️", "👩‍⚕️", "👨‍🎓", "👩‍🎓", "👨‍🏫", "👩‍🏫", "👨‍⚖️", "👩‍⚖️", "👨‍🌾", "👩‍🌾",
        "👨‍🍳", "👩‍🍳", "👨‍🔧", "👩‍🔧", "👨‍🏭", "👩‍🏭", "👨‍💼", "👩‍💼", "👨‍🔬", "👩‍🔬",
        "👨‍💻", "👩‍💻", "👨‍🎤", "👩‍🎤", "👨‍🎨", "👩‍🎨", "👨‍✈️", "👩‍✈️", "👨‍🚀", "👩‍🚀",
        "👨‍🚒", "👩‍🚒", "👮‍♂️", "👮‍♀️", "🕵️‍♂️", "🕵️‍♀️", "💂‍♂️", "💂‍♀️", "👷‍♂️", "👷‍♀️",
        "🤴", "👸", "👳‍♂️", "👳‍♀️", "👲", "🧕", "🤵‍♂️", "🤵‍♀️", "👰‍♂️", "👰‍♀️",
        "🤰", "🤱", "👶", "🧒", "👦", "👧", "🧑", "👨", "👩", "🧓", "👴", "👵",
        // 超级英雄和幻想角色
        "🦸‍♂️", "🦸‍♀️", "🦹‍♂️", "🦹‍♀️", "🧙‍♂️", "🧙‍♀️", "🧚‍♂️", "🧚‍♀️", "🧛‍♂️", "🧛‍♀️",
        "🧜‍♂️", "🧜‍♀️", "🧝‍♂️", "🧝‍♀️", "🧞‍♂️", "🧞‍♀️", "🧟‍♂️", "🧟‍♀️",
        // 其他常用
        "👤", "👥", "🫂", "👣"
    ]
    
    // 默认显示的 emoji（前 12 个）
    private var defaultEmojis: [String] {
        Array(emojiOptions.prefix(12))
    }

    var body: some View {
        NavigationStack {
        Form {
                Section(L.friendsInfo.localized) {
                    TextField(L.friendsName.localized, text: $name)
                    Picker(L.friendsCurrency.localized, selection: $selectedCurrency) {
                        ForEach(CurrencyCode.allCases) { currency in
                            Text(currency.rawValue).tag(currency)
                        }
                    }
                }
                
                Section {
                    VStack(spacing: 12) {
                        // 标题和"全部"按钮
                        HStack {
                            Text(L.friendsSelectAvatar.localized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Button {
                                showAllEmojis = true
                            } label: {
                                Text(L.all.localized)
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                        }
                        
                        // Emoji 选择网格（默认显示前 12 个）
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(defaultEmojis, id: \.self) { emoji in
                                Button {
                                    selectedEmoji = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 32))
                                        .frame(width: 50, height: 50)
                                        .background(
                                            Circle()
                                                .fill(selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.1))
                                        )
                                        .overlay(
                                            Circle()
                                                .strokeBorder(selectedEmoji == emoji ? Color.blue : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(L.friendsAddTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel.localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.save.localized) {
                        viewModel.addFriend(named: name, emoji: selectedEmoji, currency: selectedCurrency)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showAllEmojis) {
                AllEmojisSheet(selectedEmoji: $selectedEmoji, emojiOptions: emojiOptions)
            }
        }
    }
}

struct EditFriendSheet<Model: FriendListViewModelProtocol>: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: Model
    let friend: MemberSummaryViewData
    @State private var name: String
    @State private var selectedCurrency: CurrencyCode
    @State private var selectedEmoji: String
    @State private var showAllEmojis = false
    
    // 所有 emoji 选项：黄色表情 + 职位 emoji（与 OnboardingView 一致）
    private let emojiOptions = [
        // 基础黄色表情
        "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "😉", "😊",
        "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙", "🥲", "😋", "😛", "😜",
        "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔", "🤐", "🤨", "😐", "😑", "😶",
        "😏", "😒", "🙄", "😬", "🤥", "😌", "😔", "😪", "🤤", "😴", "😷", "🤒",
        "🤕", "🤢", "🤮", "🤧", "🥵", "🥶", "😶‍🌫️", "🥴", "😵", "🤯", "🤠", "🥳",
        "🥸", "😎", "🤓", "🧐", "😕", "😟", "🙁", "😮", "😯", "😲", "😳", "🥺",
        "😦", "😧", "😨", "😰", "😥", "😢", "😭", "😱", "😖", "😣", "😞", "😓",
        "😩", "😫", "🥱", "😤", "😡", "😠", "🤬",
        // 职位和角色 emoji
        "👨‍⚕️", "👩‍⚕️", "👨‍🎓", "👩‍🎓", "👨‍🏫", "👩‍🏫", "👨‍⚖️", "👩‍⚖️", "👨‍🌾", "👩‍🌾",
        "👨‍🍳", "👩‍🍳", "👨‍🔧", "👩‍🔧", "👨‍🏭", "👩‍🏭", "👨‍💼", "👩‍💼", "👨‍🔬", "👩‍🔬",
        "👨‍💻", "👩‍💻", "👨‍🎤", "👩‍🎤", "👨‍🎨", "👩‍🎨", "👨‍✈️", "👩‍✈️", "👨‍🚀", "👩‍🚀",
        "👨‍🚒", "👩‍🚒", "👮‍♂️", "👮‍♀️", "🕵️‍♂️", "🕵️‍♀️", "💂‍♂️", "💂‍♀️", "👷‍♂️", "👷‍♀️",
        "🤴", "👸", "👳‍♂️", "👳‍♀️", "👲", "🧕", "🤵‍♂️", "🤵‍♀️", "👰‍♂️", "👰‍♀️",
        "🤰", "🤱", "👶", "🧒", "👦", "👧", "🧑", "👨", "👩", "🧓", "👴", "👵",
        // 超级英雄和幻想角色
        "🦸‍♂️", "🦸‍♀️", "🦹‍♂️", "🦹‍♀️", "🧙‍♂️", "🧙‍♀️", "🧚‍♂️", "🧚‍♀️", "🧛‍♂️", "🧛‍♀️",
        "🧜‍♂️", "🧜‍♀️", "🧝‍♂️", "🧝‍♀️", "🧞‍♂️", "🧞‍♀️", "🧟‍♂️", "🧟‍♀️",
        // 其他常用
        "👤", "👥", "🫂", "👣"
    ]
    
    // 默认显示的 emoji（前 12 个）
    private var defaultEmojis: [String] {
        Array(emojiOptions.prefix(12))
    }

    init(viewModel: Model, friend: MemberSummaryViewData) {
        self.viewModel = viewModel
        self.friend = friend
        _name = State(initialValue: friend.name)
        _selectedCurrency = State(initialValue: friend.currency)
        _selectedEmoji = State(initialValue: friend.avatarEmoji ?? "👤")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L.friendsInfo.localized) {
                    TextField(L.friendsName.localized, text: $name)
                    Picker(L.friendsCurrency.localized, selection: $selectedCurrency) {
                        ForEach(CurrencyCode.allCases) { currency in
                            Text(currency.rawValue).tag(currency)
                        }
                    }
                }
                
                Section {
                    VStack(spacing: 12) {
                        // 标题和"全部"按钮
                        HStack {
                            Text(L.friendsSelectAvatar.localized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Button {
                                showAllEmojis = true
                            } label: {
                                Text(L.all.localized)
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                        }
                        
                        // Emoji 选择网格（默认显示前 12 个）
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(defaultEmojis, id: \.self) { emoji in
                                Button {
                                    selectedEmoji = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 32))
                                        .frame(width: 50, height: 50)
                                        .background(
                                            Circle()
                                                .fill(selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.1))
                                        )
                                        .overlay(
                                            Circle()
                                                .strokeBorder(selectedEmoji == emoji ? Color.blue : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(L.friendsEditTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel.localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.save.localized) {
                        viewModel.updateFriend(id: friend.id, name: name, currency: selectedCurrency, emoji: selectedEmoji)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showAllEmojis) {
                AllEmojisSheet(selectedEmoji: $selectedEmoji, emojiOptions: emojiOptions)
            }
        }
    }
}

struct CreateLedgerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: LedgerListScreenModel
    @State private var ledgerName = ""
    @State private var selectedCurrency: CurrencyCode = .cny
    @State private var selectedMemberIds: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Form {
                Section(L.createLedgerInfo.localized) {
                    TextField(L.createLedgerName.localized, text: $ledgerName)
                    Picker(L.createLedgerCurrency.localized, selection: $selectedCurrency) {
                        ForEach(CurrencyCode.allCases) { currency in
                            Text(currency.rawValue).tag(currency)
                        }
                    }
                }
                
                Section {
                    HStack {
                        Text(viewModel.currentUser.displayAvatar)
                            .font(.title2)
                        Text(L.createLedgerMe.localized)
                            .font(.headline)
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                } header: {
                    Text(L.createLedgerMembers.localized)
                } footer: {
                    Text(L.createLedgerSelectedCount.localized(selectedMemberIds.count + 1))
                }
                
                Section(L.createLedgerSelectFriends.localized) {
                    ForEach(viewModel.availableMembers) { member in
                        Button {
                            if selectedMemberIds.contains(member.id) {
                                selectedMemberIds.remove(member.id)
                            } else {
                                selectedMemberIds.insert(member.id)
                            }
                        } label: {
                    HStack {
                                Text(member.displayAvatar)
                                    .font(.title2)
                                Text(member.name)
                                    .foregroundStyle(.primary)
                        Spacer()
                                if selectedMemberIds.contains(member.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                    }
                }
            }
        }
    }
}
            .navigationTitle(L.createLedgerTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel.localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.createLedgerCreate.localized) {
                        var memberIds = Array(selectedMemberIds)
                        memberIds.append(viewModel.currentUser.id)
                        viewModel.createLedger(name: ledgerName, memberIds: memberIds, currency: selectedCurrency)
                        dismiss()
                    }
                    .disabled(ledgerName.isEmpty || selectedMemberIds.count < 1)
                }
            }
        }
    }
}

// MARK: - 个人信息编辑视图

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    let currentUser: UserProfile
    let onSave: (String, String, CurrencyCode) -> Void
    
    @State private var name: String
    @State private var selectedEmoji: String
    @State private var selectedCurrency: CurrencyCode
    @State private var showAllEmojis = false
    
    // 所有 emoji 选项：黄色表情 + 职位 emoji（与 OnboardingView 一致）
    private let emojiOptions = [
        // 基础黄色表情
        "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "😉", "😊",
        "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙", "🥲", "😋", "😛", "😜",
        "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔", "🤐", "🤨", "😐", "😑", "😶",
        "😏", "😒", "🙄", "😬", "🤥", "😌", "😔", "😪", "🤤", "😴", "😷", "🤒",
        "🤕", "🤢", "🤮", "🤧", "🥵", "🥶", "😶‍🌫️", "🥴", "😵", "🤯", "🤠", "🥳",
        "🥸", "😎", "🤓", "🧐", "😕", "😟", "🙁", "😮", "😯", "😲", "😳", "🥺",
        "😦", "😧", "😨", "😰", "😥", "😢", "😭", "😱", "😖", "😣", "😞", "😓",
        "😩", "😫", "🥱", "😤", "😡", "😠", "🤬",
        // 职位和角色 emoji
        "👨‍⚕️", "👩‍⚕️", "👨‍🎓", "👩‍🎓", "👨‍🏫", "👩‍🏫", "👨‍⚖️", "👩‍⚖️", "👨‍🌾", "👩‍🌾",
        "👨‍🍳", "👩‍🍳", "👨‍🔧", "👩‍🔧", "👨‍🏭", "👩‍🏭", "👨‍💼", "👩‍💼", "👨‍🔬", "👩‍🔬",
        "👨‍💻", "👩‍💻", "👨‍🎤", "👩‍🎤", "👨‍🎨", "👩‍🎨", "👨‍✈️", "👩‍✈️", "👨‍🚀", "👩‍🚀",
        "👨‍🚒", "👩‍🚒", "👮‍♂️", "👮‍♀️", "🕵️‍♂️", "🕵️‍♀️", "💂‍♂️", "💂‍♀️", "👷‍♂️", "👷‍♀️",
        "🤴", "👸", "👳‍♂️", "👳‍♀️", "👲", "🧕", "🤵‍♂️", "🤵‍♀️", "👰‍♂️", "👰‍♀️",
        "🤰", "🤱", "👶", "🧒", "👦", "👧", "🧑", "👨", "👩", "🧓", "👴", "👵",
        // 超级英雄和幻想角色
        "🦸‍♂️", "🦸‍♀️", "🦹‍♂️", "🦹‍♀️", "🧙‍♂️", "🧙‍♀️", "🧚‍♂️", "🧚‍♀️", "🧛‍♂️", "🧛‍♀️",
        "🧜‍♂️", "🧜‍♀️", "🧝‍♂️", "🧝‍♀️", "🧞‍♂️", "🧞‍♀️", "🧟‍♂️", "🧟‍♀️",
        // 其他常用
        "👤", "👥", "🫂", "👣"
    ]
    
    // 默认显示的 emoji（前 12 个）
    private var defaultEmojis: [String] {
        Array(emojiOptions.prefix(12))
    }
    
    init(currentUser: UserProfile, onSave: @escaping (String, String, CurrencyCode) -> Void) {
        self.currentUser = currentUser
        self.onSave = onSave
        _name = State(initialValue: currentUser.name)
        _selectedEmoji = State(initialValue: currentUser.avatarEmoji ?? "👤")
        _selectedCurrency = State(initialValue: currentUser.currency)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L.profileNamePlaceholder.localized, text: $name)
                        .font(.body)
                } header: {
                    Text(L.profileName.localized)
                } footer: {
                    Text(L.profileNameFooter.localized)
                        .font(.caption)
                }
                
                Section {
                    Picker(L.profileCurrencyPicker.localized, selection: $selectedCurrency) {
                        ForEach(CurrencyCode.allCases) { currency in
                            Text(currency.rawValue).tag(currency)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text(L.profileCurrency.localized)
                }
                
                Section {
                    VStack(spacing: 16) {
                        // 当前选中的头像预览
                        HStack {
                            Text(L.profileCurrentAvatar.localized)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(selectedEmoji)
                                .font(.system(size: 50))
                                .frame(width: 70, height: 70)
                                .background(
                                    Circle()
                                        .fill(Color.blue.opacity(0.1))
                                )
                        }
                        .padding(.vertical, 8)
                        
                        Divider()
                        
                        // 标题和"全部"按钮
                        HStack {
                            Text(L.onboardingAvatarSection.localized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Button {
                                showAllEmojis = true
                            } label: {
                                Text(L.all.localized)
                                    .font(.subheadline)
                                    .foregroundStyle(.blue)
                            }
                        }
                        
                        // Emoji 选择网格（默认显示前 12 个）
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(defaultEmojis, id: \.self) { emoji in
                                Button {
                                    selectedEmoji = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 32))
                                        .frame(width: 50, height: 50)
                                        .background(
                                            Circle()
                                                .fill(selectedEmoji == emoji ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.1))
                                        )
                                        .overlay(
                                            Circle()
                                                .strokeBorder(selectedEmoji == emoji ? Color.blue : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text(L.profileAvatar.localized)
                } footer: {
                    Text(L.profileAvatarFooter.localized)
                        .font(.caption)
                }
            }
            .navigationTitle(L.profileEdit.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel.localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.save.localized) {
                        onSave(name, selectedEmoji, selectedCurrency)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showAllEmojis) {
                AllEmojisSheet(selectedEmoji: $selectedEmoji, emojiOptions: emojiOptions)
            }
        }
    }
}

// MARK: - 键盘相关扩展

struct DismissKeyboardOnTapModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                TapGesture().onEnded { _ in
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            )
    }
}

extension View {
    /// 添加点击空白处隐藏键盘的功能
    func dismissKeyboardOnTap() -> some View {
        self.modifier(DismissKeyboardOnTapModifier())
    }
}

#Preview {
    ContentView(viewModel: AppRootViewModel())
        .environment(\.locale, Locale(identifier: "zh_CN"))
}


