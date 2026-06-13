//
//  SharedLedgerOverviewViews.swift
//  KuaiJi
//

import SwiftUI

struct LedgerOverviewHost: View {
    @ObservedObject var rootViewModel: AppRootViewModel
    let summary: LedgerSummaryViewData
    @StateObject private var viewModel: LedgerOverviewScreenModel
    @State private var showExpenseForm = false
    @State private var showSettlement = false
    @State private var showRecords = false

    init(rootViewModel: AppRootViewModel, summary: LedgerSummaryViewData) {
        self.rootViewModel = rootViewModel
        self.summary = summary
        _viewModel = StateObject(wrappedValue: rootViewModel.makeLedgerOverviewViewModel(ledgerId: summary.id))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            LedgerOverviewView(viewModel: viewModel,
                               onAddExpense: { showExpenseForm = true },
                               onOpenSettlement: { showSettlement = true },
                               onShowRecords: { showRecords = true })
            FloatingActionButton(systemImage: "plus") { showExpenseForm = true }
                .accessibilityLabel(L.ledgerAddExpense.localized)
                .padding(.trailing, 24)
                .padding(.bottom, 24)
        }
        .navigationTitle(viewModel.ledger.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    SharedLedgerStatsView(viewModel: SharedLedgerStatsViewModel(ledgerId: summary.id, ledgerName: viewModel.ledger.name, currency: viewModel.ledger.currency, records: viewModel.records))
                } label: {
                    Image(systemName: "chart.pie")
                }
            }
        }
        .sheet(isPresented: $showExpenseForm) {
            ExpenseFormHost(rootViewModel: rootViewModel, ledgerId: summary.id)
        }
        .sheet(isPresented: $showSettlement) {
            SettlementHost(rootViewModel: rootViewModel, ledgerId: summary.id)
        }
        .sheet(isPresented: $showRecords) {
            RecordsSheet(viewModel: viewModel)
        }
        .navigationDestination(for: MemberSummaryViewData.self) { member in
            MemberDetailHost(rootViewModel: rootViewModel, ledgerId: summary.id, member: member)
        }
    }
}

struct LedgerOverviewView<Model: LedgerOverviewViewModelProtocol>: View {
    @ObservedObject var viewModel: Model
    var onAddExpense: () -> Void
    var onOpenSettlement: () -> Void
    var onShowRecords: () -> Void
    
    @State private var showAllMembers = false
    @State private var showAllRecords = false
    @State private var showClearConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 第一栏：总支出
                totalExpensesCard
                
                // 第二栏：当前净额
                netBalancesCard
                
                // 第三栏：最近流水
                recentRecordsCard
                
                // 第四栏：成员支出
                memberExpensesCard
                
                // 第五栏：转账方案
                transferPlanCard
            }
            .padding()
        }
        .background(Color.appBackground)
        .sheet(isPresented: $showAllMembers) {
            AllMembersSheet(memberExpenses: viewModel.memberExpenses)
        }
        .sheet(isPresented: $showAllRecords) {
            RecordsSheet(viewModel: viewModel)
        }
        .alert(L.clearBalancesConfirmTitle.localized, isPresented: $showClearConfirmation) {
            Button(L.cancel.localized, role: .cancel) { }
            Button(L.clearBalancesConfirmButton.localized) {
                viewModel.clearAllBalances()
            }
        } message: {
            Text(L.clearBalancesConfirmMessage.localized)
        }
        .onAppear(perform: viewModel.refresh)
    }

    // 第一栏：总支出
    private var totalExpensesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.ledgerCardTotalExpenses.localized)
                .font(.headline)
            
            Text(viewModel.ledger.totalSpentDisplay)
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(Color.appSelection)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.appSelection.opacity(0.1)))
    }
    
    // 第四栏：成员支出
    private var memberExpensesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                Text(L.ledgerCardMemberExpenses.localized)
                    .font(.headline)
                Spacer()
                Button(action: { showAllMembers = true }) {
                    Text(L.ledgerCardAllButton.localized)
                        .font(.subheadline)
                        .foregroundStyle(Color.appLedgerContentText)
                }
            }
            
            // 成员支出列表（最多显示4个）
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(viewModel.memberExpenses.prefix(4))) { member in
                    HStack(spacing: 12) {
                        Text(member.displayAvatar)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.secondary.opacity(0.15)))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.name)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(L.ledgerCardMemberTotalSpent.localized)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text(member.totalSpentDisplay)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.appSelection)
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.1)))
    }

    // 第三栏：最近流水
    private var recentRecordsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L.ledgerCardRecentRecords.localized)
                    .font(.headline)
                Spacer()
                Button(action: { showAllRecords = true }) {
                    Text(L.ledgerCardAllButton.localized)
                        .font(.subheadline)
                        .foregroundStyle(Color.appLedgerContentText)
                }
            }
            
            if viewModel.records.isEmpty {
                Text(L.ledgerCardNoRecords.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(viewModel.records.prefix(3))) { record in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(record.payerName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(record.amountDisplay)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(Color.appSelection)
                                Text(record.date, style: .date)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.appDanger.opacity(0.1)))
    }
    
    // 第二栏：当前净额
    private var netBalancesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.settlementCurrentNet.localized)
                .font(.headline)
            
            if viewModel.balances.isEmpty {
                Text(L.settlementAllSettled.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.balances) { balance in
                        HStack {
                            Text(balance.userName)
                                .font(.subheadline)
                            Spacer()
                            Text(balance.amountDisplay)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(balance.isPositive ? Color.appSuccess : Color.appDanger)
                        }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.appWarning.opacity(0.15)))
    }
    
    // 第五栏：转账方案
    private var transferPlanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.settlementMinTransfers.localized)
                .font(.headline)
            
            if viewModel.transferPlan.isEmpty {
                Text(L.settlementAllSettled.localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(viewModel.transferPlan) { transfer in
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(transfer.fromName) → \(transfer.toName)")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(transfer.amountDisplay)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // 一键清账按钮
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
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.1)))
    }
}

// MARK: - All Members Sheet

struct AllMembersSheet: View {
    @Environment(\.dismiss) private var dismiss
    let memberExpenses: [MemberExpenseViewData]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(memberExpenses) { member in
                    HStack {
                        Text(member.displayAvatar)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.secondary.opacity(0.15)))
                        
                    VStack(alignment: .leading, spacing: 4) {
                        Text(member.name)
                            .font(.headline)
                        Text(L.allMembersTotalSpent.localized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                        
                        Spacer()
                        
                        Text(member.totalSpentDisplay)
                            .font(.headline)
                            .foregroundStyle(Color.appSelection)
                    }
                    .padding(.vertical, 4)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(L.allMembersTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.close.localized) { dismiss() }
                    .tint(Color.appTextPrimary)
                }
            }
        }
    }
}

// MARK: - Records Sheet

struct RecordsSheet<Model: LedgerOverviewViewModelProtocol>: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: Model

    var body: some View {
        NavigationStack {
            List {
                if viewModel.records.isEmpty {
                    ContentUnavailableView(L.recordsEmpty.localized, 
                                         systemImage: "doc.text",
                                         description: Text(L.recordsEmptyDesc.localized))
                } else {
                    ForEach(viewModel.records) { record in
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
                            
                            HStack(spacing: 8) {
                                Image(systemName: categoryIcon(for: record.category))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(record.category.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onDelete { offsets in
                        viewModel.deleteExpense(at: offsets)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(L.recordsTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                    Button(L.close.localized) { dismiss() }
                }
            }
        }
    }
    
    private func categoryIcon(for category: ExpenseCategory) -> String {
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
}

// MARK: - Friend Management Sheets
