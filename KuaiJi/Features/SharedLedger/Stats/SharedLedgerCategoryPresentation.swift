//
//  SharedLedgerCategoryPresentation.swift
//  KuaiJi
//
//  Display labels for shared ledger categories.
//

import Foundation

extension ExpenseCategory {
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
