//
//  PersonalLedgerViewData.swift
//  KuaiJi
//

import Combine
import Foundation
import SwiftData
import SwiftUI

struct PersonalOverviewEntry: Identifiable, Hashable {
    var currency: CurrencyCode
    var expenseMinorUnits: Int
    var incomeMinorUnits: Int

    var id: CurrencyCode { currency }
}

struct PersonalOverviewState {
    var entries: [PersonalOverviewEntry] = []
    var includeFees: Bool = true
}

struct PersonalYearMonth: Hashable, Identifiable, Comparable {
    var year: Int
    var month: Int

    var id: String { "\(year)-\(month)" }

    var date: Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }

    static func < (lhs: PersonalYearMonth, rhs: PersonalYearMonth) -> Bool {
        if lhs.year == rhs.year { return lhs.month < rhs.month }
        return lhs.year < rhs.year
    }
}

// Removed: PersonalMonthlyTotals (no longer needed after removing totals display in archive)

struct PersonalRecordRowViewData: Identifiable, Hashable {
    enum EntryNature: Hashable {
        case transaction(PersonalTransactionKind)
        case transfer
    }

    var id: UUID
    var categoryKey: String
    var categoryName: String
    var categoryColorHex: String?
    var systemImage: String
    var note: String
    var amountMinorUnits: Int
    var currency: CurrencyCode
    var occurredAt: Date
    var createdAt: Date
    var accountName: String
    var accountId: UUID?
    var entryNature: EntryNature
    var transferDescription: String?

    var isTransfer: Bool {
        if case .transfer = entryNature { return true }
        return false
    }

    var amountIsPositive: Bool {
        switch entryNature {
        case .transaction(let kind): return kind == .income
        case .transfer: return false
        }
    }

    var transactionKind: PersonalTransactionKind? {
        if case .transaction(let kind) = entryNature { return kind }
        return nil
    }
}

struct PersonalRecordTemplateViewData: Identifiable, Hashable {
    var id: UUID
    var name: String
    var accountId: UUID?
    var accountName: String?
    var amountMinorUnits: Int
    var currency: CurrencyCode
    var categoryKey: String
    var categoryName: String
    var systemImage: String
    var note: String?
}

struct PersonalAccountRowViewData: Identifiable, Hashable {
    var id: UUID
    var name: String
    var type: PersonalAccountType
    var currency: CurrencyCode
    var balanceMinorUnits: Int
    var includeInNetWorth: Bool
    var note: String?
    var status: PersonalAccountStatus
    var convertedBalanceMinorUnits: Int
    var creditLimitMinorUnits: Int?
}

struct PersonalNetWorthEntry: Identifiable, Hashable {
    var currency: CurrencyCode
    var totalMinorUnits: Int

    var id: CurrencyCode { currency }
}

struct PersonalNetWorthSummaryViewData {
    var entries: [PersonalNetWorthEntry]
}

struct PersonalRecordFilterState: Equatable {
    var dateRange: ClosedRange<Date>?
    var kinds: Set<PersonalTransactionKind>
    var accountIds: Set<UUID>
    var categoryKeys: Set<String>
    var minAmountText: String
    var maxAmountText: String
    var keyword: String

    static let `default` = PersonalRecordFilterState(dateRange: nil,
                                                     kinds: [.income, .expense, .fee],
                                                     accountIds: [],
                                                     categoryKeys: [],
                                                     minAmountText: "",
                                                     maxAmountText: "",
                                                     keyword: "")

    func toFilter() -> PersonalRecordFilter {
        var minimum: Int?
        if let value = NumberParsing.parseDecimal(minAmountText), value > 0 {
            minimum = SettlementMath.minorUnits(from: value, scale: 2)
        }
        var maximum: Int?
        if let value = NumberParsing.parseDecimal(maxAmountText), value > 0 {
            maximum = SettlementMath.minorUnits(from: value, scale: 2)
        }
        return PersonalRecordFilter(dateRange: dateRange,
                                    kinds: kinds.isEmpty ? nil : kinds,
                                    accountIds: accountIds.isEmpty ? nil : accountIds,
                                    categoryKeys: categoryKeys.isEmpty ? nil : categoryKeys,
                                    minimumAmountMinor: minimum,
                                    maximumAmountMinor: maximum,
                                    keyword: keyword.isEmpty ? nil : keyword)
    }
}

struct PersonalStatsSeriesPoint: Identifiable, Hashable {
    var id: UUID = UUID()
    var date: Date
    var incomeMinorUnits: Int
    var expenseMinorUnits: Int
}

struct PersonalStatsCategoryShare: Identifiable, Hashable {
    var id: UUID = UUID()
    var categoryKey: String
    var amountMinorUnits: Int
    var transactionCount: Int
}

struct PersonalStatsGrowthMetrics {
    let current: Int
    let previous: Int
    let delta: Int
    let rate: Double
}

enum PersonalStatsCategoryFocus {
    case expense
    case income
}
