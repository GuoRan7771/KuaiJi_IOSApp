//
//  SharedLedgerViewModelProtocols.swift
//  KuaiJi
//
//  Shared ledger view model protocol contracts.
//

import Foundation
import Combine

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
