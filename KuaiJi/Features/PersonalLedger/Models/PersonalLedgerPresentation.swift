//
//  PersonalLedgerPresentation.swift
//  KuaiJi
//

import SwiftUI

extension PersonalFXSource {
    var displayName: String {
        switch self {
        case .manual: return L.personalFXSourceManual.localized
        case .fixed: return L.personalFXSourceFixed.localized
        }
    }
}
extension PersonalStatsViewModel.Period {
    var displayName: String {
        switch self {
        case .month: return L.personalStatsMonth.localized
        case .quarter: return L.personalStatsQuarter.localized
        case .year: return L.personalStatsYear.localized
        }
    }
}

// MARK: - Helpers for Stats UI

private func formatCurrency(_ minor: Int) -> String {
    let amount = Double(minor) / 100.0
    let f = NumberFormatter()
    f.numberStyle = .currency
    f.maximumFractionDigits = 2
    return f.string(from: NSNumber(value: amount)) ?? String(format: "%.2f", amount)
}

func formatPercent(_ v: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .percent
    f.maximumFractionDigits = 1
    return f.string(from: NSNumber(value: v)) ?? String(format: "%.1f%%", v * 100)
}

@MainActor
func localizedCategoryName(_ key: String, store: PersonalLedgerStore) -> String {
    store.categoryName(for: key)
}

struct DashedSeparator: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundStyle(Color.appSecondaryText.opacity(0.2))
        }
        .frame(height: 1)
    }
}

extension PersonalRecordRowViewData {
    var kindDisplay: String {
        switch entryNature {
        case .transaction(let kind):
            switch kind {
            case .income: return L.personalTypeIncome.localized
            case .expense: return L.personalTypeExpense.localized
            case .fee: return L.personalTypeFee.localized
            }
        case .transfer:
            return L.personalTransferTitle.localized
        }
    }
}

extension PersonalAccountRowViewData {
    var typeDisplay: String { type.displayName }
}

extension PersonalAccountType {
    var displayName: String {
        switch self {
        case .bankCard: return L.personalAccountTypeBank.localized
        case .mobilePayment: return L.personalAccountTypeMobile.localized
        case .cash: return L.personalAccountTypeCash.localized
        case .creditCard: return L.personalAccountTypeCredit.localized
        case .prepaid: return L.personalAccountTypePrepaid.localized
        case .other: return L.personalAccountTypeOther.localized
        }
    }
}

extension Binding where Value == String {
    init(_ source: Binding<String?>, replacingNilWith defaultValue: String) {
        self.init(get: { source.wrappedValue ?? defaultValue },
                  set: { source.wrappedValue = $0 })
    }
}
