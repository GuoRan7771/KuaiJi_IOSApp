//
//  PersonalLedgerCategories.swift
//  KuaiJi
//
//  Provides category metadata used by the personal ledger module.
//

import Foundation

struct PersonalCategoryOption: Identifiable, Hashable, Sendable {
    enum Group: Sendable {
        case expense
        case income
        case neutral
    }

    var id: String { key }
    let key: String
    let nameKey: String
    let systemImage: String
    let group: Group

    var localizedName: String { nameKey.localized }

    static func defaultCategories(for kind: PersonalTransactionKind) -> [PersonalCategoryOption] {
        switch kind {
        case .expense: return expenseCategories
        case .income: return incomeCategories
        case .fee: return feeCategories
        }
    }

    static let commonExpenseKeys: [String] = ExpenseCategory.allCases.map { $0.rawValue }
    static let commonIncomeKeys: [String] = ["salary", "bonus", "investment", "sideHustle", "giftIncome", "refund", "otherIncome"]
}

let expenseCategories: [PersonalCategoryOption] = ExpenseCategory.allCases.map { category in
    PersonalCategoryOption(key: category.rawValue,
                           nameKey: sharedExpenseNameKey(for: category),
                           systemImage: sharedExpenseIcon(for: category),
                           group: .expense)
}

let incomeCategories: [PersonalCategoryOption] = [
    PersonalCategoryOption(key: "salary", nameKey: "personal.category.salary", systemImage: "banknote", group: .income),
    PersonalCategoryOption(key: "bonus", nameKey: "personal.category.bonus", systemImage: "gift.fill", group: .income),
    PersonalCategoryOption(key: "investment", nameKey: "personal.category.investment", systemImage: "chart.line.uptrend.xyaxis", group: .income),
    PersonalCategoryOption(key: "sideHustle", nameKey: "personal.category.sideHustle", systemImage: "briefcase.fill", group: .income),
    PersonalCategoryOption(key: "giftIncome", nameKey: "personal.category.giftIncome", systemImage: "sparkles", group: .income),
    PersonalCategoryOption(key: "refund", nameKey: "personal.category.refund", systemImage: "arrow.uturn.backward", group: .income),
    PersonalCategoryOption(key: "otherIncome", nameKey: "personal.category.otherIncome", systemImage: "square.grid.2x2", group: .income)
]

let feeCategories: [PersonalCategoryOption] = [
    PersonalCategoryOption(key: "fees", nameKey: "personal.category.fees", systemImage: "creditcard", group: .neutral)
]

func iconForCategory(key: String) -> String {
    if let match = (expenseCategories + incomeCategories + feeCategories).first(where: { $0.key == key }) {
        return match.systemImage
    }
    if let legacy = legacyExpenseIconMap[key] {
        return legacy
    }
    return "tag"
}

private func sharedExpenseNameKey(for category: ExpenseCategory) -> String {
    switch category {
    case .food: return L.categoryFood
    case .transport: return L.categoryTransport
    case .accommodation: return L.categoryAccommodation
    case .entertainment: return L.categoryEntertainment
    case .utilities: return L.categoryUtilities
    case .selfImprovement: return L.categorySelfImprovement
    case .school: return L.categorySchool
    case .medical: return L.categoryMedical
    case .clothing: return L.categoryClothing
    case .investment: return L.categoryInvestment
    case .social: return L.categorySocial
    case .other: return L.categoryOther
    }
}

private func sharedExpenseIcon(for category: ExpenseCategory) -> String {
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

private let legacyExpenseIconMap: [String: String] = [
    "shopping": "bag.fill",
    "housing": "house.fill",
    "health": "cross.case.fill",
    "education": "book.fill",
    "fees": "creditcard",
    "travel": "airplane",
    "utilities": "bolt.fill",
    "entertainment": "gamecontroller.fill"
]
