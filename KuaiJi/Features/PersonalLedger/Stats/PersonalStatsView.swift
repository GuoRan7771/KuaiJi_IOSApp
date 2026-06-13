//
//  PersonalStatsView.swift
//  KuaiJi
//

import Charts
import SwiftUI

struct PersonalStatsView: View {
    @ObservedObject var viewModel: PersonalStatsViewModel
    @State private var focus: Focus = .expense
    @State private var showingObservationHelp = false

    enum Focus: String, CaseIterable, Identifiable {
        case expense
        case income

        var id: String { rawValue }

        var localizedTitle: String {
            switch self {
            case .expense: return L.personalStatsFocusExpense.localized
            case .income: return L.personalStatsFocusIncome.localized
            }
        }

        var accentColor: Color {
            switch self {
            case .expense: return Color(red: 0.45, green: 0.33, blue: 0.93)
            case .income: return Color(red: 0.20, green: 0.62, blue: 0.46)
            }
        }

        var secondaryColor: Color {
            switch self {
            case .expense: return Color(red: 0.97, green: 0.44, blue: 0.51)
            case .income: return Color(red: 0.37, green: 0.77, blue: 0.55)
            }
        }
    }

    private var filteredBreakdown: [PersonalStatsCategoryShare] {
        let data = focus == .expense ? viewModel.expenseBreakdown : viewModel.incomeBreakdown
        return data.filter { $0.amountMinorUnits > 0 }
    }

    private var totalForFocus: Int {
               filteredBreakdown.reduce(0) { $0 + $1.amountMinorUnits }
    }

    private var totalExpense: Int {
        viewModel.timeline.reduce(0) { $0 + $1.expenseMinorUnits }
    }

    private var totalIncome: Int {
        viewModel.timeline.reduce(0) { $0 + $1.incomeMinorUnits }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                statsSummaryCard
                observationCard
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color.appBackground)
        .navigationTitle(L.personalStatsTitle.localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { currencyToolbar }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L.personalStatsTitle.localized)
                    .font(.largeTitle.weight(.bold))
            }

            HStack(spacing: 12) {
                headerControlButton(systemImage: "chevron.left") {
                    shiftAnchor(by: -1)
                }
                Text(formattedPeriodLabel)
                    .font(.title3.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                headerControlButton(systemImage: "chevron.right") {
                    shiftAnchor(by: 1)
                }
            }

            Picker(L.personalStatsPeriod.localized, selection: $viewModel.period) {
                ForEach(PersonalStatsViewModel.Period.allCases) { period in
                    Text(period.displayName).tag(period)
                }
            }
            .pickerStyle(.segmented)

            if focus == .expense {
                Toggle(L.personalStatsIncludeFee.localized, isOn: $viewModel.includeFees)
                    .toggleStyle(.switch)
                    .tint(Color.appToggleOn)
            }
        }
    }

    private var statsSummaryCard: some View {
        statsContainer {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .center, spacing: 16) {
                    Picker("", selection: $focus) {
                        ForEach(Focus.allCases) { scope in
                            Text(scope.localizedTitle).tag(scope)
                        }
                    }
                    .pickerStyle(.segmented)

                    Spacer(minLength: 16)

                    Text(viewModel.selectedCurrency.rawValue)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.appSurfaceAlt)
                        )
                }

                VStack(spacing: 0) {
                    donutView()
                        .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 12)

                Divider()

                if filteredBreakdown.isEmpty {
                    Text(L.personalStatsEmpty.localized)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredBreakdown) { item in
                            NavigationLink {
                                PersonalStatsCategoryRecordsView(viewModel: viewModel.makeCategoryRecordsViewModel(for: item.categoryKey,
                                                                                                                  focus: focus.categoryFocus))
                            } label: {
                                categoryRow(for: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                    
                    Text(L.personalStatsCategoryClickHint.localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 16)
                }
            }
        }
    }

    private var currencyToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                ForEach(viewModel.availableCurrencies, id: \.self) { code in
                    Button(action: { viewModel.selectedCurrency = code }) {
                        if viewModel.selectedCurrency == code {
                            Label(code.displayLabel, systemImage: "checkmark")
                        } else {
                            Text(code.displayLabel)
                        }
                    }
                }
            } label: {
                Label(viewModel.selectedCurrency.displayLabel, systemImage: "coloncurrencysign.circle")
            }
        }
    }

    private func shiftAnchor(by step: Int) {
        let calendar = Calendar.current
        let component: Calendar.Component
        let value: Int
        switch viewModel.period {
        case .month:
            component = .month
            value = step
        case .quarter:
            component = .month
            value = step * 3
        case .year:
            component = .year
            value = step
        }
        if let newDate = calendar.date(byAdding: component, value: value, to: viewModel.anchorDate) {
            viewModel.anchorDate = newDate
        }
    }

    private var formattedPeriodLabel: String {
        switch viewModel.period {
        case .month:
            return Self.monthHeaderFormatter.string(from: viewModel.anchorDate)
        case .quarter:
            return Self.quarterHeaderFormatter.string(from: viewModel.anchorDate)
        case .year:
            return Self.yearHeaderFormatter.string(from: viewModel.anchorDate)
        }
    }

    private func headerControlButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 40, height: 40)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.appSurface)
                .shadow(color: Color.appCardShadow, radius: 6, x: 0, y: 4)
        )
    }

    private func statsContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 20, content: content)
            .padding(.vertical, 22)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.appSurfaceAlt)
            )
            .shadow(color: Color.appCardShadow, radius: 18, x: 0, y: 12)
    }

    private func donutView() -> some View {
        ZStack {
            if filteredBreakdown.isEmpty {
                Circle()
                    .fill(Color.appSurfaceAlt)
                    .frame(width: 180, height: 180)
                VStack(spacing: 6) {
                    Text(focus.localizedTitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(formattedAmount(0, currency: viewModel.selectedCurrency))
                        .font(.headline)
                }
            } else {
                Chart(filteredBreakdown) { item in
                    SectorMark(angle: .value("Amount", Double(item.amountMinorUnits)),
                               innerRadius: .ratio(0.62),
                               angularInset: 1)
                        .foregroundStyle(viewModel.categoryColor(for: item.categoryKey))
                }
                .chartLegend(.hidden)
                .frame(width: 200, height: 200)

                VStack(spacing: 6) {
                    Text(focus.localizedTitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(formattedAmount(totalForFocus, currency: viewModel.selectedCurrency))
                        .font(.headline.weight(.semibold))
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func growthView(title: String,
                            metrics: PersonalStatsGrowthMetrics,
                            currentPeriodLabel: String,
                            previousPeriodLabel: String,
                            upColor: Color,
                            downColor: Color) -> some View {
        let isIncrease = metrics.delta >= 0
        let arrow = isIncrease ? "arrow.up.right" : "arrow.down.right"
        let tint = isIncrease ? upColor : downColor
        let direction = isIncrease ? L.personalStatsGrowthUp.localized : L.personalStatsGrowthDown.localized
        let amountText = formattedAmount(abs(metrics.delta), currency: viewModel.selectedCurrency)
        let rateText = formatPercent(metrics.rate)
        let detail = L.personalStatsGrowthDetailFull.localized(currentPeriodLabel, previousPeriodLabel, direction, amountText)
        
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 2) {
                    Text(rateText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                    Image(systemName: arrow)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(tint)
                }
            }
            
            Text(detail)
                .font(.caption)
                .foregroundStyle(Color.appTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func categoryRow(for item: PersonalStatsCategoryShare) -> some View {
        let color = viewModel.categoryColor(for: item.categoryKey)
        let share = totalForFocus > 0 ? Double(item.amountMinorUnits) / Double(totalForFocus) : 0
        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 46, height: 46)
                Image(systemName: viewModel.categoryIcon(for: item.categoryKey))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.categoryName(for: item.categoryKey))
                    .font(.headline)
                Text(L.personalStatsRecordCount.localized(item.transactionCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatPercent(share))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(formattedAmount(item.amountMinorUnits, currency: viewModel.selectedCurrency))
                    .font(.callout.weight(.semibold))
            }
        }
        .padding(.vertical, 8)
    }

    private func formattedAmount(_ amount: Int, currency: CurrencyCode) -> String {
        AmountFormatter.string(minorUnits: amount, currency: currency, locale: Locale.current)
    }

    private func periodLabel(for anchorDate: Date, period: PersonalStatsViewModel.Period) -> String {
        switch period {
        case .month:
            return Self.monthHeaderFormatter.string(from: anchorDate)
        case .quarter:
            return Self.quarterHeaderFormatter.string(from: anchorDate)
        case .year:
            return Self.yearHeaderFormatter.string(from: anchorDate)
        }
    }

    private static let monthHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter
    }()

    private static let quarterHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "QQQ y"
        return formatter
    }()

    private static let yearHeaderFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("y")
        return formatter
    }()

    private var observationCard: some View {
        let savings = totalIncome - totalExpense
        let savingsRate = totalIncome > 0 ? Double(savings) / Double(totalIncome) : 0
        let expenseRate = totalIncome > 0 ? Double(totalExpense) / Double(totalIncome) : 0
        
        let currentPeriodLabel = periodLabel(for: viewModel.anchorDate, period: viewModel.period)
        let previousPeriodLabel = periodLabel(for: PersonalStatsViewModel.previousRange(for: viewModel.period,
                                                                                        anchorDate: viewModel.anchorDate).lowerBound,
                                              period: viewModel.period)
        
        return statsContainer {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label(L.personalStatsObservationTitle.localized, systemImage: "eye")
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            showingObservationHelp.toggle()
                        }
                    } label: {
                        Image(systemName: showingObservationHelp ? "questionmark.circle.fill" : "questionmark.circle")
                            .font(.subheadline)
                            .foregroundStyle(showingObservationHelp ? Color.appTextPrimary : Color.secondary)
                    }
                    .overlay(alignment: .topTrailing) {
                        if showingObservationHelp {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(L.personalStatsObservationHelpTitle.localized)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.appTextPrimary)
                                
                                Text(L.personalStatsObservationHelpMessage.localized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(12)
                            .frame(width: 260, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.appSurface)
                                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                            )
                            .offset(x: 0, y: 30)
                            .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .topTrailing)))
                        }
                    }
                }
                .zIndex(1)
                
                Divider()
                
                HStack(spacing: 16) {
                    observationItem(title: L.personalStatsObservationSavings.localized,
                                    value: formattedAmount(savings, currency: viewModel.selectedCurrency),
                                    color: Color.appSuccess)
                    
                    observationItem(title: L.personalStatsObservationSavingsRate.localized,
                                    value: formatPercent(savingsRate),
                                    color: Color.appSelection)
                    
                    observationItem(title: L.personalStatsObservationExpenseRate.localized,
                                    value: formatPercent(expenseRate),
                                    color: Color.appDanger)
                }
                
                if let expenseGrowth = viewModel.expenseGrowth {
                    Divider()
                    growthView(title: L.personalStatsExpenseGrowth.localized,
                               metrics: expenseGrowth,
                               currentPeriodLabel: currentPeriodLabel,
                               previousPeriodLabel: previousPeriodLabel,
                               upColor: Color.appDanger,
                               downColor: Color.appSuccess)
                }
                
                if let incomeGrowth = viewModel.incomeGrowth {
                    Divider()
                    growthView(title: L.personalStatsIncomeGrowth.localized,
                               metrics: incomeGrowth,
                               currentPeriodLabel: currentPeriodLabel,
                               previousPeriodLabel: previousPeriodLabel,
                               upColor: Color.appSuccess,
                               downColor: Color.appDanger)
                }
            }
        }
    }
    
    private func observationItem(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension PersonalStatsView.Focus {
    var categoryFocus: PersonalStatsCategoryFocus {
        switch self {
        case .expense: return .expense
        case .income: return .income
        }
    }
}

struct PersonalStatsCategoryRecordsView: View {
    @StateObject private var viewModel: PersonalStatsCategoryRecordsViewModel

    init(viewModel: PersonalStatsCategoryRecordsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            Section(header: headerView) {
                if viewModel.records.isEmpty {
                    Text(L.personalStatsEmpty.localized)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 12)
                } else {
                    ForEach(viewModel.records) { record in
                        PersonalStatsRecordRow(record: record)
                            .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                            .listRowBackground(Color.appBackground)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(viewModel.categoryName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.refresh() }
        .alert(viewModel.lastError ?? "", isPresented: Binding(get: { viewModel.lastError != nil }, set: { _ in viewModel.lastError = nil })) {
            Button(L.ok.localized, action: {})
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(periodLabel)
                .font(.headline)
            HStack(spacing: 8) {
                Text(viewModel.selectedCurrency.displayLabel)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.appSurfaceAlt))
                Text(L.personalStatsRecordCount.localized(viewModel.records.count))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var periodLabel: String {
        switch viewModel.period {
        case .month:
            return Self.monthFormatter.string(from: viewModel.anchorDate)
        case .quarter:
            return Self.quarterFormatter.string(from: viewModel.anchorDate)
        case .year:
            return Self.yearFormatter.string(from: viewModel.anchorDate)
        }
    }

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter
    }()

    private static let quarterFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.dateFormat = "QQQ y"
        return formatter
    }()

    private static let yearFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("y")
        return formatter
    }()
}

private struct PersonalStatsRecordRow: View {
    var record: PersonalRecordRowViewData

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.systemImage)
                .font(.title3)
                .foregroundStyle(record.categoryColorHex.flatMap { Color(hex: $0) } ?? Color.appBrand)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.categoryName)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                if !record.note.isEmpty {
                    Text(record.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(record.accountName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(amountString)
                    .foregroundStyle(record.amountIsPositive ? Color.appSuccess : Color.appDanger)
                Text(record.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.appSecondaryText)
            }
        }
    }

    private var amountString: String {
        AmountFormatter.string(minorUnits: record.amountMinorUnits,
                              currency: record.currency,
                              locale: Locale.current)
    }
}
