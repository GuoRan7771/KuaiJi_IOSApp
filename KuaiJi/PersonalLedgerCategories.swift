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

    static let commonExpenseKeys: [String] = ["food", "transport", "shopping", "housing", "entertainment", "utilities", "health", "education", "fees", "other"]
    static let commonIncomeKeys: [String] = ["salary", "bonus", "investment", "gift", "otherIncome"]
}

let expenseCategories: [PersonalCategoryOption] = [
    PersonalCategoryOption(key: "food", nameKey: "personal.category.food", systemImage: "fork.knife", group: .expense),
    PersonalCategoryOption(key: "transport", nameKey: "personal.category.transport", systemImage: "car.fill", group: .expense),
    PersonalCategoryOption(key: "shopping", nameKey: "personal.category.shopping", systemImage: "bag.fill", group: .expense),
    PersonalCategoryOption(key: "housing", nameKey: "personal.category.housing", systemImage: "house.fill", group: .expense),
    PersonalCategoryOption(key: "utilities", nameKey: "personal.category.utilities", systemImage: "bolt.fill", group: .expense),
    PersonalCategoryOption(key: "entertainment", nameKey: "personal.category.entertainment", systemImage: "gamecontroller.fill", group: .expense),
    PersonalCategoryOption(key: "health", nameKey: "personal.category.health", systemImage: "cross.case.fill", group: .expense),
    PersonalCategoryOption(key: "education", nameKey: "personal.category.education", systemImage: "book.fill", group: .expense),
    PersonalCategoryOption(key: "fees", nameKey: "personal.category.fees", systemImage: "creditcard", group: .expense),
    PersonalCategoryOption(key: "travel", nameKey: "personal.category.travel", systemImage: "airplane", group: .expense),
    PersonalCategoryOption(key: "other", nameKey: "personal.category.other", systemImage: "square.grid.2x2", group: .expense)
]

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
    return "tag"
}
