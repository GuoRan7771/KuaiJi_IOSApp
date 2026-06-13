//
//  AmountFormatter.swift
//  KuaiJi
//

import Foundation

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
