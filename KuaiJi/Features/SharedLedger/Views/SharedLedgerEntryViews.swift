//
//  SharedLedgerEntryViews.swift
//  KuaiJi
//
//  Shared ledger expense, settlement, and member detail views.
//

import SwiftUI

struct ExpenseFormView<Model: ExpenseFormViewModelProtocol>: View {
    @ObservedObject var viewModel: Model
    @State private var showingOtherPayerSheet = false
    @State private var showingHelpPayPayerSheet = false
    @State private var showingBeneficiarySheet = false
    @State private var showingCategorySheet = false
    @State private var amountText: String = ""
    @FocusState private var isAmountFocused: Bool
    
    private var selectedHelpPayPayerName: String {
        guard let id = viewModel.selectedHelpPayPayerId else { return "" }
        return viewModel.selectableHelpPayPayers.first(where: { $0.id == id })?.name ?? ""
    }
    
    private var selectedBeneficiaryName: String {
        guard let id = viewModel.selectedBeneficiaryId else { return "" }
        return viewModel.selectableBeneficiaries.first(where: { $0.id == id })?.name ?? ""
    }

    var body: some View {
        Form {
            // 第一栏：支出金额
            Section {
                HStack(spacing: 8) {
                    Text(viewModel.currencyCode)
                        .foregroundStyle(.secondary)
                        .font(.title3)
                        .fontWeight(.medium)
                     TextField(placeholderText, text: $amountText)
                         .keyboardType(.decimalPad)
                         .multilineTextAlignment(.trailing)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .focused($isAmountFocused)
                        .onChange(of: amountText) { oldValue, newValue in
                            // 实时验证并限制只能输入2位小数
                            let validated = validateDecimalInput(newValue, maxDecimalPlaces: 2, oldValue: oldValue)
                            if validated != newValue {
                                amountText = validated
                            }
                            if let decimal = parseDecimal(from: validated) {
                                viewModel.draft.amount = decimal
                                viewModel.regeneratePreview()
                            }
                        }
                        .onChange(of: isAmountFocused) { oldValue, focused in
                            let separator = decimalSeparator
                            let zeroString = "0\(separator)00"
                            if focused && amountText == zeroString {
                                amountText = ""
                            } else if !focused && amountText.isEmpty {
                                amountText = zeroString
                            }
                        }
                        .onAppear {
                            let separator = decimalSeparator
                            if viewModel.draft.amount == 0 {
                                amountText = "0\(separator)00"
                            } else {
                                // 使用当前区域设置格式化金额
                                amountText = formatAmount(viewModel.draft.amount)
                            }
                        }
                }
                .padding(.vertical, 8)
            } header: {
                Text(L.expenseAmount.localized)
            } footer: {
                // 显示验证错误
                if let error = viewModel.validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(ExpenseSplitOption.allCases) { option in
                        VStack(alignment: .leading, spacing: 4) {
                            Button {
                                viewModel.selectSplitOption(option)
                                if option == .otherAllAA || option == .otherTreat {
                                    if !viewModel.selectableOtherPayers.isEmpty {
                                        showingOtherPayerSheet = true
                                    }
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: viewModel.splitOption == option ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(viewModel.splitOption == option ? Color.appSelection : Color.secondary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(option.title)
                                            .font(.headline)
                                            .foregroundStyle(Color.appTextPrimary)
                                        
                                        Text(option.description)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                if viewModel.splitOption == .otherAllAA || viewModel.splitOption == .otherTreat {
                    if viewModel.selectableOtherPayers.isEmpty {
                        Text(L.splitAddOtherMembers.localized)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    } else {
                        HStack {
                            Text(L.splitPayer.localized)
                            Spacer()
                            Text(selectedOtherPayerName)
                                .foregroundStyle(Color.appTextPrimary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.appSecondaryText)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingOtherPayerSheet = true
                        }
                        .confirmationDialog(L.splitSelectPayer.localized, isPresented: $showingOtherPayerSheet, titleVisibility: .visible) {
                            ForEach(viewModel.selectableOtherPayers) { member in
                                Button(member.name) {
                                    viewModel.selectOtherPayer(id: member.id)
                                }
                            }
                            Button(L.cancel.localized, role: .cancel) { }
                        }
                    }
                }
                
                if viewModel.splitOption == .helpPay {
                    if viewModel.availableMembers.count < 2 {
                        Text(L.splitAddOtherMembers.localized)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    } else {
                        VStack(spacing: 12) {
                            // 付款人选择器
                            HStack {
                                Text(L.splitPayer.localized)
                                Spacer()
                                Text(selectedHelpPayPayerName)
                                    .foregroundStyle(.blue)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showingHelpPayPayerSheet = true
                            }
                            .confirmationDialog(L.splitSelectPayer.localized, isPresented: $showingHelpPayPayerSheet, titleVisibility: .visible) {
                                ForEach(viewModel.selectableHelpPayPayers) { member in
                                    Button(member.name) {
                                        viewModel.selectHelpPayPayer(id: member.id)
                                    }
                                }
                                Button(L.cancel.localized, role: .cancel) { }
                            }
                            
                            Divider()
                            
                            // 受益人选择器
                            HStack {
                                Text(L.splitBeneficiary.localized)
                                Spacer()
                                Text(selectedBeneficiaryName)
                                    .foregroundStyle(Color.appTextPrimary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                showingBeneficiarySheet = true
                            }
                            .confirmationDialog(L.splitSelectBeneficiary.localized, isPresented: $showingBeneficiarySheet, titleVisibility: .visible) {
                                ForEach(viewModel.selectableBeneficiaries) { member in
                                    Button(member.name) {
                                        viewModel.selectBeneficiary(id: member.id)
                                    }
                                }
                                Button(L.cancel.localized, role: .cancel) { }
                            }
                        }
                    }
                }
            } header: {
                Text(L.expenseSplitMethod.localized)
            }
            
            // 第四栏：基本信息（可选填写）
            Section {
                // 用途
                TextField(L.expensePurpose.localized, text: binding(
                    get: { viewModel.draft.title },
                    set: { viewModel.draft.title = $0 }
                ))
                .submitLabel(.done)
                
                // 将日期与分类顺序对调：先分类，后日期
                HStack {
                    Text(L.expenseCategory.localized)
                    Spacer()
                    Text(viewModel.draft.category.displayName)
                        .foregroundStyle(Color.appTextPrimary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { showingCategorySheet = true }
                .confirmationDialog(L.expenseCategory.localized, isPresented: $showingCategorySheet, titleVisibility: .visible) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        Button(category.displayName) {
                            viewModel.draft.category = category
                            viewModel.regeneratePreview()
                        }
                    }
                    Button(L.cancel.localized, role: .cancel) { }
                }

                DatePicker(L.expenseDate.localized, selection: binding(
                    get: { viewModel.draft.date },
                    set: { viewModel.draft.date = $0 }
                ), displayedComponents: [.date, .hourAndMinute])
            } header: {
                Text(L.expenseBasicInfo.localized)
            } footer: {
                Text(L.expenseOptionalFields.localized)
                    .font(.caption2)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .tint(Color.appTextPrimary)
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
    }

    private var selectedOtherPayerName: String {
        guard let id = viewModel.selectedOtherPayerId,
              let member = viewModel.selectableOtherPayers.first(where: { $0.id == id }) else {
            return "请选择"
        }
        return member.name
    }

    private func binding<Value>(get: @escaping () -> Value, set: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(get: get, set: { newValue in
            set(newValue)
            viewModel.regeneratePreview()
        })
    }
    
    /// 获取当前区域设置的小数分隔符
    private var decimalSeparator: String {
        Locale.current.decimalSeparator ?? "."
    }
    
    /// 获取当前区域设置的千位分隔符
    private var groupingSeparator: String {
        Locale.current.groupingSeparator ?? ","
    }
    
    /// placeholder 文本（根据地区设置显示）
    private var placeholderText: String {
        "0\(decimalSeparator)00"
    }
    
    /// 使用当前区域设置格式化金额
    private func formatAmount(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "\(amount)"
    }
    
    /// 使用当前区域设置解析 Decimal
    private func parseDecimal(from string: String) -> Decimal? {
        // 移除千位分隔符
        let cleanString = string.replacingOccurrences(of: groupingSeparator, with: "")
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale.current
        
        if let number = formatter.number(from: cleanString) {
            return number.decimalValue
        }
        return nil
    }
    
    /// 验证并限制小数输入位数（支持不同地区的小数分隔符）
    private func validateDecimalInput(_ input: String, maxDecimalPlaces: Int, oldValue: String) -> String {
        // 允许空字符串
        if input.isEmpty { return input }
        
        let separator = decimalSeparator
        
        // 移除千位分隔符（用户可能复制粘贴了包含千位分隔符的数字）
        let cleanInput = input.replacingOccurrences(of: groupingSeparator, with: "")
        
        // 检查小数点
        let components = cleanInput.split(separator: Character(separator), omittingEmptySubsequences: false)
        
        // 只允许一个小数点
        if components.count > 2 { return oldValue }
        
        // 限制小数位数
        if components.count == 2 {
            let decimalPart = String(components[1])
            if decimalPart.count > maxDecimalPlaces {
                // 截断到最大位数
                return "\(components[0])\(separator)\(decimalPart.prefix(maxDecimalPlaces))"
            }
        }
        
        // 验证是否为有效数字（包括"10."这样的中间状态）
        if cleanInput.last?.description == separator {
            // 允许以小数点结尾（输入中间状态）
            let prefix = String(cleanInput.dropLast())
            if prefix.isEmpty || parseDecimal(from: prefix) != nil {
                return cleanInput
            }
        }
        
        guard parseDecimal(from: cleanInput) != nil else { return oldValue }
        
        return cleanInput
    }
}

struct ExpenseFormHost: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: ExpenseFormScreenModel

    init(rootViewModel: AppRootViewModel, ledgerId: UUID) {
        _viewModel = StateObject(wrappedValue: rootViewModel.makeExpenseFormViewModel(ledgerId: ledgerId))
    }

    var body: some View {
        NavigationStack {
            ExpenseFormView(viewModel: viewModel)
                .navigationTitle(L.expenseTitle.localized)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L.cancel.localized, action: dismiss.callAsFunction)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L.save.localized) {
                            // 先验证，验证通过才保存
                            if viewModel.validateSplitAmounts() {
                                viewModel.saveDraft()
                                dismiss()
                            }
                            // 如果验证失败，validationError 会自动显示在UI上
                        }
                        .disabled(viewModel.draft.amount <= .zero)
                    }
                }
        }
    }
}

struct SettlementHost: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SettlementScreenModel

    init(rootViewModel: AppRootViewModel, ledgerId: UUID) {
        _viewModel = StateObject(wrappedValue: rootViewModel.makeSettlementViewModel(ledgerId: ledgerId))
    }

    var body: some View {
        NavigationStack {
            SettlementView(viewModel: viewModel)
                .navigationTitle(L.settlementTitle.localized)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L.close.localized, action: dismiss.callAsFunction) }
                }
        }
        .background(Color.appBackground)
    }
}

struct SettlementView<Model: SettlementViewModelProtocol>: View {
    @ObservedObject var viewModel: Model
    @Environment(\.dismiss) private var dismiss
    @State private var showClearConfirmation = false

    var body: some View {
        List {
            Section(L.settlementCurrentNet.localized) {
                ForEach(viewModel.netBalances) { balance in
                    HStack {
                        Text(balance.userName)
                        Spacer()
                        Text(balance.amountDisplay)
                            .foregroundStyle(balance.isPositive ? Color.appSuccess : Color.appDanger)
                    }
                }
            }

            Section(L.settlementMinTransfers.localized) {
                if viewModel.transferPlan.isEmpty {
                    Text(L.settlementAllSettled.localized)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.transferPlan) { transfer in
                        VStack(alignment: .leading) {
                            Text("\(transfer.fromName) → \(transfer.toName)")
                            Text(transfer.amountDisplay)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // 一键清账按钮
                if !viewModel.transferPlan.isEmpty {
                    Button(action: { showClearConfirmation = true }) {
                        HStack {
                            Label(L.ledgerCardClearBalances.localized, systemImage: "checkmark.circle")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.appSuccess.opacity(0.1)))
                        .foregroundStyle(Color.appSuccess)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .onAppear(perform: viewModel.generatePlan)
        .alert(L.clearBalancesConfirmTitle.localized, isPresented: $showClearConfirmation) {
            Button(L.cancel.localized, role: .cancel) { }
            Button(L.clearBalancesConfirmButton.localized) {
                viewModel.clearAllBalances()
                dismiss()
            }
        } message: {
            Text(L.clearBalancesConfirmMessage.localized)
        }
    }
}

struct MemberDetailHost: View {
    @StateObject private var viewModel: MemberDetailScreenModel

    init(rootViewModel: AppRootViewModel, ledgerId: UUID, member: MemberSummaryViewData) {
        _viewModel = StateObject(wrappedValue: rootViewModel.makeMemberDetailViewModel(memberId: member.id, ledgerId: ledgerId))
    }

    var body: some View {
        MemberDetailView(viewModel: viewModel)
            .navigationTitle(viewModel.member.name)
    }
}

struct MemberDetailView<Model: MemberDetailViewModelProtocol>: View {
    @ObservedObject var viewModel: Model

    var body: some View {
        List {
            Section("分类占比") {
                ForEach(viewModel.breakdown) { item in
                    HStack {
                        Text(item.category.displayName)
                        Spacer()
                        Text(String(format: "%.0f%%", item.percentage * 100))
                    }
                }
            }

            Section("时间走势") {
                ForEach(viewModel.timeline) { point in
                    HStack {
                        Text(point.date, style: .date)
                        Spacer()
                        Text(AmountFormatter.string(minorUnits: point.amountMinorUnits, currency: .eur, locale: Locale.current))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
