//
//  PersonalLedgerStore+Analytics.swift
//  KuaiJi
//

import Foundation
import Combine
import SwiftData
import SwiftUI

extension PersonalLedgerStore {
    // MARK: - Analytics

    func categoryBreakdown(for range: ClosedRange<Date>, includeFees: Bool, accountIds: Set<UUID>?) throws -> [String: Int] {
        var kinds: Set<PersonalTransactionKind> = [.expense]
        if includeFees {
            kinds.insert(.fee)
        }
        var filter = PersonalRecordFilter(dateRange: range, kinds: kinds)
        filter.accountIds = accountIds
        let transactions = try records(filter: filter)
        var totals: [String: Int] = [:]
        for transaction in transactions {
            let currency = currency(for: transaction.accountId)
            let converted = convertToDisplay(minorUnits: transaction.amountMinorUnits, currency: currency, fxRate: transaction.fxRate)
            totals[transaction.categoryKey, default: 0] += converted
        }
        return totals
    }

    func timeline(for range: ClosedRange<Date>, kinds: Set<PersonalTransactionKind>, accountIds: Set<UUID>?) throws -> [Date: (income: Int, expense: Int)] {
        var filter = PersonalRecordFilter(dateRange: range, kinds: kinds)
        filter.accountIds = accountIds
        let transactions = try records(filter: filter)
        var daily: [Date: (income: Int, expense: Int)] = [:]
        for transaction in transactions {
            let dayStart = calendar.startOfDay(for: transaction.occurredAt)
            var bucket = daily[dayStart] ?? (income: 0, expense: 0)
            let currency = currency(for: transaction.accountId)
            let converted = convertToDisplay(minorUnits: transaction.amountMinorUnits, currency: currency, fxRate: transaction.fxRate)
            switch transaction.kind {
            case .income:
                bucket.income += converted
            case .expense, .fee:
                bucket.expense += converted
            }
            daily[dayStart] = bucket
        }
        return daily
    }
}
