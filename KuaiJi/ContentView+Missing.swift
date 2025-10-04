//
//  ContentView+Missing.swift
//  KuaiJi
//
//  补全缺失的 ScreenModel 与 Helper（不含重复视图组件）
//

import SwiftUI
import Combine

// MARK: - Missing Screen Models

@MainActor
final class SettlementScreenModel: ObservableObject, SettlementViewModelProtocol {
    @Published private(set) var netBalances: [NetBalanceViewData]
    @Published private(set) var transferPlan: [TransferRecordViewData]

    private weak var root: AppRootViewModel?
    private let ledgerId: UUID
    private var filters = LedgerFilterState()

    init(root: AppRootViewModel, ledgerId: UUID) {
        let initialFilters = LedgerFilterState()
        self.root = root
        self.ledgerId = ledgerId
        self.filters = initialFilters
        self.netBalances = root.netBalancesViewData(ledgerId: ledgerId, filters: initialFilters)
        self.transferPlan = root.transferPlanViewData(ledgerId: ledgerId, filters: initialFilters)
    }

    func generatePlan() {
        guard let root else { return }
        netBalances = root.netBalancesViewData(ledgerId: ledgerId, filters: filters)
        transferPlan = root.transferPlanViewData(ledgerId: ledgerId, filters: filters)
    }
    
    func clearAllBalances() {
        guard let root else { return }
        root.clearLedgerBalances(ledgerId: ledgerId)
        // 刷新数据
        generatePlan()
    }
}

@MainActor
final class MemberDetailScreenModel: ObservableObject, MemberDetailViewModelProtocol {
    @Published private(set) var member: MemberSummaryViewData
    @Published private(set) var breakdown: [CategoryBreakdown]
    @Published private(set) var timeline: [TimeSeriesPoint]

    private weak var root: AppRootViewModel?
    private let ledgerId: UUID
    private let memberId: UUID

    init(root: AppRootViewModel, ledgerId: UUID, memberId: UUID) {
        self.root = root
        self.ledgerId = ledgerId
        self.memberId = memberId
        self.member = root.member(with: memberId) ?? MemberSummaryViewData(id: memberId, name: L.defaultUnknownMember.localized, avatarSystemName: "person.circle", currency: .cny, avatarEmoji: nil)
        let stats = root.memberBreakdown(ledgerId: ledgerId, memberId: memberId)
        self.breakdown = stats.breakdown
        self.timeline = stats.timeline
    }
}

@MainActor
final class SettingsScreenModel: ObservableObject, SettingsViewModelProtocol {
    @Published var uiState: SettingsViewState
    private weak var root: AppRootViewModel?

    init(root: AppRootViewModel) {
        self.root = root
        // 语言选项不再需要，使用默认值
        self.uiState = SettingsViewState(language: .system)
    }

    func persist() {
        guard let root else { return }
        root.updateSettings(with: uiState)
    }
    
    func clearAllData() {
        root?.clearAllData()
    }
    
    func getCurrentUser() -> UserProfile? {
        return root?.dataManager?.currentUser
    }
    
    func updateUserProfile(name: String, emoji: String, currency: CurrencyCode) {
        root?.updateUserProfile(name: name, emoji: emoji, currency: currency)
    }
}

// MARK: - Root Helpers

enum AmountFormatter {
    static func string(minorUnits: Int, currency: CurrencyCode, locale: Locale) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.locale = locale
        let decimal = SettlementMath.decimal(fromMinorUnits: minorUnits, scale: 2)
        return formatter.string(from: NSDecimalNumber(decimal: decimal)) ?? "\(decimal)"
    }
}
