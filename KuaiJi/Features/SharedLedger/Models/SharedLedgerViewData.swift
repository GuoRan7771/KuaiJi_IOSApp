//
//  SharedLedgerViewData.swift
//  KuaiJi
//
//  Shared ledger view data and UI enums.
//

import Foundation
import SwiftUI

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
    var amountMinorUnits: Int
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
