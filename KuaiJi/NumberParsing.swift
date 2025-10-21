//
//  NumberParsing.swift
//  KuaiJi
//
//  Locale-aware helpers for parsing and validating decimal numbers.
//

import Foundation

enum NumberParsing {
    static func decimalSeparator(for locale: Locale = .current) -> String {
        locale.decimalSeparator ?? "."
    }

    static func groupingSeparator(for locale: Locale = .current) -> String {
        locale.groupingSeparator ?? ","
    }

    /// Parse a decimal string using the provided locale (defaults to current).
    /// - Important: Removes grouping separators before parsing.
    static func parseDecimal(_ string: String, locale: Locale = .current) -> Decimal? {
        let clean = string.replacingOccurrences(of: groupingSeparator(for: locale), with: "")
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = locale
        if let number = formatter.number(from: clean) {
            return number.decimalValue
        }
        return nil
    }

    /// Validate and normalize user input for decimal numbers with a max number of fraction digits.
    /// Preserves the locale-specific decimal separator and strips grouping separators.
    static func validateDecimalInput(_ input: String, maxDecimalPlaces: Int, locale: Locale = .current, oldValue: String) -> String {
        if input.isEmpty { return input }
        let separator = decimalSeparator(for: locale)
        let cleanInput = input.replacingOccurrences(of: groupingSeparator(for: locale), with: "")

        let components = cleanInput.split(separator: Character(separator), omittingEmptySubsequences: false)
        if components.count > 2 { return oldValue }

        if components.count == 2 {
            let decimalPart = String(components[1])
            if decimalPart.count > maxDecimalPlaces {
                return "\(components[0])\(separator)\(decimalPart.prefix(maxDecimalPlaces))"
            }
        }

        if cleanInput.last?.description == separator {
            let prefix = String(cleanInput.dropLast())
            if prefix.isEmpty || parseDecimal(prefix, locale: locale) != nil {
                return cleanInput
            }
        }

        guard parseDecimal(cleanInput, locale: locale) != nil else { return oldValue }
        return cleanInput
    }
}


