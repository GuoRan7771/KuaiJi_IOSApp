//
//  PersonalLedgerSettingsViewModel.swift
//  KuaiJi
//

import Combine
import Foundation
import SwiftData
import SwiftUI

@MainActor
final class PersonalLedgerSettingsViewModel: ObservableObject {
    @Published var primaryCurrency: CurrencyCode
    @Published var defaultFXPrecision: Int
    @Published var defaultFXRateText: String
    @Published var defaultFeeText: String
    @Published var countFeeInStats: Bool
    @Published var feeCategoryKey: String
    @Published var fxRates: [CurrencyCode: String]
    @Published var lastError: String?

    private let store: PersonalLedgerStore

    init(store: PersonalLedgerStore) {
        self.store = store
        let prefs = store.getPreferences()
        primaryCurrency = prefs.primaryDisplayCurrency
        defaultFXPrecision = prefs.defaultFXPrecision
        defaultFXRateText = ""
        defaultFeeText = ""
        countFeeInStats = prefs.countFeeInStats
        feeCategoryKey = prefs.defaultFeeCategoryKey ?? "fees"
        fxRates = [:]
        applyPreferences(prefs)
    }

    func save() async {
        do {
            let trimmedRate = defaultFXRateText.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedFee = defaultFeeText.trimmingCharacters(in: .whitespacesAndNewlines)
            let defaultRate = NumberParsing.parseDecimal(trimmedRate)
            var normalizedDefaultFee = NumberParsing.parseDecimal(trimmedFee) ?? 0
            if normalizedDefaultFee < 0 {
                normalizedDefaultFee = 0
            }
            var parsedRates: [CurrencyCode: Decimal] = [:]
            for (code, text) in fxRates {
                if let value = NumberParsing.parseDecimal(text), value > 0 {
                    parsedRates[code] = value
                }
            }
            try store.updatePreferences { prefs in
                prefs.primaryDisplayCurrency = primaryCurrency
                prefs.fxSource = .manual
                prefs.defaultFXPrecision = defaultFXPrecision
                prefs.countFeeInStats = countFeeInStats
                prefs.defaultFeeCategoryKey = feeCategoryKey
                prefs.defaultFXRate = defaultRate
                prefs.defaultConversionFee = normalizedDefaultFee
                prefs.fxRates = parsedRates
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func reloadFromStore() {
        applyPreferences(store.getPreferences())
    }

    private func applyPreferences(_ prefs: PersonalPreferences) {
        primaryCurrency = prefs.primaryDisplayCurrency
        defaultFXPrecision = prefs.defaultFXPrecision
        if let rate = prefs.defaultFXRate {
            defaultFXRateText = NSDecimalNumber(decimal: rate).stringValue
        } else {
            defaultFXRateText = ""
        }
        if let defaultFee = prefs.defaultConversionFee, defaultFee != 0 {
            defaultFeeText = NSDecimalNumber(decimal: defaultFee).stringValue
        } else {
            defaultFeeText = ""
        }
        countFeeInStats = prefs.countFeeInStats
        feeCategoryKey = prefs.defaultFeeCategoryKey ?? "fees"
        fxRates = Dictionary(uniqueKeysWithValues: prefs.fxRates.map { ($0.key, NSDecimalNumber(decimal: $0.value).stringValue) })
        if prefs.fxSource != .manual {
            do {
                try store.updatePreferences { preferences in
                    preferences.fxSource = .manual
                }
            } catch {
                lastError = error.localizedDescription
            }
        }
    }
}
