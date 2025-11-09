//
//  PersonalCategorySeeds.swift
//  KuaiJi
//
//  Defines the built-in category metadata used for seeding personal ledger categories.
//

import Foundation

struct PersonalCategorySeed: Hashable, Sendable {
    let key: String
    let localizationKey: String
    let systemImage: String
    let kind: PersonalTransactionKind
    let colorHex: String?

    var displayName: String { localizationKey.localized }
}

enum PersonalCategorySeedCatalog {
    static let expense: [PersonalCategorySeed] = ExpenseCategory.allCases.map { category in
        PersonalCategorySeed(key: category.rawValue,
                             localizationKey: sharedExpenseNameKey(for: category),
                             systemImage: sharedExpenseIcon(for: category),
                             kind: .expense,
                             colorHex: nil)
    }

    static let income: [PersonalCategorySeed] = [
        PersonalCategorySeed(key: "salary", localizationKey: "personal.category.salary", systemImage: "banknote", kind: .income, colorHex: nil),
        PersonalCategorySeed(key: "bonus", localizationKey: "personal.category.bonus", systemImage: "gift.fill", kind: .income, colorHex: nil),
        PersonalCategorySeed(key: "investment", localizationKey: "personal.category.investment", systemImage: "chart.line.uptrend.xyaxis", kind: .income, colorHex: nil),
        PersonalCategorySeed(key: "sideHustle", localizationKey: "personal.category.sideHustle", systemImage: "briefcase.fill", kind: .income, colorHex: nil),
        PersonalCategorySeed(key: "giftIncome", localizationKey: "personal.category.giftIncome", systemImage: "sparkles", kind: .income, colorHex: nil),
        PersonalCategorySeed(key: "refund", localizationKey: "personal.category.refund", systemImage: "arrow.uturn.backward", kind: .income, colorHex: nil),
        PersonalCategorySeed(key: "otherIncome", localizationKey: "personal.category.otherIncome", systemImage: "square.grid.2x2", kind: .income, colorHex: nil)
    ]

    static let fee: [PersonalCategorySeed] = [
        PersonalCategorySeed(key: "fees", localizationKey: "personal.category.fees", systemImage: "creditcard", kind: .fee, colorHex: nil)
    ]

    static var all: [PersonalCategorySeed] {
        expense + income + fee
    }

    static func defaultKey(for kind: PersonalTransactionKind) -> String {
        switch kind {
        case .expense:
            return expense.first?.key ?? ExpenseCategory.food.rawValue
        case .income:
            return income.first?.key ?? "salary"
        case .fee:
            return fee.first?.key ?? "fees"
        }
    }

    static func isSystemExpenseKey(_ key: String) -> Bool {
        expense.contains { $0.key == key }
    }
}

func iconForCategory(key: String) -> String {
    if let seed = PersonalCategorySeedCatalog.all.first(where: { $0.key == key }) {
        return seed.systemImage
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
