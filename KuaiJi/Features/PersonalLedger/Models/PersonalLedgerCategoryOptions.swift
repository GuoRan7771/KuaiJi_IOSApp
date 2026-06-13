//
//  PersonalLedgerCategories.swift
//  KuaiJi
//
//  Provides category metadata used by the personal ledger module.
//

import Foundation
import SwiftUI

struct PersonalCategoryOption: Identifiable, Hashable, Sendable {
    enum Group: Sendable {
        case expense
        case income
        case neutral
    }

    var id: String { key }
    let key: String
    let nameKey: String?
    let customName: String?
    let systemImage: String
    let group: Group
    let color: Color
    let mappedSystemCategory: ExpenseCategory?
    let isCustom: Bool

    var localizedName: String {
        if let name = customName { return name }
        return nameKey?.localized ?? key.capitalized
    }

    static func defaultCategories(for kind: PersonalTransactionKind) -> [PersonalCategoryOption] {
        switch kind {
        case .expense: return systemExpenseCategories
        case .income: return systemIncomeCategories
        case .fee: return feeCategories
        }
    }

    static let commonExpenseKeys: [String] = ExpenseCategory.allCases.map { $0.rawValue }
    static let commonIncomeKeys: [String] = ["salary", "bonus", "investment", "sideHustle", "giftIncome", "refund", "otherIncome"]

    init(key: String,
         nameKey: String,
         systemImage: String,
         group: Group,
         color: Color,
         mappedSystemCategory: ExpenseCategory? = nil,
         isCustom: Bool = false) {
        self.key = key
        self.nameKey = nameKey
        self.customName = nil
        self.systemImage = systemImage
        self.group = group
        self.color = color
        self.mappedSystemCategory = mappedSystemCategory
        self.isCustom = isCustom
    }

    init(customKey: String,
         name: String,
         systemImage: String,
         group: Group,
         color: Color,
         mappedSystemCategory: ExpenseCategory?) {
        self.key = customKey
        self.nameKey = nil
        self.customName = name
        self.systemImage = systemImage
        self.group = group
        self.color = color
        self.mappedSystemCategory = mappedSystemCategory
        self.isCustom = true
    }
}

private let systemCategoryColorHex: [String: String] = [
    // Expenses
    "food": "FF7F50",
    "transport": "4C9CFF",
    "accommodation": "A86BFF",
    "entertainment": "FFB347",
    "utilities": "4FB286",
    "selfImprovement": "FF6FAF",
    "school": "6EC6A6",
    "medical": "FF6B6B",
    "clothing": "8E9CFF",
    "investment": "4DD0E1",
    "social": "F0C419",
    "other": "8D8D93",
    // Income
    "salary": "36CFC9",
    "bonus": "FF9F59",
    "investmentIncome": "6AA9FF",
    "sideHustle": "B072F4",
    "giftIncome": "F06292",
    "refund": "7BC6F6",
    "otherIncome": "94A3B8",
    // Neutral / fees
    "fees": "A05A2C"
]

private func systemCategoryColor(for key: String) -> Color {
    if let hex = systemCategoryColorHex[key], let color = Color(hex: hex) {
        return color
    }
    return Color.appBrand
}

let systemExpenseCategories: [PersonalCategoryOption] = ExpenseCategory.allCases.map { category in
    PersonalCategoryOption(key: category.rawValue,
                           nameKey: sharedExpenseNameKey(for: category),
                           systemImage: sharedExpenseIcon(for: category),
                           group: .expense,
                           color: systemCategoryColor(for: category.rawValue))
}

let systemIncomeCategories: [PersonalCategoryOption] = [
    PersonalCategoryOption(key: "salary", nameKey: "personal.category.salary", systemImage: "banknote", group: .income, color: systemCategoryColor(for: "salary")),
    PersonalCategoryOption(key: "bonus", nameKey: "personal.category.bonus", systemImage: "gift.fill", group: .income, color: systemCategoryColor(for: "bonus")),
    PersonalCategoryOption(key: "investment", nameKey: "personal.category.investment", systemImage: "chart.line.uptrend.xyaxis", group: .income, color: systemCategoryColor(for: "investmentIncome")),
    PersonalCategoryOption(key: "sideHustle", nameKey: "personal.category.sideHustle", systemImage: "briefcase.fill", group: .income, color: systemCategoryColor(for: "sideHustle")),
    PersonalCategoryOption(key: "giftIncome", nameKey: "personal.category.giftIncome", systemImage: "sparkles", group: .income, color: systemCategoryColor(for: "giftIncome")),
    PersonalCategoryOption(key: "refund", nameKey: "personal.category.refund", systemImage: "arrow.uturn.backward", group: .income, color: systemCategoryColor(for: "refund")),
    PersonalCategoryOption(key: "otherIncome", nameKey: "personal.category.otherIncome", systemImage: "square.grid.2x2", group: .income, color: systemCategoryColor(for: "otherIncome"))
]

let feeCategories: [PersonalCategoryOption] = [
    PersonalCategoryOption(key: "fees", nameKey: "personal.category.fees", systemImage: "creditcard", group: .neutral, color: systemCategoryColor(for: "fees"))
]

// Backward compatibility aliases
let expenseCategories = systemExpenseCategories
let incomeCategories = systemIncomeCategories

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

let legacyExpenseIconMap: [String: String] = [
    "shopping": "bag.fill",
    "housing": "house.fill",
    "health": "cross.case.fill",
    "education": "book.fill",
    "fees": "creditcard",
    "travel": "airplane",
    "utilities": "bolt.fill",
    "entertainment": "gamecontroller.fill"
]

let personalCategoryFallbackPalette: [Color] = [
    Color(red: 0.46, green: 0.33, blue: 0.93),
    Color(red: 0.99, green: 0.53, blue: 0.31),
    Color(red: 0.16, green: 0.68, blue: 0.93),
    Color(red: 0.19, green: 0.74, blue: 0.52),
    Color(red: 0.98, green: 0.46, blue: 0.71),
    Color(red: 0.96, green: 0.77, blue: 0.36),
    Color(red: 0.38, green: 0.69, blue: 0.98),
    Color(red: 0.57, green: 0.39, blue: 0.93),
    Color(red: 0.98, green: 0.65, blue: 0.33),
    Color(red: 0.24, green: 0.60, blue: 0.99)
]

func hashedCategoryColor(for key: String) -> Color {
    let hash = key.unicodeScalars.reduce(into: UInt64(0)) { partial, scalar in
        partial = partial &* 31 &+ UInt64(scalar.value)
    }
    let index = Int(hash % UInt64(personalCategoryFallbackPalette.count))
    return personalCategoryFallbackPalette[index]
}
