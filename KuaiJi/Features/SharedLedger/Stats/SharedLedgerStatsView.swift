//
//  SharedLedgerStatsView.swift
//  KuaiJi
//
//  Shared ledger statistics views and view model.
//

import SwiftUI
import Charts

struct SharedLedgerStatsCategoryShare: Identifiable, Hashable {
    var id: UUID = UUID()
    var category: ExpenseCategory
    var amountMinorUnits: Int
    var transactionCount: Int
}

@MainActor
class SharedLedgerStatsViewModel: ObservableObject {
    @Published var breakdown: [SharedLedgerStatsCategoryShare] = []
    @Published var totalAmount: Int = 0
    
    let ledgerId: UUID
    let ledgerName: String
    let currency: CurrencyCode
    private let records: [LedgerRecordViewData]
    
    init(ledgerId: UUID, ledgerName: String, currency: CurrencyCode, records: [LedgerRecordViewData]) {
        self.ledgerId = ledgerId
        self.ledgerName = ledgerName
        self.currency = currency
        self.records = records
        computeStats()
    }
    
    private func computeStats() {
        var categoryMap: [ExpenseCategory: (amount: Int, count: Int)] = [:]
        var total = 0
        
        for record in records {
            categoryMap[record.category, default: (0, 0)].amount += record.amountMinorUnits
            categoryMap[record.category, default: (0, 0)].count += 1
            total += record.amountMinorUnits
        }
        
        self.totalAmount = total
        self.breakdown = categoryMap.map { category, data in
            SharedLedgerStatsCategoryShare(category: category, amountMinorUnits: data.amount, transactionCount: data.count)
        }.sorted { $0.amountMinorUnits > $1.amountMinorUnits }
    }
    
    func categoryColor(for category: ExpenseCategory) -> Color {
        SharedLedgerStatsHelpers.color(for: category)
    }
    
    func categoryIcon(for category: ExpenseCategory) -> String {
        SharedLedgerStatsHelpers.icon(for: category)
    }
    
    func categoryName(for category: ExpenseCategory) -> String {
        SharedLedgerStatsHelpers.name(for: category)
    }
    
    func records(for category: ExpenseCategory) -> [LedgerRecordViewData] {
        records.filter { $0.category == category }.sorted { $0.date > $1.date }
    }
}

struct SharedLedgerCategoryRecordsView: View {
    let category: ExpenseCategory
    let records: [LedgerRecordViewData]
    let currency: CurrencyCode
    
    var body: some View {
        List {
            if records.isEmpty {
                ContentUnavailableView(L.recordsEmpty.localized,
                                     systemImage: "doc.text",
                                     description: Text(L.recordsEmptyDesc.localized))
            } else {
                ForEach(records) { record in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.title)
                                    .font(.headline)
                                Text("\(record.payerName) · \(record.splitModeDisplay)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(record.amountDisplay)
                                    .font(.headline)
                                    .foregroundStyle(Color.appSelection)
                                Text(record.date, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(SharedLedgerStatsHelpers.name(for: category))
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SharedLedgerStatsView: View {
    @StateObject var viewModel: SharedLedgerStatsViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                donutView()
                    .padding(.top, 20)
                
                if viewModel.breakdown.isEmpty {
                    Text(L.personalStatsEmpty.localized)
                        .foregroundStyle(.secondary)
                        .padding()
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.breakdown) { item in
                            NavigationLink {
                                SharedLedgerCategoryRecordsView(category: item.category,
                                                              records: viewModel.records(for: item.category),
                                                              currency: viewModel.currency)
                            } label: {
                                categoryRow(for: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color.appBackground)
        .navigationTitle(L.ledgerStatsTitle.localized(viewModel.ledgerName))
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func donutView() -> some View {
        ZStack {
            if viewModel.breakdown.isEmpty {
                Circle()
                    .stroke(Color.appSurfaceAlt, lineWidth: 20)
                    .frame(width: 180, height: 180)
                Text(formattedAmount(0))
                    .font(.headline)
            } else {
                Chart(viewModel.breakdown) { item in
                    SectorMark(angle: .value("Amount", Double(item.amountMinorUnits)),
                               innerRadius: .ratio(0.6),
                               angularInset: 1)
                        .foregroundStyle(viewModel.categoryColor(for: item.category))
                }
                .frame(width: 220, height: 220)
                
                VStack(spacing: 4) {
                    Text(L.ledgerTotalSpent.localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formattedAmount(viewModel.totalAmount))
                        .font(.headline)
                }
            }
        }
    }
    
    private func categoryRow(for item: SharedLedgerStatsCategoryShare) -> some View {
        let color = viewModel.categoryColor(for: item.category)
        let percentage = viewModel.totalAmount > 0 ? Double(item.amountMinorUnits) / Double(viewModel.totalAmount) : 0
        
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: viewModel.categoryIcon(for: item.category))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.categoryName(for: item.category))
                    .font(.body.weight(.medium))
                Text(L.personalStatsRecordCount.localized(item.transactionCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedAmount(item.amountMinorUnits))
                    .font(.callout.weight(.medium))
                Text(percentage.formatted(.percent.precision(.fractionLength(1))))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color.appSurface)
        .cornerRadius(12)
    }
    
    private func formattedAmount(_ minorUnits: Int) -> String {
        AmountFormatter.string(minorUnits: minorUnits, currency: viewModel.currency, locale: Locale.current)
    }
}

enum SharedLedgerStatsHelpers {
    static func color(for category: ExpenseCategory) -> Color {
        let hex: String
        switch category {
        case .food: hex = "FF7F50"
        case .transport: hex = "4C9CFF"
        case .accommodation: hex = "A86BFF"
        case .entertainment: hex = "FFB347"
        case .utilities: hex = "4FB286"
        case .selfImprovement: hex = "FF6FAF"
        case .school: hex = "6EC6A6"
        case .medical: hex = "FF6B6B"
        case .clothing: hex = "8E9CFF"
        case .investment: hex = "4DD0E1"
        case .social: hex = "F0C419"
        case .other: hex = "8D8D93"
        }
        return Color(hex: hex) ?? .gray
    }
    
    static func icon(for category: ExpenseCategory) -> String {
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
    
    static func name(for category: ExpenseCategory) -> String {
        switch category {
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
