//
//  ContentView.swift
//  KuaiJi
//
//  Shared ledger UI skeleton with view model protocols and SwiftUI structure.
//

import SwiftUI
import UIKit
import Combine
import UniformTypeIdentifiers
import SwiftData
import Darwin
import StoreKit

extension Notification.Name {
    static let openPersonalTemplates = Notification.Name("kuaji.openPersonalTemplates")
}

// MARK: - View Data Models

struct LedgerSummaryViewData: Identifiable, Hashable {
    var id: UUID
    var name: String
    var memberCount: Int
    var currency: CurrencyCode
    var outstandingDisplay: String
    var updatedAt: Date
    var isArchived: Bool
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
    var splitModeDisplay: String
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

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

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
        Self.dateFormatter.string(from: date)
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

extension SplitStrategy {
    func displayLabel(beneficiaryName: String? = nil) -> String {
        switch self {
        case .payerAA, .actorAA:
            return L.splitModeAA.localized
        case .payerTreat, .actorTreat:
            return L.splitModeTreat.localized
        case .weighted:
            return L.splitModeWeighted.localized
        case .custom:
            return L.splitModeCustom.localized
        case .fixedPlusEqual:
            return L.splitModeFixedPlusEqual.localized
        case .helpPay:
            if let name = beneficiaryName, !name.isEmpty {
                return L.splitModeHelpPayWithName.localized(name)
            }
            return L.splitModeHelpPay.localized
        }
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
// 这些协议仅用于驱动 SwiftUI 界面，按设计限定在主线程执行，避免并发隔离告警。
@MainActor
protocol LedgerListViewModelProtocol: ObservableObject {
    var ledgers: [LedgerSummaryViewData] { get }
    var archivedLedgers: [LedgerSummaryViewData] { get }
    var availableMembers: [MemberSummaryViewData] { get }
    var currentUser: MemberSummaryViewData { get }
    func createLedger(name: String, memberIds: [UUID], currency: CurrencyCode)
    func deleteLedgers(at offsets: IndexSet)
    func deleteLedger(id: UUID)
    func archiveLedger(id: UUID)
    func unarchiveLedger(id: UUID)
}

@MainActor
protocol LedgerOverviewViewModelProtocol: ObservableObject {
    var ledger: LedgerDetailViewData { get }
    var filters: LedgerFilterState { get set }
    var balances: [NetBalanceViewData] { get }
    var members: [MemberSummaryViewData] { get }
    var memberExpenses: [MemberExpenseViewData] { get }
    var records: [LedgerRecordViewData] { get }
    var transferPlan: [TransferRecordViewData] { get }
    func refresh()
    func member(for userId: UUID) -> MemberSummaryViewData?
    func deleteExpense(at offsets: IndexSet)
    func clearAllBalances()
}

@MainActor
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

@MainActor
protocol SettlementViewModelProtocol: ObservableObject {
    var netBalances: [NetBalanceViewData] { get }
    var transferPlan: [TransferRecordViewData] { get }
    func generatePlan()
    func clearAllBalances()
}

@MainActor
protocol MemberDetailViewModelProtocol: ObservableObject {
    var member: MemberSummaryViewData { get }
    var breakdown: [CategoryBreakdown] { get }
    var timeline: [TimeSeriesPoint] { get }
}

@MainActor
protocol FriendListViewModelProtocol: ObservableObject {
    var friends: [MemberSummaryViewData] { get }
    func addFriend(named name: String, emoji: String?, currency: CurrencyCode)
    func addFriendFromQRCode(userId: String, named name: String, emoji: String?, currency: CurrencyCode) -> Bool
    func deleteFriend(at offsets: IndexSet)
    func updateFriend(id: UUID, name: String, currency: CurrencyCode, emoji: String?)
}

@MainActor
protocol RecordsViewModelProtocol: ObservableObject {
    var records: [LedgerRecordViewData] { get }
    func refresh()
}

@MainActor
protocol SettingsViewModelProtocol: ObservableObject {
    var uiState: SettingsViewState { get set }
    func persist()
    func clearAllData()
    func eraseAbsolutelyAll()
    func getCurrentUser() -> UserProfile?
    func updateUserProfile(name: String, emoji: String, currency: CurrencyCode)
    func exportFullData(personalStore: PersonalLedgerStore, visibility: FeatureVisibilitySnapshot) -> URL?
    func importFullData(from url: URL, personalStore: PersonalLedgerStore) throws -> FeatureVisibilitySnapshot?
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

struct ExpenseFormView<Model: ExpenseFormViewModelProtocol>: View {
    @ObservedObject var viewModel: Model
    @State private var showingOtherPayerSheet = false
    @State private var showingHelpPayPayerSheet = false
    @State private var showingBeneficiarySheet = false
    @State private var showingCategorySheet = false
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
                                        .foregroundStyle(viewModel.splitOption == option ? Color.appSelection : Color.secondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.title)
                                            .font(.headline)
                                            .foregroundStyle(Color.appTextPrimary)
                                        
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
                                .foregroundStyle(Color.appTextPrimary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.appSecondaryText)
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
                                    .foregroundStyle(Color.appTextPrimary)
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
                // 用途
                TextField(L.expensePurpose.localized, text: binding(
                    get: { viewModel.draft.title },
                    set: { viewModel.draft.title = $0 }
                ))
                .submitLabel(.done)
                
                // 将日期与分类顺序对调：先分类，后日期
                HStack {
                    Text(L.expenseCategory.localized)
                    Spacer()
                    Text(viewModel.draft.category.displayName)
                        .foregroundStyle(Color.appTextPrimary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { showingCategorySheet = true }
                .confirmationDialog(L.expenseCategory.localized, isPresented: $showingCategorySheet, titleVisibility: .visible) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        Button(category.displayName) {
                            viewModel.draft.category = category
                            viewModel.regeneratePreview()
                        }
                    }
                    Button(L.cancel.localized, role: .cancel) { }
                }

                DatePicker(L.expenseDate.localized, selection: binding(
                    get: { viewModel.draft.date },
                    set: { viewModel.draft.date = $0 }
                ), displayedComponents: [.date, .hourAndMinute])
            } header: {
                Text(L.expenseBasicInfo.localized)
            } footer: {
                Text(L.expenseOptionalFields.localized)
                    .font(.caption2)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .tint(Color.appTextPrimary)
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
        .background(Color.appBackground)
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
                            .foregroundStyle(balance.isPositive ? Color.appSuccess : Color.appDanger)
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
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.appSuccess.opacity(0.1)))
                        .foregroundStyle(Color.appSuccess)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
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
    @ObservedObject var personalSettingsViewModel: PersonalLedgerSettingsViewModel
    @ObservedObject var personalLedgerRoot: PersonalLedgerRootViewModel
    @EnvironmentObject var appState: AppState
    @AppStorage("theme") private var theme = "default"
    @State private var showingContactSheet = false
    @State private var showingClearDataAlert = false
    @State private var showingProfileEdit = false
    @State private var showingGuide = false
    @State private var navigateToUsageGuide = false
    @State private var navigateToPersonalAccounts = false
    @State private var navigateToPersonalCSVExport = false
    @State private var navigateToTemplates = false
    @State private var navigateToPersonalCategories = false
    @State private var showingImportPicker = false
    @State private var showingImportConfirmation = false
    @State private var pendingImportURL: URL?
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingPersonalExportError = false
    @State private var showingPersonalClearAlert = false
    @State private var showingEraseAbsolutelyAllAlert = false
    @State private var quickActionSelection: QuickActionSelection = .none
    @State private var showingSharedCSVPicker = false
    @State private var showingSupport = false

    private enum QuickActionSelection: Hashable, Identifiable {
        case none
        case shared(UUID)
        case personal

        var id: String {
            switch self {
            case .none: return "none"
            case .personal: return "personal"
            case .shared(let id): return id.uuidString
            }
        }
    }

    private func selection(from target: QuickActionTarget?) -> QuickActionSelection {
        switch target {
        case .shared(let id): return .shared(id)
        case .personal: return .personal
        case .none: return .none
        }
    }

    private enum SharedCSVExportError: LocalizedError {
        case ledgerMissing

        var errorDescription: String? {
            switch self {
            case .ledgerMissing:
                return L.settingsExportSharedCSVNotFound.localized
            }
        }
    }

    private enum SettingsScrollTarget: Hashable {
        case dataManagement
    }
    var body: some View {
        ScrollViewReader { proxy in
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
                                    .foregroundStyle(Color.appTextPrimary)
                                Text(L.profileUserIdLabel.localized(currentUser.userId))
                                    .appSecondaryTextStyle()
                                Text(L.profileCurrencyLabel.localized(currentUser.currency.rawValue))
                                    .appSecondaryTextStyle()
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.appSecondaryText)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text(L.profileTitle.localized)
            } footer: {
                Text(L.profileViewInfo.localized)
                    .appSecondaryTextStyle()
            }
            
            Section(L.settingsInterfaceDisplay.localized) {
                Button {
                    openSystemSettings()
                } label: {
                    HStack {
                        Text(L.settingsLanguage.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }

                Picker(selection: $theme) {
                    Text(L.themeDefault.localized).tag("default")
                    Text(L.themeForest.localized).tag("forest")
                    Text(L.themePeach.localized).tag("peach")
                    Text(L.themeLavender.localized).tag("lavender")
                    Text(L.themeAlps.localized).tag("alps")
                    Text(L.themeMorandi.localized).tag("morandi")
                    Text(L.themeChristmas.localized).tag("christmas")
                } label: {
                    Text(L.settingsColorScheme.localized)
                        .foregroundStyle(Color.appLedgerContentText)
                }
                .tint(Color.appToggleOn)
                Toggle(L.settingsShowSharedAndFriends.localized, isOn: $appState.showSharedLedgerTab)
                    .tint(Color.appToggleOn)
                    .foregroundStyle(Color.appLedgerContentText)
                
                Toggle(L.settingsShowPersonalLedger.localized, isOn: $appState.showPersonalLedgerTab)
                    .tint(Color.appToggleOn)
                    .foregroundStyle(Color.appLedgerContentText)
                
                HStack {
                    Text(L.settingsSharedLanding.localized)
                        .foregroundStyle(Color.appLedgerContentText)
                    Spacer()
                    Picker(selection: Binding(get: {
                        switch appState.getSharedLandingPreference() {
                        case .list: return "list"
                        case .ledger(let id): return id.uuidString
                        }
                    }, set: { (raw: String) in
                        if raw == "list" {
                            appState.setSharedLandingPreference(.list)
                        } else if let id = UUID(uuidString: raw) {
                            appState.setSharedLandingPreference(.ledger(id))
                        }
                    })) {
                        Text(L.settingsSharedLandingList.localized).tag("list")
                        ForEach(rootViewModel.ledgerSummaries, id: \.id) { ledger in
                            Text(ledger.name).tag(ledger.id.uuidString)
                        }
                    } label: { EmptyView() }
                    .pickerStyle(.menu)
                    .tint(Color.appToggleOn)
                    .accessibilityIdentifier("settings.sharedLandingPicker")
                }
            }
            
            // 快速记账默认账本设置
            Section {
                Picker(selection: $quickActionSelection) {
                    Text(L.settingsDefaultLedgerNone.localized)
                        .tag(QuickActionSelection.none)
                    Text(L.settingsQuickActionPersonal.localized)
                        .tag(QuickActionSelection.personal)
                    ForEach(rootViewModel.ledgerSummaries, id: \.id) { ledger in
                        Text(ledger.name)
                            .tag(QuickActionSelection.shared(ledger.id))
                    }
                } label: {
                    Text(L.settingsDefaultLedger.localized)
                        .foregroundStyle(Color.appLedgerContentText)
                }
                .onChangeCompat(of: quickActionSelection) {
                    switch quickActionSelection {
                    case .none:
                        appState.setQuickActionTarget(nil)
                    case .personal:
                        appState.setQuickActionTarget(.personal)
                    case .shared(let id):
                        appState.setQuickActionTarget(.shared(id))
                    }
                }
                .tint(Color.appToggleOn)
            } header: {
                Text(L.settingsQuickActionSection.localized)
            } footer: {
                Text(L.settingsDefaultLedgerDesc.localized)
                    .appSecondaryTextStyle()
            }
            
            // 个人账本设置
            Section {
                Toggle(L.personalFeeInclude.localized, isOn: $personalSettingsViewModel.countFeeInStats)
                    .tint(Color.appToggleOn)
                    .foregroundStyle(Color.appLedgerContentText)
                    .onChangeCompat(of: personalSettingsViewModel.countFeeInStats) {
                        Task { await personalSettingsViewModel.save() }
                    }
                Button {
                    navigateToPersonalAccounts = true
                } label: {
                    HStack {
                        Text(L.personalAccountsManage.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }
                Button {
                    navigateToTemplates = true
                } label: {
                    HStack {
                        Text(L.personalTemplatesTitle.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }
                Button {
                    navigateToPersonalCategories = true
                } label: {
                    HStack {
                        Text(L.personalCategoriesManage.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }
            } header: {
                Text(L.personalSettingsTitle.localized)
            }

            Section(L.settingsAbout.localized) {
                Button {
                    showingGuide = true
                } label: {
                    HStack {
                        Text(L.settingsGuide.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }
                Button {
                    navigateToUsageGuide = true
                } label: {
                    HStack {
                        Text(L.settingsUsageGuide.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }

                Button {
                    showingSupport = true
                } label: {
                    HStack {
                        Text(L.settingsSupportMe.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(Color.appToggleOn)
                    }
                }

                Button {
                    AppReviewManager.requestInAppReview()
                } label: {
                    HStack {
                        Text(L.settingsRateApp.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(Color.appToggleOn)
                    }
                }

                Button {
                    showingContactSheet = true
                } label: {
                    HStack {
                        Text(L.settingsContactMe.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }

                Button {
                    openPrivacySupport()
                } label: {
                    HStack {
                        Text(L.contactSupport.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }

                // 版本信息
                HStack {
                    Text(L.settingsVersion.localized)
                        .foregroundStyle(Color.appLedgerContentText)
                    Spacer()
                    Text(versionString())
                        .foregroundStyle(Color.appLedgerContentText)
                }
            }

            // 数据管理
            Section {
                Button {
                    exportData()
                } label: {
                    HStack {
                        Text(L.settingsExportData.localized)
                            .foregroundStyle(Color.appTextPrimary)
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }

                Button {
                    showingImportPicker = true
                } label: {
                    HStack {
                        Text(L.settingsImportData.localized)
                            .foregroundStyle(Color.appTextPrimary)
                        Spacer()
                        Image(systemName: "square.and.arrow.down")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }

                Button {
                    if rootViewModel.ledgerSummaries.isEmpty {
                        alertTitle = L.settingsExportSharedCSVEmptyTitle.localized
                        alertMessage = L.settingsExportSharedCSVEmptyMessage.localized
                        showingAlert = true
                    } else {
                        showingSharedCSVPicker = true
                    }
                } label: {
                    HStack {
                        Text(L.settingsExportSharedCSV.localized)
                            .foregroundStyle(Color.appTextPrimary)
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }

                Button {
                    navigateToPersonalCSVExport = true
                } label: {
                    HStack {
                        Text(L.personalExportCSV.localized)
                            .foregroundStyle(Color.appTextPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }
            } header: {
                Text(L.settingsDataSection.localized)
            } footer: {
                Text(L.settingsExportDataDesc.localized)
                    .appSecondaryTextStyle()
            }
            .id(SettingsScrollTarget.dataManagement)
            .confirmationDialog(L.settingsExportSharedCSV.localized, isPresented: $showingSharedCSVPicker, titleVisibility: .visible) {
                ForEach(rootViewModel.ledgerSummaries, id: \.id) { ledger in
                    Button(ledger.name) {
                        exportSharedLedgerCSV(for: ledger)
                    }
                }
                Button(L.cancel.localized, role: .cancel) { }
            }

            Section {
                Button(role: .destructive) {
                    showingClearDataAlert = true
                } label: {
                    Text(L.settingsClearData.localized)
                        .frame(maxWidth: .infinity)
                }
            } footer: {
                Text(L.settingsClearDataWarning.localized)
                    .appSecondaryTextStyle()
            }

            Section {
                Button(role: .destructive) {
                    showingPersonalClearAlert = true
                } label: {
                    Text(L.personalClearData.localized)
                        .frame(maxWidth: .infinity)
                }
            } footer: {
                Text(L.personalClearHint.localized)
                    .appSecondaryTextStyle()
            }

            // 彻底抹除所有数据（共享+个人+设置）
            Section {
                Button(role: .destructive) {
                    showingEraseAbsolutelyAllAlert = true
                } label: {
                    Text(L.eraseAllData.localized)
                        .frame(maxWidth: .infinity)
                }
            } footer: {
                Text(L.eraseAllDataWarning.localized)
                    .appSecondaryTextStyle()
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationDestination(isPresented: $navigateToUsageGuide) {
            UsageGuideView()
        }
        .navigationDestination(isPresented: $navigateToPersonalAccounts) {
            PersonalAccountsView(root: personalLedgerRoot, viewModel: personalLedgerRoot.makeAccountsViewModel())
        }
        .navigationDestination(isPresented: $navigateToPersonalCSVExport) {
            PersonalCSVExportView(root: personalLedgerRoot, viewModel: personalLedgerRoot.makeCSVExportViewModel())
        }
        .navigationDestination(isPresented: $navigateToTemplates) {
            PersonalRecordTemplatesView(root: personalLedgerRoot, viewModel: personalLedgerRoot.makeTemplatesViewModel())
        }
        .navigationDestination(isPresented: $navigateToPersonalCategories) {
            PersonalCategorySettingsView(viewModel: personalLedgerRoot.makeCategorySettingsViewModel())
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .navigationTitle(L.settingsTitle.localized)
        .onChangeCompat(of: appState.settingsDeepLink) {
            handleSettingsDeepLink(using: proxy)
        }
        .onAppear {
            // 初始化快速操作目标
            quickActionSelection = selection(from: appState.getQuickActionTarget())
            handleSettingsDeepLink(using: proxy)
        }
        .sheet(isPresented: $showingContactSheet) {
            ContactView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSupport) {
            SupportMeView()
                .presentationDetents([.fraction(0.67), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingProfileEdit) {
            if let currentUser = viewModel.getCurrentUser() {
                ProfileEditView(currentUser: currentUser) { name, emoji, currency in
                    viewModel.updateUserProfile(name: name, emoji: emoji, currency: currency)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .sheet(isPresented: $showingGuide) {
            WelcomeGuideView {
                showingGuide = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPersonalTemplates)) { _ in
            navigateToTemplates = true
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
        .alert(L.eraseAllConfirmTitle.localized, isPresented: $showingEraseAbsolutelyAllAlert) {
            Button(L.cancel.localized, role: .cancel) { }
            Button(L.delete.localized, role: .destructive) {
                viewModel.eraseAbsolutelyAll()
            }
        } message: {
            Text(L.eraseAllConfirmMessage.localized)
        }
        .alert(L.settingsImportConfirmTitle.localized, isPresented: $showingImportConfirmation) {
            Button(L.cancel.localized, role: .cancel) {
                pendingImportURL = nil
            }
            Button(L.settingsImportConfirmButton.localized, role: .destructive) {
                performImport()
            }
        } message: {
            Text(L.settingsImportConfirmMessage.localized)
        }
        .alert(L.personalExportFailed.localized, isPresented: $showingPersonalExportError) {
            Button(L.ok.localized, action: {})
        }
        .alert(L.personalClearConfirmTitle.localized, isPresented: $showingPersonalClearAlert) {
            Button(L.cancel.localized, role: .cancel) { }
            Button(L.personalClearData.localized, role: .destructive) {
                clearPersonalData()
            }
        } message: {
            Text(L.personalClearConfirmMessage.localized)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button(L.ok.localized, role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .fileImporter(isPresented: $showingImportPicker, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                pendingImportURL = url
                showingImportConfirmation = true
            case .failure(let error):
                alertTitle = L.settingsImportError.localized
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
        }
    }
    
    private func handleSettingsDeepLink(using proxy: ScrollViewProxy) {
        guard let deepLink = appState.settingsDeepLink else { return }
        switch deepLink {
        case .dataManagement:
            withAnimation(.easeInOut) {
                proxy.scrollTo(SettingsScrollTarget.dataManagement, anchor: .top)
            }
        }
        appState.settingsDeepLink = nil
    }
    
    private func exportSharedLedgerCSV(for ledger: LedgerSummaryViewData) {
        do {
            let url = try makeSharedLedgerCSV(for: ledger)
            presentShare(url: url)
        } catch {
            alertTitle = L.settingsExportError.localized
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }

    private func makeSharedLedgerCSV(for ledger: LedgerSummaryViewData) throws -> URL {
        guard let info = rootViewModel.ledgerInfos[ledger.id] else {
            throw SharedCSVExportError.ledgerMissing
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        var lines: [String] = ["日期,标题,金额,币种,类别,付款人,参与者,备注"]
        let sortedExpenses = info.expenses.sorted { $0.date > $1.date }
        for expense in sortedExpenses {
            let totalMinor = expense.amountMinorUnits + expense.metadata.tipMinorUnits + expense.metadata.taxMinorUnits
            let amount = SettlementMath.decimal(fromMinorUnits: totalMinor, scale: 2)
            let payerName = rootViewModel.member(with: expense.payerId)?.name ?? L.defaultUnknownMember.localized
            let categoryName = expense.category.displayName
            let dateString = formatter.string(from: expense.date)
            let participants = expense.participants.map { share -> String in
                let name = rootViewModel.member(with: share.userId)?.name ?? L.defaultUnknownMember.localized
                return name
                    .replacingOccurrences(of: ",", with: " ")
                    .replacingOccurrences(of: "\n", with: " ")
            }.joined(separator: ";")
            let sanitizedTitle = (expense.title.isEmpty ? L.defaultUntitledExpense.localized : expense.title)
                .replacingOccurrences(of: ",", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
            let sanitizedCategory = categoryName
                .replacingOccurrences(of: ",", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
            let sanitizedPayer = payerName
                .replacingOccurrences(of: ",", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
            let sanitizedNote = expense.note
                .replacingOccurrences(of: ",", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
            lines.append("\(dateString),\(sanitizedTitle),\(amount),\(info.currency.rawValue),\(sanitizedCategory),\(sanitizedPayer),\(participants),\(sanitizedNote)")
        }

        let csv = lines.joined(separator: "\n") + "\n"
        let safeName = ledger.name.isEmpty ? "Ledger" : ledger.name.replacingOccurrences(of: " ", with: "_")
        let filename = "SharedLedger-\(safeName)-\(UUID().uuidString).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func exportPersonalCSV() throws -> URL {
        let records = try personalLedgerRoot.store.records(filter: PersonalRecordFilter())
        var lines: [String] = ["日期,账户,类型,分类,金额,币种,备注"]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        for record in records {
            let dateString = formatter.string(from: record.occurredAt)
            let typeString: String
            switch record.kind {
            case .income: typeString = "Income"
            case .expense: typeString = "Expense"
            case .fee: typeString = "Fee"
            }
            let account = personalLedgerRoot.store.account(with: record.accountId)
            let accountName = account?.name ?? ""
            let note = record.note.replacingOccurrences(of: ",", with: " ")
            let amount = SettlementMath.decimal(fromMinorUnits: record.amountMinorUnits, scale: 2)
            let currencyCode = account?.currency.rawValue ?? personalLedgerRoot.store.safePrimaryDisplayCurrency().rawValue
            lines.append("\(dateString),\(accountName),\(typeString),\(record.categoryKey),\(amount),\(currencyCode),\(note)")
        }
        let csv = lines.joined(separator: "\n") + "\n"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PersonalLedger-\(UUID().uuidString).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func presentShare(url: URL) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else { return }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = rootVC.view
        rootVC.present(controller, animated: true)
    }

    private func clearPersonalData() {
        do {
            try personalLedgerRoot.store.clearAllPersonalData()
            alertTitle = L.personalClearSuccess.localized
            alertMessage = L.personalClearSuccessMessage.localized
            showingAlert = true
        } catch {
            alertTitle = L.personalClearFailed.localized
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }

    private func exportData() {
        let visibility = FeatureVisibilitySnapshot(showSharedAndFriends: appState.showSharedLedgerTab,
                                                   showPersonal: appState.showPersonalLedgerTab,
                                                   quickAction: appState.getQuickActionTarget())
        if let exportURL = viewModel.exportFullData(personalStore: personalLedgerRoot.store, visibility: visibility) {
            // 使用 UIActivityViewController 分享文件
            let activityVC = UIActivityViewController(activityItems: [exportURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                activityVC.popoverPresentationController?.sourceView = rootVC.view
                rootVC.present(activityVC, animated: true)
            }
        } else {
            alertTitle = L.settingsExportError.localized
            alertMessage = L.settingsExportErrorMessage.localized
            showingAlert = true
        }
    }
    
    private func performImport() {
        guard let url = pendingImportURL else { return }
        
        do {
            // 需要访问安全作用域资源
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            let visibility = try viewModel.importFullData(from: url, personalStore: personalLedgerRoot.store)
            if let visibility {
                appState.showSharedLedgerTab = visibility.showSharedAndFriends
                appState.showPersonalLedgerTab = visibility.showPersonal
                appState.setQuickActionTarget(visibility.quickActionTarget())
                quickActionSelection = selection(from: appState.getQuickActionTarget())
            }
            personalSettingsViewModel.reloadFromStore()
            alertTitle = L.settingsImportSuccess.localized
            alertMessage = L.settingsImportSuccessMessage.localized
            showingAlert = true
            pendingImportURL = nil
        } catch {
            alertTitle = L.settingsImportError.localized
            alertMessage = error.localizedDescription
            showingAlert = true
            pendingImportURL = nil
        }
    }
    
    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func openPrivacySupport() {
        if let url = URL(string: "https://guoran7771.github.io/KuaiJiPrivacy-Support/kuaji_privacy_support_trilingual.html") {
            UIApplication.shared.open(url)
        }
    }

    private func binding<Value>(get: @escaping () -> Value, set: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(get: get, set: set)
    }

    // Local helper for SettingsView scope
    private func versionString() -> String {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String) ?? ""
        let build = (info?["CFBundleVersion"] as? String) ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }
}

struct ContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var rotationAngle: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var activeCard: ContactCardKind?
    
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
                        
                        appleMark
                    }
                    .scaleEffect(pulseScale)
                    
                    // Text content with liquid glass effect
                    VStack(spacing: 16) {
                    Text(L.contactAuthor.localized)
                        .font(.system(size: 32, weight: .semibold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .shadow(color: .white.opacity(0.5), radius: 8)
                    
                    GeometryReader { proxy in
                        let maxWidth = min(proxy.size.width * 0.88, 380)
                        let cardHeight = max(120, min(170, proxy.size.width * 0.38))
                        let overlap = cardHeight * 0.45
                        let cards = ContactCardKind.allCases
                        let totalHeight = cardHeight + overlap * CGFloat(cards.count - 1)
                        
                        ZStack(alignment: .top) {
                            ForEach(Array(cards.enumerated()), id: \.1) { index, card in
                                Button {
                                    bounceAndPerform(card)
                                } label: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        HStack(spacing: 10) {
                                            Image(systemName: card.icon)
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundStyle(.white.opacity(0.95))
                                                .frame(width: 32, height: 32)
                                                .background(Circle().fill(.white.opacity(0.12)))
                                            Text(title(for: card))
                                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                                .foregroundStyle(.white.opacity(0.95))
                                        }
                                        Text(card.subtitle)
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                            .foregroundStyle(.white.opacity(0.85))
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 18)
                                    .frame(width: maxWidth, height: cardHeight, alignment: .topLeading)
                                    .background(cardBackground(for: card))
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                    .shadow(color: .black.opacity(0.22), radius: 10, y: 6)
                                }
                                .buttonStyle(.plain)
                                .offset(y: CGFloat(index) * overlap)
                                .scaleEffect(activeCard == card ? 1.03 : 1.0)
                                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: activeCard)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: totalHeight, alignment: .top)
                    }
                    .frame(height: max(260, UIScreen.main.bounds.width * 0.6))
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

    private func bounceAndPerform(_ card: ContactCardKind) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            activeCard = card
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            perform(card)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    activeCard = nil
                }
            }
        }
    }

    private func title(for card: ContactCardKind) -> String {
        switch card {
        case .email: return L.contactEmail.localized
        case .rednote: return L.contactRednote.localized
        case .github: return L.contactGithub.localized
        }
    }

    private func perform(_ card: ContactCardKind) {
        switch card {
        case .email:
            let email = "rangertars777@gmail.com"
            let subject = "KuaiJi Feedback"
            let info = Bundle.main.infoDictionary
            let appVersion = (info?["CFBundleShortVersionString"] as? String) ?? ""
            let appBuild = (info?["CFBundleVersion"] as? String) ?? ""
            let osVersion = UIDevice.current.systemVersion
            let osBuild = ContactView.fetchOSBuildVersion() ?? ""
            let language = Locale.current.identifier
            let device = ContactView.marketingDeviceName()

            let lines: [String] = [
                "Device: \(device)",
                "iOS: \(osVersion)\(osBuild.isEmpty ? "" : " (\(osBuild))")",
                "App: \(appVersion) (\(appBuild))",
                "Language: \(language)",
                "",
                "",
                "Please write your suggestions below (you can add screenshots):",
                "",
                ""
            ]
            let body = lines.joined(separator: "\r\n")

            var components = URLComponents()
            components.scheme = "mailto"
            components.path = email
            components.queryItems = [
                URLQueryItem(name: "subject", value: subject),
                URLQueryItem(name: "body", value: body)
            ]
            if let url = components.url {
                openURL(url)
            }
        case .rednote:
            if let url = URL(string: "https://www.xiaohongshu.com/user/profile/5b815f2d47bf040001a99d94?xsec_token=YBZpK0YrWREW6VWRFKrUhGlh_jMjVWqu6nVjX2p9iNlIo=&xsec_source=app_share&xhsshare=CopyLink&shareRedId=N0g6MThLNk06PkdIOTwwNjY0SkA9ST89&apptime=1764280587&share_id=b2892ebc9b194468947fa9ba0efc65ba") {
                UIApplication.shared.open(url)
            }
        case .github:
            if let url = URL(string: "https://github.com/GuoRan7771/KuaiJi_IOSApp") {
                openURL(url)
            }
        }
    }

    @ViewBuilder
    private func cardBackground(for card: ContactCardKind) -> some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(
                LinearGradient(colors: card.colors,
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
            )
            .opacity(0.9)
    }
}

private extension ContactView {
    enum ContactCardKind: CaseIterable {
        case email
        case rednote
        case github

        var icon: String {
            switch self {
            case .email: return "envelope.fill"
            case .rednote: return "globe.asia.australia.fill"
            case .github: return "chevron.left.forwardslash.chevron.right"
            }
        }

        var subtitle: String {
            switch self {
            case .email:
                return L.contactEmailSubtitle.localized
            case .rednote:
                return L.contactRednoteSubtitle.localized
            case .github:
                return L.contactGithubSubtitle.localized
            }
        }

        var colors: [Color] {
            switch self {
            case .email:
                return [Color(red: 0.18, green: 0.35, blue: 0.9), Color(red: 0.08, green: 0.16, blue: 0.46)]
            case .rednote:
                return [Color(red: 0.92, green: 0.26, blue: 0.32), Color(red: 0.62, green: 0.12, blue: 0.18)]
            case .github:
                return [Color(red: 0.1, green: 0.1, blue: 0.1), Color(red: 0.2, green: 0.2, blue: 0.2)]
            }
        }
    }

    static func fetchOSBuildVersion() -> String? {
        var size: size_t = 0
        sysctlbyname("kern.osversion", nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: Int(size))
        sysctlbyname("kern.osversion", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    static func hardwareIdentifier() -> String {
        var size: size_t = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var buffer = [CChar](repeating: 0, count: Int(size))
        sysctlbyname("hw.machine", &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    static func marketingDeviceName() -> String {
        let id = hardwareIdentifier()
        let map: [String: String] = [
            // iPhone 15 family
            "iPhone15,4": "iPhone 15",
            "iPhone15,5": "iPhone 15 Plus",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            // iPhone 14 family
            "iPhone14,7": "iPhone 14",
            "iPhone14,8": "iPhone 14 Plus",
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            // iPhone 13 family
            "iPhone14,4": "iPhone 13 mini",
            "iPhone14,5": "iPhone 13",
            "iPhone14,2": "iPhone 13 Pro",
            "iPhone14,3": "iPhone 13 Pro Max",
            // iPhone 12 family
            "iPhone13,1": "iPhone 12 mini",
            "iPhone13,2": "iPhone 12",
            "iPhone13,3": "iPhone 12 Pro",
            "iPhone13,4": "iPhone 12 Pro Max",
            // iPhone 11 family
            "iPhone12,1": "iPhone 11",
            "iPhone12,3": "iPhone 11 Pro",
            "iPhone12,5": "iPhone 11 Pro Max",
            // iPhone X / XS / XR / 8
            "iPhone10,3": "iPhone X",
            "iPhone10,6": "iPhone X",
            "iPhone11,2": "iPhone XS",
            "iPhone11,4": "iPhone XS Max",
            "iPhone11,6": "iPhone XS Max",
            "iPhone11,8": "iPhone XR",
            "iPhone10,1": "iPhone 8",
            "iPhone10,4": "iPhone 8",
            "iPhone10,2": "iPhone 8 Plus",
            "iPhone10,5": "iPhone 8 Plus"
        ]
        return map[id] ?? "iPhone (\(id))"
    }
    
    var appleMark: some View {
        Group {
            if UIImage(systemName: "apple.logo") != nil {
                Image(systemName: "apple.logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 76)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, .white.opacity(0.9)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            } else if let appIcon = UIImage(named: "AppIcon") {
                Image(uiImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .shadow(color: .white.opacity(0.5), radius: 10)
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
        case .selfImprovement: return L.categorySelfImprovement.localized
        case .school: return L.categorySchool.localized
        case .medical: return L.categoryMedical.localized
        case .clothing: return L.categoryClothing.localized
        case .investment: return L.categoryInvestment.localized
        case .social: return L.categorySocial.localized
        case .other: return L.categoryOther.localized
        }
    }
}


// iOS 18 项目，直接使用现代 onChange API
private extension View {
    @ViewBuilder
    func onChangeCompat<Value: Equatable>(of value: Value, perform action: @escaping () -> Void) -> some View {
        // iOS 17+ onChange API with oldValue and newValue parameters
        onChange(of: value, initial: false) { _, _ in action() }
    }
}

// MARK: - Main ContentView & Navigation

struct ContentView: View {
    @ObservedObject var viewModel: AppRootViewModel
    @ObservedObject var personalLedgerRoot: PersonalLedgerRootViewModel
    @StateObject private var listViewModel: LedgerListScreenModel
    @StateObject private var friendViewModel: FriendListScreenModel
    @StateObject private var settingsViewModel: SettingsScreenModel
    @EnvironmentObject var appState: AppState
    @AppStorage("theme") private var theme = "default"
    
    private enum RootTab: Hashable { case personal, ledgers, friends, settings }
    @State private var selectedTab: RootTab = .personal
    @State private var path = NavigationPath()
    private let switchToLedgersTab: () -> Void

    init(viewModel: AppRootViewModel, personalLedgerRoot: PersonalLedgerRootViewModel, switchToLedgersTab: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.personalLedgerRoot = personalLedgerRoot
        self.switchToLedgersTab = switchToLedgersTab
        _listViewModel = StateObject(wrappedValue: viewModel.makeLedgerListViewModel())
        _friendViewModel = StateObject(wrappedValue: viewModel.makeFriendListViewModel())
        _settingsViewModel = StateObject(wrappedValue: viewModel.makeSettingsViewModel())
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            if appState.showPersonalLedgerTab {
                PersonalLedgerNavigator(root: personalLedgerRoot)
                    .environmentObject(viewModel)
                    .tabItem { Label(L.tabPersonalLedger.localized, systemImage: "wallet.pass") }
                    .tag(RootTab.personal)
            }

            if appState.showSharedLedgerTab {
                LedgerNavigator(rootViewModel: viewModel,
                                listViewModel: listViewModel,
                                onRequireLedgerTab: { selectedTab = .ledgers })
                    .tabItem { Label(L.tabLedgers.localized, systemImage: "list.bullet") }
                    .tag(RootTab.ledgers)

                FriendNavigator(viewModel: friendViewModel, rootViewModel: viewModel)
                    .tabItem { Label(L.tabFriends.localized, systemImage: "person.2.fill") }
                    .tag(RootTab.friends)
            }

            SettingsNavigator(viewModel: settingsViewModel, rootViewModel: viewModel, personalLedgerRoot: personalLedgerRoot)
                .tabItem { Label(L.tabSettings.localized, systemImage: "gearshape") }
                .tag(RootTab.settings)
        }
        .id(theme) // Force full rebuild when theme changes to update all colors
        .onChangeCompat(of: appState.showPersonalLedgerTab) { ensureValidSelectedTab() }
        .onChangeCompat(of: appState.showSharedLedgerTab) { ensureValidSelectedTab() }
        .onChangeCompat(of: appState.quickActionTarget) {
            handleGlobalQuickAction()
        }
        .onChangeCompat(of: appState.settingsDeepLink) {
            handleSettingsDeepLinkTabSwitch()
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPersonalTemplates)) { _ in
            selectedTab = .settings
        }
        .onChangeCompat(of: selectedTab) {
            if selectedTab == .ledgers {
                appState.requestSharedTabLandingActivation()
            }
        }
        .onAppear {
            handleSettingsDeepLinkTabSwitch()
        }
        .tint(Color.appTextPrimary)
        .background(Color.appBackground.ignoresSafeArea())
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func ensureValidSelectedTab() {
        // 如果当前选中的 tab 已被隐藏，切换到第一个可见 tab
        switch selectedTab {
        case .personal:
            if !appState.showPersonalLedgerTab {
                selectedTab = appState.showSharedLedgerTab ? .ledgers : .settings
            }
        case .ledgers, .friends:
            if !appState.showSharedLedgerTab {
                selectedTab = appState.showPersonalLedgerTab ? .personal : .settings
            }
        case .settings:
            // 永远可用，无需处理
            break
        }
    }

    private func handleGlobalQuickAction() {
        guard case .shared = appState.quickActionTarget else { return }
        selectedTab = .ledgers
    }

    private func handleSettingsDeepLinkTabSwitch() {
        if appState.settingsDeepLink != nil {
            selectedTab = .settings
        }
    }

    // MARK: - App Version Helper
    private func versionString() -> String {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String) ?? ""
        let build = (info?["CFBundleVersion"] as? String) ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }
}

struct LedgerNavigator: View {
    @ObservedObject var rootViewModel: AppRootViewModel
    @ObservedObject var listViewModel: LedgerListScreenModel
    @EnvironmentObject var appState: AppState
    @State private var showingCreateLedger = false
    @State private var showingShareLedger = false
    @State private var quickActionLedger: LedgerSummaryViewData?
    @State private var path = NavigationPath()
    let onRequireLedgerTab: () -> Void

    var body: some View {
        NavigationStack(path: $path) {
            LedgerListView(viewModel: listViewModel)
                .navigationTitle(L.ledgersPageTitle.localized)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showingShareLedger = true }) {
                            Label(L.syncShareLedger.localized, systemImage: "antenna.radiowaves.left.and.right")
                        }
                        .tint(Color.appTextPrimary)
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingCreateLedger = true }) {
                            Label(L.ledgersNew.localized, systemImage: "plus")
                        }
                        .tint(Color.appTextPrimary)
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
                .sheet(item: $quickActionLedger) { ledger in
                    ExpenseFormHost(rootViewModel: rootViewModel, ledgerId: ledger.id)
                }
                .onChangeCompat(of: appState.quickActionTarget) {
                    handleQuickAction()
                }
                .onAppear {
                    activateSharedLandingIfNeeded()
                    // 处理首次出现前已设置的 Quick Action 情况
                    handleQuickAction()
                }
                .onChangeCompat(of: appState.sharedTabActivateAt) {
                    activateSharedLandingIfNeeded()
                }
        }
        .background(Color.appBackground)
    }
    
    private func handleQuickAction() {
        guard case .shared(let ledgerId) = appState.quickActionTarget else {
            return
        }

        guard let summary = rootViewModel.ledgerSummaries.first(where: { $0.id == ledgerId }) else {
            appState.quickActionTarget = nil
            return
        }

        appState.quickActionTarget = nil

        onRequireLedgerTab()
        var newPath = NavigationPath()
        newPath.append(summary)
        path = newPath

        DispatchQueue.main.async {
            quickActionLedger = summary
        }
    }

    private func activateSharedLandingIfNeeded() {
        switch appState.getSharedLandingPreference() {
        case .list:
            break
        case .ledger(let ledgerId):
            guard let summary = rootViewModel.ledgerSummaries.first(where: { $0.id == ledgerId }) else {
                return
            }
            // 重置路径并跳转到指定账本
            var newPath = NavigationPath()
            newPath.append(summary)
            path = newPath
        }
    }
}

struct SettingsNavigator: View {
    @ObservedObject var viewModel: SettingsScreenModel
    @ObservedObject var rootViewModel: AppRootViewModel
    @ObservedObject var personalLedgerRoot: PersonalLedgerRootViewModel
    @StateObject private var personalSettingsModel: PersonalLedgerSettingsViewModel
    
    init(viewModel: SettingsScreenModel, rootViewModel: AppRootViewModel, personalLedgerRoot: PersonalLedgerRootViewModel) {
        self.viewModel = viewModel
        self.rootViewModel = rootViewModel
        self.personalLedgerRoot = personalLedgerRoot
        _personalSettingsModel = StateObject(wrappedValue: personalLedgerRoot.makeSettingsViewModel())
    }
    
    var body: some View {
        NavigationStack {
            SettingsView(viewModel: viewModel,
                        rootViewModel: rootViewModel,
                        personalSettingsViewModel: personalSettingsModel,
                        personalLedgerRoot: personalLedgerRoot)
        }
        .background(Color.appBackground)
    }
}

// MARK: - Support Me Page (Sheet)

struct SupportMeView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("support.hasSupported") private var hasSupported = false
    @StateObject private var store = StoreKitManager()
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var appState: AppState

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(L.supportTitle.localized)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.appTextPrimary)
                    if hasSupported {
                        Text(L.supportSuccess.localized)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.appSuccess)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.top, 28)

                Text(L.supportDisclaimer.localized)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.appSecondaryText)
                    .padding(.horizontal)
                    .padding(.bottom, 10)

                VStack(spacing: 12) {
                    let hasCoffee = store.products.contains { $0.id == "tip.coffee.099" }
                    let hasCake   = store.products.contains { $0.id == "tip.bakery.299" }
                    let hasSushi  = store.products.contains { $0.id == "tip.sushi.999" }

                    TipCard(title: L.supportCoffee.localized,
                            emoji: "☕️",
                            price: store.displayPrice(for: "tip.coffee.099", fallback: "$0.99"),
                            color: .appTextPrimary,
                            action: {
                                Task { await store.buy("tip.coffee.099") }
                            },
                            isEnabled: hasCoffee)
                    TipCard(title: L.supportCheesecake.localized,
                            emoji: "🍰",
                            price: store.displayPrice(for: "tip.bakery.299", fallback: "$2.99"),
                            color: .appTextPrimary,
                            action: {
                                Task { await store.buy("tip.bakery.299") }
                            },
                            isEnabled: hasCake)
                    TipCard(title: L.supportSushi.localized,
                            emoji: "🍱",
                            price: store.displayPrice(for: "tip.sushi.999", fallback: "$9.99"),
                            color: .appTextPrimary,
                            action: {
                                Task { await store.buy("tip.sushi.999") }
                            },
                            isEnabled: hasSushi)
                    if store.products.isEmpty {
                        Text("Loading prices…")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }
                .padding(.horizontal)

                // Move the feature note below the tip options
                Text(L.supportNoFeatureNote.localized)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.appSecondaryText)
                    .padding(.horizontal)
                    .padding(.top, 4)

                Spacer(minLength: 20)
            }
            .padding(.bottom, 24)
        }
        .background(
            Group {
                if colorScheme == .dark {
                    // Deep dark background for readability (#0E0E11)
                    Color.appBackground
                } else {
                    LinearGradient(colors: [Color.appSurfaceAlt, Color.appBackground], startPoint: .top, endPoint: .bottom)
                }
            }
        )
        .ignoresSafeArea()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if store.purchasing { ProgressView().controlSize(.small) }
            }
        }
        .onAppear {
            Task { await store.load(); store.listenForUpdates() }
            appState.isSupportSheetVisible = true
        }
        .task {
            await store.load()
            store.listenForUpdates()
        }
        .onDisappear { appState.isSupportSheetVisible = false }
        .alert(isPresented: Binding(get: { (appState.iapAlertMessage?.isEmpty == false) && appState.isSupportSheetVisible }, set: { _ in appState.iapAlertTitle = nil; appState.iapAlertMessage = nil })) {
            Alert(title: Text(appState.iapAlertTitle ?? L.supportPurchaseTitle.localized), message: Text(appState.iapAlertMessage ?? ""), dismissButton: .default(Text(L.ok.localized)))
        }
    }
}

private struct TipCard: View {
    let title: String
    let emoji: String
    let price: String
    let color: Color
    let action: () -> Void
    var isEnabled: Bool = true

    @State private var pressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { pressed = true }
            action()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring()) { pressed = false }
            }
        }) {
            HStack(spacing: 16) {
                Text(emoji).font(.system(size: 40))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 18, weight: .semibold, design: .rounded)).foregroundStyle(Color.appTextPrimary)
                    Text(price).font(.system(size: 14, weight: .medium, design: .rounded)).foregroundStyle(color)
                }
                Spacer()
                Image(systemName: "heart.fill").foregroundStyle(Color.appToggleOn)
            }
            .padding(16)
            .scaleEffect(pressed ? 0.97 : 1.0)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.appSurface))
            .shadow(color: Color.appCardShadow, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1.0 : 0.5)
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
                        .tint(Color.appTextPrimary)
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
        .background(Color.appBackground)
    }
}

struct LedgerListView<Model: LedgerListViewModelProtocol>: View {
    @ObservedObject var viewModel: Model
    @State private var pendingDeletion: LedgerSummaryViewData?

    var body: some View {
        List {
            Section(L.ledgersRecentUpdates.localized) {
                ForEach(viewModel.ledgers) { ledger in
                    NavigationLink(value: ledger) {
                        LedgerSummaryRow(ledger: ledger)
                    }
                    .accessibilityLabel("\(ledger.name), \(L.ledgersMemberCount.localized(ledger.memberCount)), \(L.ledgersOutstanding.localized(ledger.outstandingDisplay))")
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            viewModel.archiveLedger(id: ledger.id)
                        } label: {
                            Label(L.ledgersArchiveAction.localized, systemImage: "archivebox")
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            pendingDeletion = ledger
                        } label: {
                            Label(L.delete.localized, systemImage: "trash")
                        }
                    }
                }
                .onDelete { indexSet in
                    if let first = indexSet.first, viewModel.ledgers.indices.contains(first) {
                        pendingDeletion = viewModel.ledgers[first]
                    }
                }
            }
            if !viewModel.archivedLedgers.isEmpty {
                Section(L.ledgersArchived.localized) {
                    ForEach(viewModel.archivedLedgers) { ledger in
                        NavigationLink(value: ledger) {
                            LedgerSummaryRow(ledger: ledger, isArchived: true)
                        }
                        .accessibilityLabel("\(ledger.name), \(L.ledgersMemberCount.localized(ledger.memberCount)), \(L.ledgersOutstanding.localized(ledger.outstandingDisplay)), \(L.ledgersArchived.localized)")
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                viewModel.unarchiveLedger(id: ledger.id)
                            } label: {
                                Label(L.ledgersUnarchiveAction.localized, systemImage: "arrow.uturn.left")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                pendingDeletion = ledger
                            } label: {
                                Label(L.delete.localized, systemImage: "trash")
                            }
                        }
                    }
                    .onDelete { indexSet in
                        if let first = indexSet.first, viewModel.archivedLedgers.indices.contains(first) {
                            pendingDeletion = viewModel.archivedLedgers[first]
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .alert(L.ledgersDeleteConfirmTitle.localized, isPresented: Binding(get: { pendingDeletion != nil }, set: { newValue in
            if !newValue { pendingDeletion = nil }
        })) {
            Button(L.cancel.localized, role: .cancel) {
                pendingDeletion = nil
            }
            Button(L.delete.localized, role: .destructive) {
                if let ledger = pendingDeletion {
                    viewModel.deleteLedger(id: ledger.id)
                }
                pendingDeletion = nil
            }
        } message: {
            Text(L.ledgersDeleteConfirmMessage.localized)
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
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .sheet(item: $editingFriend) { friend in
            EditFriendSheet(viewModel: viewModel, friend: friend)
        }
    }
}

struct LedgerSummaryRow: View {
    var ledger: LedgerSummaryViewData
    var isArchived: Bool = false

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
            if isArchived {
                Text(L.ledgersArchivedTag.localized)
                    .font(.caption2)
                    .foregroundStyle(Color.appSecondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
            }
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
        ZStack(alignment: .bottomTrailing) {
            LedgerOverviewView(viewModel: viewModel,
                               onAddExpense: { showExpenseForm = true },
                               onOpenSettlement: { showSettlement = true },
                               onShowRecords: { showRecords = true })
            FloatingActionButton(systemImage: "plus") { showExpenseForm = true }
                .accessibilityLabel(L.ledgerAddExpense.localized)
                .padding(.trailing, 24)
                .padding(.bottom, 24)
        }
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
    @State private var showClearConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 第一栏：总支出
                totalExpensesCard
                
                // 第二栏：当前净额
                netBalancesCard
                
                // 第三栏：最近流水
                recentRecordsCard
                
                // 第四栏：成员支出
                memberExpensesCard
                
                // 第五栏：转账方案
                transferPlanCard
            }
            .padding()
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showAllMembers) {
            AllMembersSheet(memberExpenses: viewModel.memberExpenses)
        }
        .sheet(isPresented: $showAllRecords) {
            RecordsSheet(viewModel: viewModel)
        }
        .alert(L.clearBalancesConfirmTitle.localized, isPresented: $showClearConfirmation) {
            Button(L.cancel.localized, role: .cancel) { }
            Button(L.clearBalancesConfirmButton.localized) {
                viewModel.clearAllBalances()
            }
        } message: {
            Text(L.clearBalancesConfirmMessage.localized)
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
                .foregroundStyle(Color.appSelection)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.appSelection.opacity(0.1)))
    }
    
    // 第四栏：成员支出
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
                        .foregroundStyle(Color.appLedgerContentText)
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
                            .foregroundStyle(Color.appSelection)
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
                        .foregroundStyle(Color.appLedgerContentText)
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
                                    .foregroundStyle(Color.appSelection)
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
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.appDanger.opacity(0.1)))
    }
    
    // 第二栏：当前净额
    private var netBalancesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.settlementCurrentNet.localized)
                .font(.headline)
            
            if viewModel.balances.isEmpty {
                Text(L.settlementAllSettled.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.balances) { balance in
                        HStack {
                            Text(balance.userName)
                                .font(.subheadline)
                            Spacer()
                            Text(balance.amountDisplay)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(balance.isPositive ? Color.appSuccess : Color.appDanger)
                        }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.appWarning.opacity(0.15)))
    }
    
    // 第五栏：转账方案
    private var transferPlanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.settlementMinTransfers.localized)
                .font(.headline)
            
            if viewModel.transferPlan.isEmpty {
                Text(L.settlementAllSettled.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.transferPlan) { transfer in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(transfer.fromName) → \(transfer.toName)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(transfer.amountDisplay)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // 一键清账按钮
                    Button(action: { showClearConfirmation = true }) {
                        HStack {
                            Label(L.ledgerCardClearBalances.localized, systemImage: "checkmark.circle")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.appSuccess.opacity(0.1)))
                        .foregroundStyle(Color.appSuccess)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.1)))
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
                            .foregroundStyle(Color.appSelection)
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(L.allMembersTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.close.localized) { dismiss() }
                    .tint(Color.appTextPrimary)
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
                                    Text("\(record.payerName) · \(record.splitModeDisplay)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(record.amountDisplay)
                                        .font(.headline)
                                        .foregroundStyle(Color.appSelection)
                                    Text(record.date, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: categoryIcon(for: record.category))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(record.category.displayName)
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
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
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
        case .selfImprovement: return "brain.head.profile"
        case .school: return "graduationcap.fill"
        case .medical: return "cross.case.fill"
        case .clothing: return "tshirt.fill"
        case .investment: return "chart.line.uptrend.xyaxis"
        case .social: return "person.2.fill"
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
                            Text(currency.displayLabel).tag(currency)
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
                                    .foregroundStyle(Color.appSelection)
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
                                                .fill(selectedEmoji == emoji ? Color.appSelection.opacity(0.2) : Color.secondary.opacity(0.1))
                                        )
                                        .overlay(
                                            Circle()
                                                .strokeBorder(selectedEmoji == emoji ? Color.appSelection : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(L.friendsAddTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel.localized) { dismiss() }
                    .tint(Color.appTextPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.save.localized) {
                        viewModel.addFriend(named: name, emoji: selectedEmoji, currency: selectedCurrency)
                        dismiss()
                    }
                    .tint(Color.appTextPrimary)
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
                            Text(currency.displayLabel).tag(currency)
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
                                    .foregroundStyle(Color.appSelection)
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
                                                .fill(selectedEmoji == emoji ? Color.appSelection.opacity(0.2) : Color.secondary.opacity(0.1))
                                        )
                                        .overlay(
                                            Circle()
                                                .strokeBorder(selectedEmoji == emoji ? Color.appSelection : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(L.friendsEditTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel.localized) { dismiss() }
                    .tint(Color.appTextPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.save.localized) {
                        viewModel.updateFriend(id: friend.id, name: name, currency: selectedCurrency, emoji: selectedEmoji)
                        dismiss()
                    }
                    .tint(Color.appTextPrimary)
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
                            Text(currency.displayLabel).tag(currency)
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
                                    .foregroundStyle(Color.appTextPrimary)
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
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
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
                    Picker(selection: $selectedCurrency) {
                        ForEach(CurrencyCode.allCases) { currency in
                            Text(currency.displayLabel).tag(currency)
                        }
                    } label: {
                        Text(L.profileCurrencyPicker.localized)
                            .foregroundStyle(Color.appLedgerContentText)
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
                                        .fill(Color.appSelection.opacity(0.1))
                                )
                        }
                        .padding(.vertical, 8)
                        
                        Divider()
                        
                        // 标题和"全部"按钮
                        HStack {
                            Text(L.onboardingAvatarSection.localized)
                                .font(.subheadline)
                                .foregroundStyle(Color.appLedgerContentText)
                            
                            Spacer()
                            
                            Button {
                                showAllEmojis = true
                            } label: {
                                Text(L.all.localized)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appLedgerContentText)
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
                                                .fill(selectedEmoji == emoji ? Color.appSelection.opacity(0.2) : Color.secondary.opacity(0.1))
                                        )
                                        .overlay(
                                            Circle()
                                                .strokeBorder(selectedEmoji == emoji ? Color.appSelection : Color.clear, lineWidth: 2)
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
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
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
        // 使用全局 window 级手势统一处理收起键盘；避免局部手势与子视图交互冲突
        content
    }
}

extension View {
    /// 添加点击空白处隐藏键盘的功能
    func dismissKeyboardOnTap() -> some View {
        self.modifier(DismissKeyboardOnTapModifier())
    }
}

// 全局 Window 级键盘收起安装器（不拦截子视图点击，且仅在点击非输入控件时触发）
final class KeyboardDismissInstaller: NSObject, UIGestureRecognizerDelegate {
    private static var installed = false
    private var tapRecognizers: [UITapGestureRecognizer] = []
    static let shared = KeyboardDismissInstaller()

    static func installIfNeeded() {
        guard !installed else { return }
        installed = true
        shared.install()
    }

    private func install() {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        for scene in scenes {
            for window in scene.windows {
                let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
                tap.cancelsTouchesInView = false
                tap.delegate = self
                window.addGestureRecognizer(tap)
                tapRecognizers.append(tap)
            }
        }
    }

    @objc private func handleTap(_ sender: UITapGestureRecognizer) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    // 仅在点击非输入控件区域时触发，避免点击文本框本身也收起键盘
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view: UIView? = touch.view
        while let v = view {
            if v is UITextField || v is UITextView { return false }
            view = v.superview
        }
        return true
    }
}

// NOTE: This coordinator is not used anymore; tab switching is handled via state inside ContentView.

#Preview {
    let schema = Schema([
        UserProfile.self,
        Ledger.self,
        Membership.self,
        Expense.self,
        ExpenseParticipant.self,
        BalanceSnapshot.self,
        TransferPlan.self,
        AuditLog.self,
        PersonalCategoryDefinition.self,
        PersonalAccount.self,
        PersonalTransaction.self,
        AccountTransfer.self,
        PersonalRecordTemplate.self,
        PersonalPreferences.self
    ])
    let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    do {
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let personalRoot = PersonalLedgerRootViewModel(modelContext: container.mainContext, defaultCurrency: .cny)
        return ContentView(viewModel: AppRootViewModel(), personalLedgerRoot: personalRoot)
            .modelContainer(container)
    } catch {
        let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        if let container = try? ModelContainer(for: schema, configurations: [fallbackConfig]) {
            let personalRoot = PersonalLedgerRootViewModel(modelContext: container.mainContext, defaultCurrency: .cny)
            return ContentView(viewModel: AppRootViewModel(), personalLedgerRoot: personalRoot)
                .modelContainer(container)
        }
        return Text("Preview init failed: \(error.localizedDescription)")
    }
}
