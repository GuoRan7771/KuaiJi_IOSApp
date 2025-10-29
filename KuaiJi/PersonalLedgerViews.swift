//
//  PersonalLedgerViews.swift
//  KuaiJi
//
//  Simplified SwiftUI surfaces for the personal ledger module.
//

import Charts
import Combine
import SwiftUI
import UIKit

enum PersonalLedgerRoute: Hashable {
    case allRecords(Date)
    case allRecordsAll
    case accounts
    case stats
    case export
    case archive
    case recordDetail(PersonalRecordRowViewData)
}

struct PersonalLedgerNavigator: View {
    @ObservedObject var root: PersonalLedgerRootViewModel
    @StateObject private var homeViewModel: PersonalLedgerHomeViewModel
    @State private var path: [PersonalLedgerRoute] = []
    @State private var showingRecordForm = false
    @State private var recordToEdit: PersonalRecordRowViewData?
    @EnvironmentObject var appState: AppState

    init(root: PersonalLedgerRootViewModel) {
        self.root = root
        _homeViewModel = StateObject(wrappedValue: root.makeHomeViewModel())
    }

    var body: some View {
        NavigationStack(path: $path) {
            PersonalLedgerHomeView(viewModel: homeViewModel,
                                   onCreateRecord: {
                                       recordToEdit = nil
                                       showingRecordForm = true
                                   },
                                   onShowArchive: {
                                       homeViewModel.prepareArchive()
                                       path.append(.archive)
                                   },
                                   onShowAllRecords: {
                                       path.append(.allRecordsAll)
                                   },
                                   onShowAccounts: { path.append(.accounts) },
                                   onShowStats: { path.append(.stats) },
                                   onShowExport: { path.append(.export) },
                                   onOpenRecord: { path.append(.recordDetail($0)) },
                                   onDeleteRecords: { ids in
                                       do {
                                           try root.store.deleteTransactionsOrTransfers(ids: ids)
                                       } catch {
                                           // swallow for now
                                       }
                                   },
                                   onEditRecord: { record in
                                       recordToEdit = record
                                       showingRecordForm = true
                                   })
            .navigationDestination(for: PersonalLedgerRoute.self) { route in
                switch route {
                case .allRecords(let date):
                    PersonalAllRecordsView(root: root, viewModel: root.makeAllRecordsViewModel(anchorDate: date))
                case .allRecordsAll:
                    PersonalAllRecordsView(root: root, viewModel: root.makeAllRecordsViewModelForAll())
                case .accounts:
                    PersonalAccountsView(root: root, viewModel: root.makeAccountsViewModel())
                case .stats:
                    PersonalStatsView(viewModel: root.makeStatsViewModel())
                case .export:
                    PersonalCSVExportView(root: root, viewModel: root.makeCSVExportViewModel())
                case .archive:
                    PersonalMonthlyArchiveView(viewModel: homeViewModel,
                                               onSelect: { month in
                        withAnimation(.easeInOut) {
                            path.append(.allRecords(month.date))
                        }
                    })
                case .recordDetail(let record):
                    if record.isTransfer {
                        PersonalTransferDetailView(root: root, record: record) { transfer in
                            // 打开转账编辑界面
                            path.removeAll(where: { if case .recordDetail = $0 { return true } else { return false } })
                            // 以转账编辑表单弹出
                            showingRecordForm = false
                            // 打开独立的转账编辑表单
                            // 使用统一入口：转账表单 Host
                            // 这里通过导航到账户页的转账表单以复用 ViewModel 能力
                            // 直接打开专用的转账编辑 Sheet
                            PersonalTransferEditSheet.present(root: root, transferId: transfer.remoteId)
                        }
                    } else {
                        PersonalRecordDetailView(root: root,
                                                 record: record,
                                                 onEdit: { editable in
                                                     recordToEdit = editable
                                                     showingRecordForm = true
                                                 })
                    }
                }
            }
            .sheet(isPresented: $showingRecordForm) {
                PersonalRecordFormHost(root: root, existing: recordToEdit) {
                    showingRecordForm = false
                    Task { await homeViewModel.refresh() }
                }
            }
            .navigationTitle(L.personalHomeTitle.localized)
            .onChange(of: appState.quickActionTarget) { _, target in
                guard case .personal = target else { return }
                recordToEdit = nil
                showingRecordForm = true
                appState.quickActionTarget = nil
            }
        }
    }
}

struct PersonalMonthlyArchiveView: View {
    @ObservedObject var viewModel: PersonalLedgerHomeViewModel
    var onSelect: (PersonalYearMonth) -> Void

    var body: some View {
        List {
            if viewModel.isLoadingArchive {
                Section(header: Text(L.personalArchiveTitle.localized)) {
                    HStack {
                        ProgressView()
                        Text(L.personalArchiveLoading.localized)
                    }
                }
            } else if viewModel.availableMonths.isEmpty {
                Section(header: Text(L.personalArchiveTitle.localized)) {
                    Text(L.personalArchiveEmpty.localized)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section(header: Text(L.personalArchiveTitle.localized)) {
                    ForEach(viewModel.availableMonths, id: \.id) { ym in
                        Button {
                            onSelect(ym)
                        } label: {
                            HStack {
                                Text(String(format: "%04d-%02d", ym.year, ym.month))
                                    .foregroundStyle(Color.appLedgerContentText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(Color.appLedgerContentText)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(L.personalArchiveTitle.localized)
    }
}

struct PersonalLedgerHomeView: View {
    @ObservedObject var viewModel: PersonalLedgerHomeViewModel
    var onCreateRecord: () -> Void
    var onShowArchive: () -> Void
    var onShowAllRecords: () -> Void
    var onShowAccounts: () -> Void
    var onShowStats: () -> Void
    var onShowExport: () -> Void
    var onOpenRecord: (PersonalRecordRowViewData) -> Void
    var onDeleteRecords: ([UUID]) async -> Void
    var onEditRecord: (PersonalRecordRowViewData) -> Void

    @State private var selection: Set<UUID> = []
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            List(selection: $selection) {
                Section {
                    HStack {
                        Spacer()
                        Button(action: onShowArchive) {
                            Text(L.all.localized)
                                .foregroundStyle(Color.appLedgerContentText)
                        }
                    }
                    .padding(.horizontal)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                    PersonalOverviewCard(selectedMonth: viewModel.selectedMonth,
                                         overview: viewModel.overview,
                                         canGoPrevious: viewModel.canGoToPreviousMonth,
                                         canGoNext: viewModel.canGoToNextMonth,
                                         onPrevious: { viewModel.changeMonth(by: -1) },
                                         onNext: { viewModel.changeMonth(by: 1) })
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
                Section(header: TodayHeader(onShowAll: onShowAllRecords)) {
                    if viewModel.todayRecords.isEmpty {
                        Text(L.personalTodayEmpty.localized)
                            .font(.system(size: 14, weight: .regular, design: .rounded))
                            .foregroundStyle(Color.appSecondaryText)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(viewModel.todayRecords) { record in
                            PersonalRecordRow(record: record,
                                              onTap: { onOpenRecord(record) },
                                              onEdit: { onEditRecord(record) },
                                              onDelete: { deleteRecords([record.id]) })
                            .listRowBackground(Color.clear)
                        }
                        .onDelete { indexSet in
                            let ids = indexSet.compactMap { viewModel.todayRecords[$0].id }
                            deleteRecords(ids)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarLeading) {
                    Button(action: onShowExport) {
                        Label(L.personalExportCSV.localized, systemImage: "square.and.arrow.up")
                    }
                    .tint(Color.appTextPrimary)
                    Button(action: onShowStats) {
                        Label(L.personalStatsTitle.localized, systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tint(Color.appTextPrimary)
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !selection.isEmpty {
                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label(L.delete.localized, systemImage: "trash")
                        }
                    }
                    Button(action: onShowAccounts) {
                        Label(L.personalAccountsManage.localized, systemImage: "creditcard")
                    }
                    .tint(Color.appTextPrimary)
                }
            }
            .alert(L.delete.localized, isPresented: $showingDeleteConfirmation) {
                Button(L.cancel.localized, role: .cancel) { }
                Button(L.delete.localized, role: .destructive) {
                    deleteRecords(Array(selection))
                }
            } message: {
                Text(L.personalDeleteConfirm.localized)
            }

            FloatingActionButton(systemImage: "plus", action: onCreateRecord)
                .padding(.trailing, 24)
                .padding(.bottom, 24)
        }
        .task { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
    }

    private func deleteRecords(_ ids: [UUID]) {
        guard !ids.isEmpty else { return }
        Task {
            await onDeleteRecords(ids)
            selection.subtract(ids)
            await viewModel.refresh()
        }
    }
}

private struct TodayHeader: View {
    var onShowAll: () -> Void

    var body: some View {
        HStack {
            Text(L.personalTodayTitle.localized)
                .font(.headline)
            Spacer()
            Button(action: onShowAll) {
                Text(L.all.localized)
                    .foregroundStyle(Color.appLedgerContentText)
            }
        }
    }
}

struct FloatingActionButton: View {
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            FloatingButtonLabel(systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }
}

struct FloatingButtonLabel: View {
    var systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.title)
            .foregroundStyle(Color.appTextPrimary)
            .frame(width: 56, height: 56)
            .background(Circle().fill(Color.appBackground))
            .shadow(color: Color.black.opacity(0.15), radius: 6, y: 3)
    }
}

struct PersonalOverviewCard: View {
    var selectedMonth: Date
    var overview: PersonalOverviewState
    var canGoPrevious: Bool
    var canGoNext: Bool
    var onPrevious: () -> Void
    var onNext: () -> Void

    @State private var dragOffset: CGFloat = 0
    private let dragThreshold: CGFloat = 60

    private static let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    var body: some View {
        VStack(spacing: 12) {
            // 顶部：左右箭头 + 月份标题
            HStack(spacing: 12) {
                MonthArrow(direction: .previous, enabled: canGoPrevious, action: onPrevious)
                Spacer(minLength: 8)
                Text(Self.monthFormatter.string(from: selectedMonth))
                    .font(.headline)
                    .foregroundStyle(Color.appLedgerContentText)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                MonthArrow(direction: .next, enabled: canGoNext, action: onNext)
            }

            // 中部：统计
            VStack(spacing: 12) {
                ForEach(overview.entries) { entry in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(entry.currency.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        HStack(alignment: .firstTextBaseline, spacing: 24) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(L.personalMonthlyExpense.localized)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appLedgerContentText.opacity(0.7))
                                AmountView(amountMinorUnits: entry.expenseMinorUnits,
                                           currency: entry.currency,
                                           tint: .red)
                            }

                            Spacer(minLength: 50)

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(L.personalMonthlyIncome.localized)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appLedgerContentText.opacity(0.7))
                                AmountView(amountMinorUnits: entry.incomeMinorUnits,
                                           currency: entry.currency,
                                           tint: .green,
                                           prefix: "+")
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .appCardStyle()
        .padding(.horizontal)
        .offset(x: dragOffset)
        .gesture(dragGesture)
        .animation(.spring(response: 0.25, dampingFraction: 0.85, blendDuration: 0.1), value: dragOffset)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                let horizontal = value.translation.width
                let vertical = abs(value.translation.height)
                guard abs(horizontal) > vertical else { return }
                dragOffset = horizontal / 2
            }
            .onEnded { value in
                let horizontal = value.translation.width
                defer { dragOffset = 0 }
                guard abs(horizontal) > dragThreshold else { return }
                if horizontal > 0 {
                    if canGoPrevious { onPrevious() }
                } else {
                    if canGoNext { onNext() }
                }
            }
    }
}

private struct MonthArrow: View {
    enum Direction { case previous, next }

    var direction: Direction
    var enabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: direction == .previous ? "chevron.left" : "chevron.right")
                .font(.title2.weight(.semibold))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .background(
            Circle()
                .strokeBorder(Color.secondary.opacity(0.15), lineWidth: 1)
                .background(Circle().fill(Color.secondary.opacity(0.08)))
        )
        .gesture(
            DragGesture(minimumDistance: 12)
                .onEnded { value in
                    guard enabled else { return }
                    let horizontal = value.translation.width
                    if abs(horizontal) < abs(value.translation.height) { return }
                    if direction == .previous, horizontal > 40 {
                        action()
                    } else if direction == .next, horizontal < -40 {
                        action()
                    }
                }
        )
    }
}

private struct AmountView: View {
    var amountMinorUnits: Int
    var currency: CurrencyCode
    var tint: Color
    var prefix: String = ""

    var body: some View {
        Text(formatted)
            .font(.title3.weight(.semibold))
            .foregroundStyle(tint)
    }

    private var formatted: String {
        let base = AmountFormatter.string(minorUnits: amountMinorUnits,
                                          currency: currency,
                                          locale: Locale.current)
        if amountMinorUnits > 0 && !prefix.isEmpty {
            return prefix + base
        }
        return base
    }
}

private struct AnimatedAmountText: View, Animatable {
    var amountMinorUnits: Double
    var currency: CurrencyCode
    var color: Color
    var positivePrefix: String = ""

    var animatableData: Double {
        get { amountMinorUnits }
        set { amountMinorUnits = newValue }
    }

    var body: some View {
        let rounded = Int(amountMinorUnits.rounded())
        let formatted = AmountFormatter.string(minorUnits: rounded,
                                               currency: currency,
                                               locale: Locale.current)
        let text = rounded > 0 && !positivePrefix.isEmpty ? positivePrefix + formatted : formatted
        return Text(text)
            .foregroundStyle(color)
            .animation(.interpolatingSpring(stiffness: 200, damping: 18), value: rounded)
    }
}

struct PersonalRecordRow: View {
    var record: PersonalRecordRowViewData
    var onTap: () -> Void
    var onEdit: () -> Void
    var onDelete: () -> Void
    var timestampText: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.systemImage)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.categoryName)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                if !record.note.isEmpty {
                    Text(record.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(AmountFormatter.string(minorUnits: record.amountMinorUnits,
                                            currency: record.currency,
                                            locale: Locale.current))
                    .foregroundStyle(record.amountIsPositive ? Color.green : Color.red)
                Text(timestampText ?? record.occurredAt.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.appSecondaryText)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button(L.edit.localized, action: onEdit)
            Button(L.delete.localized, role: .destructive, action: onDelete)
        }
        .swipeActions {
            Button(role: .destructive, action: onDelete) {
                Label(L.delete.localized, systemImage: "trash")
            }
            Button(action: onEdit) {
                Label(L.edit.localized, systemImage: "pencil")
            }
            .tint(Color.appBrand)
        }
    }
}

struct PersonalRecordDetailView: View {
    @ObservedObject var root: PersonalLedgerRootViewModel
    var record: PersonalRecordRowViewData
    var onEdit: (PersonalRecordRowViewData) -> Void
    @State private var showingDeleteAlert = false
    @State private var storeChangeTick = 0

    private var latest: PersonalTransaction? {
        root.store.transaction(with: record.id)
    }

    var body: some View {
        List {
            Section(header: Text(L.personalDetailSection.localized)) {
                if let tx = latest, let account = root.store.account(with: tx.accountId) {
                    let categoryName = localizedCategoryName(tx.categoryKey)
                    DetailRow(title: L.personalDetailCategory.localized, value: categoryName)
                    DetailRow(title: L.personalDetailAccount.localized, value: root.store.account(with: tx.accountId)?.name ?? record.accountName)
                    let kindDisplay = PersonalRecordRowViewData(id: tx.remoteId,
                                                                categoryKey: tx.categoryKey,
                                                                categoryName: categoryName,
                                                                systemImage: iconForCategory(key: tx.categoryKey),
                                                                note: tx.note,
                                                                amountMinorUnits: tx.amountMinorUnits,
                                                                currency: account.currency,
                                                                occurredAt: tx.occurredAt,
                                                                createdAt: tx.createdAt,
                                                                accountName: account.name,
                                                                accountId: account.remoteId,
                                                                entryNature: .transaction(tx.kind),
                                                                transferDescription: nil).kindDisplay
                    DetailRow(title: L.personalDetailType.localized, value: kindDisplay)
                    DetailRow(title: L.personalDetailAmount.localized,
                              value: AmountFormatter.string(minorUnits: tx.amountMinorUnits,
                                                             currency: account.currency,
                                                             locale: Locale.current))
                    DetailRow(title: L.personalDetailDate.localized,
                              value: tx.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    if !tx.note.isEmpty {
                        DetailRow(title: L.personalDetailNote.localized, value: tx.note)
                    }
                } else {
                    DetailRow(title: L.personalDetailCategory.localized, value: record.categoryName)
                    DetailRow(title: L.personalDetailAccount.localized, value: record.accountName)
                    DetailRow(title: L.personalDetailType.localized, value: record.kindDisplay)
                    DetailRow(title: L.personalDetailAmount.localized,
                              value: AmountFormatter.string(minorUnits: record.amountMinorUnits,
                                                             currency: record.currency,
                                                             locale: Locale.current))
                    DetailRow(title: L.personalDetailDate.localized,
                              value: record.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    if !record.note.isEmpty {
                        DetailRow(title: L.personalDetailNote.localized, value: record.note)
                    }
                }
            }
        }
        .navigationTitle(latest != nil ? localizedCategoryName(latest!.categoryKey) : record.categoryName)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button(L.edit.localized) { onEdit(record) }
                Button(role: .destructive) { showingDeleteAlert = true } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .onReceive(root.store.objectWillChange) { _ in
            // bump a state to trigger view refresh when store changes (after edits)
            storeChangeTick &+= 1
        }
        .alert(L.delete.localized, isPresented: $showingDeleteAlert) {
            Button(L.cancel.localized, role: .cancel) {}
            Button(L.delete.localized, role: .destructive) {
                Task {
                    try? root.store.deleteTransactionsOrTransfers(ids: [record.id])
                }
            }
        } message: {
            Text(L.personalDeleteConfirm.localized)
        }
    }
}

struct PersonalTransferDetailView: View {
    @ObservedObject var root: PersonalLedgerRootViewModel
    var record: PersonalRecordRowViewData
    var onEdit: (AccountTransfer) -> Void
    @State private var showingDeleteAlert = false

    var body: some View {
        List {
            if let transfer = root.store.transfer(with: record.id),
               let from = root.store.account(with: transfer.fromAccountId),
               let to = root.store.account(with: transfer.toAccountId) {
                Section(header: Text(L.personalDetailSection.localized)) {
                    DetailRow(title: L.personalDetailCategory.localized, value: L.personalTransferTitle.localized)
                    DetailRow(title: L.personalDetailAccount.localized, value: from.name)
                    DetailRow(title: L.personalDetailNote.localized, value: String(format: L.personalTransferDirection.localized, from.name, to.name))
                    DetailRow(title: L.personalDetailAmount.localized,
                              value: AmountFormatter.string(minorUnits: transfer.amountFromMinorUnits,
                                                           currency: from.currency,
                                                           locale: Locale.current))
                    DetailRow(title: L.personalDetailDate.localized,
                              value: transfer.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    if let fee = transfer.feeMinorUnits, fee > 0 {
                        DetailRow(title: L.personalTransferFee.localized,
                                  value: AmountFormatter.string(minorUnits: fee,
                                                               currency: (transfer.feeChargedOn == .from ? from.currency : to.currency),
                                                               locale: Locale.current))
                    }
                }
            }
        }
        .navigationTitle(L.personalTransferTitle.localized)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if let transfer = root.store.transfer(with: record.id) {
                    Button(L.edit.localized) { onEdit(transfer) }
                }
                Button(role: .destructive) { showingDeleteAlert = true } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .alert(L.delete.localized, isPresented: $showingDeleteAlert) {
            Button(L.cancel.localized, role: .cancel) {}
            Button(L.delete.localized, role: .destructive) {
                Task {
                    try? root.store.deleteTransactionsOrTransfers(ids: [record.id])
                }
            }
        } message: {
            Text(L.personalDeleteConfirm.localized)
        }
    }
}

private enum PersonalTransferEditSheet {
    static func present(root: PersonalLedgerRootViewModel, transferId: UUID) {
        // Simple runtime presentation via UIKit bridge
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else { return }
        let host = UIHostingController(rootView: PersonalTransferEditHost(root: root, transferId: transferId))
        rootVC.present(host, animated: true)
    }
}

private struct PersonalTransferEditHost: View {
    @Environment(\.dismiss) private var dismiss
    let root: PersonalLedgerRootViewModel
    let transferId: UUID

    var body: some View {
        NavigationStack {
            PersonalTransferFormView(viewModel: root.makeTransferFormViewModel(transferId: transferId)) {
                dismiss()
            }
            .navigationTitle(L.personalTransferTitle.localized)
        }
    }
}

private struct DetailRow: View {
    var title: String
    var value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

struct PersonalRecordFormHost: View {
    @StateObject private var viewModel: PersonalRecordFormViewModel
    var onDismiss: () -> Void

    init(root: PersonalLedgerRootViewModel, existing: PersonalRecordRowViewData?, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: root.makeRecordFormViewModel(existing: existing))
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            PersonalRecordFormView(viewModel: viewModel, onDone: onDismiss)
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
    }
}

private struct SharedLedgerOption: Identifiable, Hashable {
    var id: UUID
    var name: String
    var currency: CurrencyCode
}

private struct SharedExpenseDraft: Identifiable, Hashable {
    var id: UUID = UUID()
    var amount: Decimal
    var currency: CurrencyCode
    var occurredAt: Date
    var category: ExpenseCategory
    var note: String
}

private extension SharedLedgerQuickAdd.SplitMode {
    var title: String {
        switch self {
        case .equalShares:
            return L.personalSaveAndShareModeEqual.localized
        case .payerTreat:
            return L.personalSaveAndShareModeTreat.localized
        }
    }
}

private extension ExpenseCategory {
    var localizedName: String {
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

private struct SaveToSharedSheet: View {
    var draft: SharedExpenseDraft
    var ledgers: [SharedLedgerOption]
    @Binding var selectedLedgerId: UUID?
    var onConfirm: (QuickSplitConfiguration) -> Void
    var onCancel: () -> Void

    private var selectedLedger: SharedLedgerOption? {
        guard let selectedLedgerId else { return nil }
        return ledgers.first(where: { $0.id == selectedLedgerId })
    }

    private var currencyMismatch: Bool {
        guard let ledger = selectedLedger else { return false }
        return ledger.currency != draft.currency
    }

    @EnvironmentObject private var appRootViewModel: AppRootViewModel
    @EnvironmentObject private var appState: AppState
    @State private var splitOption: ExpenseSplitOption = .meAllAA
    @State private var members: [MemberSummaryViewData] = []
    @State private var selectedOtherPayerId: UUID?
    @State private var selectedHelpPayPayerId: UUID?
    @State private var selectedBeneficiaryId: UUID?

    var body: some View {
        NavigationStack {
            Form {
                ledgerPickerSection()
                splitModeSection()
                summarySection()
            }
            .navigationTitle(L.personalSaveAndShareSheetTitle.localized)
            .toolbar { toolbarContent() }
        }
        .onAppear {
            if selectedLedgerId == nil { selectedLedgerId = resolvedLedgers().first?.id }
            loadMembersIfNeeded()
        }
        .onChange(of: selectedLedgerId) { _, _ in loadMembersIfNeeded() }
    }

    // MARK: - Subsections (split to reduce type-checking complexity)

    @ViewBuilder private func ledgerPickerSection() -> some View {
        Section(header: Text(L.personalSaveAndShareLedgerSection.localized)) {
            let options = resolvedLedgers()
            if options.isEmpty {
                Text(L.personalSaveAndShareNoLedgers.localized)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(options) { option in
                    Button { selectedLedgerId = option.id } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(option.name).foregroundStyle(Color.appTextPrimary)
                                Text(option.currency.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: selectedLedgerId == option.id ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedLedgerId == option.id ? Color.blue : Color.appSecondaryText)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("saveAndShare.ledgerRow.\(option.id.uuidString)")
                    .contentShape(Rectangle())
                }

                if currencyMismatch, let ledger = selectedLedgerFrom(options: options) {
                    Text(L.personalSaveAndShareCurrencyMismatch.localized(ledger.currency.rawValue, draft.currency.rawValue))
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func resolvedLedgers() -> [SharedLedgerOption] {
        if !ledgers.isEmpty { return ledgers }
        var options: [SharedLedgerOption] = []
        let summaries = appRootViewModel.ledgerSummaries
        if !summaries.isEmpty {
            options = summaries.map { SharedLedgerOption(id: $0.id, name: $0.name, currency: $0.currency) }
        } else if let manager = appState.dataManager, !manager.allLedgers.isEmpty {
            options = manager.allLedgers.map { SharedLedgerOption(id: $0.remoteId, name: $0.name, currency: $0.currency) }
        }
        return options.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func selectedLedgerFrom(options: [SharedLedgerOption]) -> SharedLedgerOption? {
        guard let selectedLedgerId else { return nil }
        return options.first { $0.id == selectedLedgerId }
    }

    @ViewBuilder private func splitModeSection() -> some View {
        Section(header: Text(L.personalSaveAndShareSplitMode.localized)) {
            ForEach(ExpenseSplitOption.allCases) { option in
                Button {
                    splitOption = option
                    ensureValidSelections()
                } label: {
                    HStack {
                        Image(systemName: splitOption == option ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(splitOption == option ? Color.blue : Color.appSecondaryText)
                        Text(option.title).foregroundStyle(Color.appTextPrimary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("saveAndShare.split.\(option.id)")
            }

            if splitOption == .otherAllAA || splitOption == .otherTreat {
                otherPayerControls()
            }

            if splitOption == .helpPay {
                helpPayControls()
            }
        }
    }

    @ViewBuilder private func otherPayerControls() -> some View {
        if selectableOtherPayers.isEmpty {
            Text(L.splitAddOtherMembers.localized)
                .font(.footnote)
                .foregroundStyle(.orange)
        } else {
            Picker(L.splitPayer.localized, selection: otherPayerBinding()) {
                ForEach(selectableOtherPayers, id: \.id) { m in
                    Text(m.name).tag(m.id as UUID?)
                }
            }
        }
    }

    @ViewBuilder private func helpPayControls() -> some View {
        Picker(L.splitPayer.localized, selection: helpPayPayerBinding()) {
            ForEach(members, id: \.id) { m in
                Text(m.name).tag(m.id as UUID?)
            }
        }
        .accessibilityIdentifier("saveAndShare.payerPicker")
        Picker(L.splitBeneficiary.localized, selection: beneficiaryBinding()) {
            ForEach(selectableBeneficiaries, id: \.id) { m in
                Text(m.name).tag(m.id as UUID?)
            }
        }
        .accessibilityIdentifier("saveAndShare.beneficiaryPicker")
    }

    @ViewBuilder private func summarySection() -> some View {
        Section(header: Text(L.personalSaveAndShareSummary.localized)) {
            HStack {
                Text(L.personalFieldAmount.localized)
                Spacer()
                Text("\(draft.currency.rawValue) \(NSDecimalNumber(decimal: draft.amount).stringValue)")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(L.personalFieldCategory.localized)
                Spacer()
                Text(draft.category.localizedName)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text(L.personalFieldDate.localized)
                Spacer()
                Text(draft.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    .foregroundStyle(.secondary)
            }
            if !draft.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(alignment: .top) {
                    Text(L.personalFieldNote.localized)
                    Spacer()
                    Text(draft.note)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    @ToolbarContentBuilder private func toolbarContent() -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(L.cancel.localized, action: onCancel)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(L.personalSaveAndShare.localized) {
                if let config = try? buildConfiguration() {
                    onConfirm(config)
                }
            }
            .disabled(!canConfirm)
            .accessibilityIdentifier("saveAndShare.confirmButton")
        }
    }

    private var currentUserId: UUID { appRootViewModel.currentUser.id }

    private var selectableOtherPayers: [MemberSummaryViewData] {
        members.filter { $0.id != currentUserId }
    }

    private var selectableBeneficiaries: [MemberSummaryViewData] {
        guard let payer = selectedHelpPayPayerId else { return members }
        return members.filter { $0.id != payer }
    }

    private func loadMembersIfNeeded() {
        guard let id = selectedLedgerId else { return }
        members = appRootViewModel.ledgerMembers(ledgerId: id)
        ensureValidSelections()
    }

    // initializeLedgersIfNeeded removed; resolved via resolvedLedgers() and onAppear

    private func ensureValidSelections() {
        if splitOption == .otherAllAA || splitOption == .otherTreat {
            if selectedOtherPayerId == nil || !selectableOtherPayers.contains(where: { $0.id == selectedOtherPayerId }) {
                selectedOtherPayerId = selectableOtherPayers.first?.id
            }
        }
        if splitOption == .helpPay {
            if selectedHelpPayPayerId == nil { selectedHelpPayPayerId = members.first?.id }
            if selectedBeneficiaryId == nil || selectedBeneficiaryId == selectedHelpPayPayerId {
                selectedBeneficiaryId = selectableBeneficiaries.first?.id
            }
        }
    }

    private func otherPayerBinding() -> Binding<UUID?> {
        Binding<UUID?>(get: {
            selectedOtherPayerId ?? selectableOtherPayers.first?.id
        }, set: { newVal in
            selectedOtherPayerId = newVal
        })
    }

    private func helpPayPayerBinding() -> Binding<UUID?> {
        Binding<UUID?>(get: {
            selectedHelpPayPayerId ?? members.first?.id
        }, set: { newVal in
            selectedHelpPayPayerId = newVal
            if selectedBeneficiaryId == newVal {
                selectedBeneficiaryId = selectableBeneficiaries.first?.id
            }
        })
    }

    private func beneficiaryBinding() -> Binding<UUID?> {
        Binding<UUID?>(get: {
            selectedBeneficiaryId ?? selectableBeneficiaries.first?.id
        }, set: { newVal in
            selectedBeneficiaryId = newVal
        })
    }

    private var canConfirm: Bool {
        guard selectedLedgerId != nil, !resolvedLedgers().isEmpty else { return false }
        return isSplitValid()
    }

    private func isSplitValid() -> Bool {
        switch splitOption {
        case .meAllAA, .meTreat:
            return true
        case .otherAllAA, .otherTreat:
            // 只要选择了付款人即可
            return (selectedOtherPayerId != nil) || !selectableOtherPayers.isEmpty
        case .helpPay:
            guard let payer = selectedHelpPayPayerId ?? members.first?.id else { return false }
            let beneficiary = selectedBeneficiaryId ?? selectableBeneficiaries.first?.id
            return beneficiary != nil && payer != beneficiary
        }
    }

    private func buildConfiguration() throws -> QuickSplitConfiguration {
        let payerId: UUID
        let includePayer: Bool
        let strategy: SplitStrategy
        var participants: [ExpenseParticipantShare] = []

        switch splitOption {
        case .meAllAA:
            payerId = currentUserId
            includePayer = true
            strategy = .payerAA
            participants = members.map { ExpenseParticipantShare(userId: $0.id, shareType: .aa) }
        case .otherAllAA:
            payerId = selectedOtherPayerId ?? selectableOtherPayers.first?.id ?? currentUserId
            includePayer = true
            strategy = .payerAA
            participants = members.map { ExpenseParticipantShare(userId: $0.id, shareType: .aa) }
        case .meTreat:
            payerId = currentUserId
            includePayer = false
            strategy = .payerTreat
            participants = [ExpenseParticipantShare(userId: currentUserId, shareType: .treat)]
        case .otherTreat:
            payerId = selectedOtherPayerId ?? selectableOtherPayers.first?.id ?? currentUserId
            includePayer = false
            strategy = .actorTreat
            participants = [ExpenseParticipantShare(userId: payerId, shareType: .treat)]
        case .helpPay:
            let payer = selectedHelpPayPayerId ?? members.first?.id ?? currentUserId
            let beneficiary = selectedBeneficiaryId ?? selectableBeneficiaries.first?.id ?? currentUserId
            payerId = payer
            includePayer = false
            strategy = .helpPay
            participants = [ExpenseParticipantShare(userId: beneficiary, shareType: .aa)]
        }

        return QuickSplitConfiguration(payerId: payerId, splitStrategy: strategy, includePayer: includePayer, participants: participants)
    }
}

struct PersonalRecordFormView: View {
    @ObservedObject var viewModel: PersonalRecordFormViewModel
    var onDone: () -> Void

    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var appRootViewModel: AppRootViewModel
    @State private var isSharingWithSharedLedger = false
    @State private var sharedLedgerOptions: [SharedLedgerOption] = []
    @State private var selectedSharedLedgerId: UUID?
    @State private var pendingSharedDraft: SharedExpenseDraft?

    var body: some View {
        Form {
            Section(header: Text(L.personalFieldType.localized)) {
                Picker("", selection: $viewModel.kind) {
                    Text(L.personalTypeExpense.localized).tag(PersonalTransactionKind.expense)
                    Text(L.personalTypeIncome.localized).tag(PersonalTransactionKind.income)
                }
                .pickerStyle(.segmented)
            }
            Section(header: Text(L.personalFieldAccount.localized)) {
                Picker(L.personalFieldAccount.localized, selection: Binding(get: { viewModel.accountId }, set: viewModel.selectAccount)) {
                    ForEach(viewModel.accounts) { account in
                        Text("\(account.name) · \(account.currency.rawValue)").tag(account.remoteId as UUID?)
                    }
                }
            }
            // 基本信息
            Section(header: Text(L.expenseBasicInfo.localized)) {
                HStack {
                    TextField(L.personalFieldAmount.localized, text: $viewModel.amountText)
                        .keyboardType(.decimalPad)
                        .onChange(of: viewModel.amountText) { oldValue, newValue in
                            let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 2, locale: .current, oldValue: oldValue)
                            if validated != newValue { viewModel.amountText = validated }
                        }
                    Menu {
                        ForEach(viewModel.currencyOptions, id: \.self) { code in
                            Button(code.rawValue) { viewModel.selectAmountCurrency(code) }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.amountCurrency.rawValue)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.15)))
                    }
                    .accessibilityLabel(Text(L.personalFieldCurrency.localized))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if viewModel.showFXField {
                    TextField(L.personalFieldFXRate.localized,
                              text: $viewModel.fxRateText,
                              prompt: Text(viewModel.fxRatePlaceholder).foregroundStyle(.secondary))
                        .keyboardType(.decimalPad)
                        .onChange(of: viewModel.fxRateText) { oldValue, newValue in
                            let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 6, locale: .current, oldValue: oldValue)
                            if validated != newValue { viewModel.fxRateText = validated }
                        }
                    HStack(spacing: 8) {
                        Text(viewModel.fxInfoText)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L.personalTransferInvert.localized) {
                            viewModel.invertFXRate()
                        }
                        .font(.caption)
                    }
                    TextField(L.personalFieldFee.localized(viewModel.accountCurrencyCode),
                              text: $viewModel.feeText,
                              prompt: Text(viewModel.feePlaceholder).foregroundStyle(.secondary))
                        .keyboardType(.decimalPad)
                        .onChange(of: viewModel.feeText) { oldValue, newValue in
                            let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 2, locale: .current, oldValue: oldValue)
                            if validated != newValue { viewModel.feeText = validated }
                        }
                    Text(L.personalTransferFeeHint.localized)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                // 备注/来源
                TextField(viewModel.kind == .expense ? L.expensePurpose.localized : "income.source".localized, text: $viewModel.note, axis: .vertical)
                // 分类
                Picker(L.personalFieldCategory.localized, selection: $viewModel.categoryKey) {
                    ForEach(viewModel.categoryOptions, id: \.key) { option in
                        Text(option.localizedName).tag(option.key)
                    }
                }
                // 时间
                DatePicker(L.personalFieldDate.localized, selection: $viewModel.occurredAt, displayedComponents: [.date, .hourAndMinute])
            }
        }
        .dismissKeyboardOnTap()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(action: onDone) {
                    Text(L.cancel.localized)
                        .font(.headline)
                        .foregroundStyle(Color.appTextPrimary)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if canShowSaveAndShareButton {
                    Button(action: { beginSaveAndShareFlow() }) {
                        Text(L.personalSaveAndShare.localized)
                            .font(.headline)
                            .foregroundStyle(Color.appTextPrimary)
                    }
                    .disabled(viewModel.isSaving || isSharingWithSharedLedger)
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving || isSharingWithSharedLedger {
                    ProgressView()
                } else {
                    Button(action: {
                        Task {
                            let success = await viewModel.submit()
                            if success { onDone() }
                        }
                    }) {
                        Text(L.save.localized)
                            .font(.headline)
                            .foregroundStyle(Color.appTextPrimary)
                    }
                }
            }
        }
        .alert(viewModel.errorMessage ?? "", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })) {
            Button(L.ok.localized, action: {})
        }
        .sheet(item: $pendingSharedDraft) { draft in
            SaveToSharedSheet(draft: draft,
                              ledgers: sharedLedgerOptions,
                              selectedLedgerId: $selectedSharedLedgerId,
                              onConfirm: { config in confirmSaveAndShare(with: draft, configuration: config) },
                              onCancel: { cancelSaveToSharedFlow() })
        }
    }

    private var canShowSaveAndShareButton: Bool {
        guard appState.showSharedLedgerTab,
              appState.showPersonalLedgerTab,
              viewModel.kind == .expense else { return false }
        if !appRootViewModel.ledgerSummaries.isEmpty { return true }
        if let manager = appState.dataManager, !manager.allLedgers.isEmpty { return true }
        return false
    }

    private func beginSaveAndShareFlow() {
        guard !isSharingWithSharedLedger, !viewModel.isSaving else { return }
        guard appState.dataManager != nil else {
            viewModel.errorMessage = L.personalSaveAndShareUnavailable.localized
            return
        }

        let trimmedAmount = viewModel.amountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = NumberParsing.parseDecimal(trimmedAmount), amount > 0 else {
            viewModel.errorMessage = L.personalSaveAndShareInvalidAmount.localized
            return
        }

        let category = ExpenseCategory(rawValue: viewModel.categoryKey) ?? .other
        let draft = SharedExpenseDraft(amount: amount,
                                       currency: viewModel.amountCurrency,
                                       occurredAt: viewModel.occurredAt,
                                       category: category,
                                       note: viewModel.note)

        // Prefer shared ledgers from root view model; fallback to data manager if needed
        var options: [SharedLedgerOption] = []
        let summaries = appRootViewModel.ledgerSummaries
        if !summaries.isEmpty {
            options = summaries
                .map { SharedLedgerOption(id: $0.id, name: $0.name, currency: $0.currency) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } else if let manager = appState.dataManager, !manager.allLedgers.isEmpty {
            options = manager.allLedgers
                .map { SharedLedgerOption(id: $0.remoteId, name: $0.name, currency: $0.currency) }
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        guard !options.isEmpty else {
            viewModel.errorMessage = L.personalSaveAndShareNoLedgers.localized
            return
        }

        sharedLedgerOptions = options
        selectedSharedLedgerId = options.first?.id
        pendingSharedDraft = draft
    }

    private func cancelSaveToSharedFlow() {
        pendingSharedDraft = nil
    }

    private func confirmSaveAndShare(with draft: SharedExpenseDraft, configuration: QuickSplitConfiguration) {
        guard let ledgerId = selectedSharedLedgerId else { return }
        pendingSharedDraft = nil
        isSharingWithSharedLedger = true
        Task { @MainActor in
            defer { isSharingWithSharedLedger = false }
            do {
                try shareToSharedLedger(ledgerId: ledgerId, draft: draft, config: configuration)
                let success = await viewModel.submit()
                if success { onDone() }
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

@MainActor
private func shareToSharedLedger(ledgerId: UUID, draft: SharedExpenseDraft, config: QuickSplitConfiguration) throws {
        guard let manager = appState.dataManager else {
            throw SaveToSharedError.dataUnavailable
        }
        guard let ledger = manager.allLedgers.first(where: { $0.remoteId == ledgerId }) else {
            throw SaveToSharedError.ledgerMissing
        }
        guard ledger.currency == draft.currency else {
            throw SaveToSharedError.currencyMismatch(shared: ledger.currency, personal: draft.currency)
        }
        guard manager.currentUser != nil else {
            throw SaveToSharedError.currentUserMissing
        }

        let trimmedNote = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmedNote.isEmpty ? L.defaultUntitledExpense.localized : trimmedNote

        manager.addExpense(ledgerId: ledgerId,
                           payerId: config.payerId,
                           title: title,
                           amount: draft.amount,
                           currency: draft.currency,
                           date: draft.occurredAt,
                           category: draft.category,
                           note: draft.note,
                           splitStrategy: config.splitStrategy,
                           includePayer: config.includePayer,
                           participants: config.participants)

        // Ensure shared ledger UI refreshes immediately
        appRootViewModel.loadFromPersistence()
    }
}

private enum SaveToSharedError: LocalizedError {
    case dataUnavailable
    case ledgerMissing
    case currencyMismatch(shared: CurrencyCode, personal: CurrencyCode)
    case currentUserMissing

    var errorDescription: String? {
        switch self {
        case .dataUnavailable:
            return L.personalSaveAndShareUnavailable.localized
        case .ledgerMissing:
            return L.personalSaveAndShareLedgerMissing.localized
        case let .currencyMismatch(shared, personal):
            return L.personalSaveAndShareCurrencyMismatch.localized(shared.rawValue, personal.rawValue)
        case .currentUserMissing:
            return L.personalSaveAndShareMissingCurrentUser.localized
        }
    }
}

// MARK: - Bridge to Shared Ledger Full Split UI

private struct QuickSplitConfiguration {
    let payerId: UUID
    let splitStrategy: SplitStrategy
    let includePayer: Bool
    let participants: [ExpenseParticipantShare]
}

private enum SharedExpensePrefillSheet {
    static func present(rootViewModel: AppRootViewModel, ledgerId: UUID, prefill: SharedExpenseDraft) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else { return }
        let host = UIHostingController(rootView: SharedExpensePrefillHost(rootViewModel: rootViewModel,
                                                                          ledgerId: ledgerId,
                                                                          prefill: prefill))
        rootVC.present(host, animated: true)
    }
}

private struct SharedExpensePrefillHost: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var viewModel: ExpenseFormScreenModel
    private let prefill: SharedExpenseDraft

    init(rootViewModel: AppRootViewModel, ledgerId: UUID, prefill: SharedExpenseDraft) {
        _viewModel = ObservedObject(wrappedValue: rootViewModel.makeExpenseFormViewModel(ledgerId: ledgerId))
        self.prefill = prefill
    }

    var body: some View {
        NavigationStack {
            ExpenseFormView(viewModel: viewModel)
                .navigationTitle(L.expenseTitle.localized)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button(L.close.localized, action: dismiss.callAsFunction) }
                }
        }
        .onAppear {
            // Prefill shared expense fields from personal draft
            viewModel.draft.title = prefill.note.isEmpty ? L.defaultUntitledExpense.localized : prefill.note
            viewModel.draft.amount = prefill.amount
            viewModel.draft.date = prefill.occurredAt
            viewModel.draft.note = prefill.note
            viewModel.draft.category = prefill.category
            viewModel.regeneratePreview()
        }
    }
}

struct PersonalAllRecordsView: View {
    @ObservedObject var root: PersonalLedgerRootViewModel
    @StateObject private var viewModel: PersonalAllRecordsViewModel
    @State private var editingRecord: PersonalRecordRowViewData?

    init(root: PersonalLedgerRootViewModel, viewModel: PersonalAllRecordsViewModel) {
        self.root = root
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List(selection: $viewModel.selection) {
            Section {
                ForEach(viewModel.records) { record in
                    PersonalRecordRow(record: record,
                                      onTap: { },
                                      onEdit: {
                                          editingRecord = record
                                      },
                                      onDelete: {
                                          Task { await viewModel.deleteRecord(id: record.id) }
                                      },
                                      timestampText: timestampText(for: record))
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let id = viewModel.records[index].id
                        Task { await viewModel.deleteRecord(id: id) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(monthTitle())
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Menu {
                    Picker("", selection: $viewModel.sortMode) {
                        ForEach(PersonalAllRecordsViewModel.SortMode.allCases) { mode in
                            Text(mode.title)
                                .foregroundStyle(Color.appLedgerContentText)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .foregroundStyle(Color.appLedgerContentText)
                }
                if !viewModel.selection.isEmpty {
                    Button(L.delete.localized, role: .destructive) {
                        Task { await viewModel.deleteSelected() }
                    }
                }
            }
        }
        .task { await viewModel.refresh() }
        .alert(viewModel.lastError ?? "", isPresented: Binding(get: { viewModel.lastError != nil }, set: { _ in viewModel.lastError = nil })) {
            Button(L.ok.localized, action: {})
        }
        .sheet(item: $editingRecord) { record in
            PersonalRecordFormHost(root: root, existing: record) {
                editingRecord = nil
                Task { @MainActor in
                    try? root.store.refreshAccounts()
                    await viewModel.refresh()
                }
            }
        }
    }

    private func monthTitle() -> String {
        // 若 filterState 的范围正好是整月，则用"yyyy-MM 交易记录"，否则退回"全部记录"
        if let range = viewModel.filterState.dateRange {
            let cal = Calendar.current
            if let interval = cal.dateInterval(of: .month, for: range.lowerBound), interval.start == range.lowerBound && interval.end == range.upperBound {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM"
                return fmt.string(from: range.lowerBound) + " " + L.personalAllRecordsTitle.localized
            }
        }
        return L.personalAllRecordsTitle.localized
    }

    private func timestampText(for record: PersonalRecordRowViewData) -> String {
        let date: Date
        switch viewModel.sortMode {
        case .occurredAt:
            date = record.occurredAt
        case .createdAt:
            date = record.createdAt
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct FilterControls: View {
    @Binding var filterState: PersonalRecordFilterState
    var onApply: () -> Void
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            DatePicker(L.personalFilterFrom.localized, selection: Binding(get: {
                filterState.dateRange?.lowerBound ?? Date()
            }, set: { newValue in
                if let upper = filterState.dateRange?.upperBound {
                    filterState.dateRange = newValue...upper
                } else {
                    filterState.dateRange = newValue...Date()
                }
            }), displayedComponents: [.date])
            DatePicker(L.personalFilterTo.localized, selection: Binding(get: {
                filterState.dateRange?.upperBound ?? Date()
            }, set: { newValue in
                if let lower = filterState.dateRange?.lowerBound {
                    filterState.dateRange = lower...newValue
                } else {
                    filterState.dateRange = Date()...newValue
                }
            }), displayedComponents: [.date])
            TextField(L.personalFilterKeyword.localized, text: $filterState.keyword)
            HStack {
                TextField(L.personalFilterMin.localized, text: $filterState.minAmountText)
                    .keyboardType(.decimalPad)
                    .onChange(of: filterState.minAmountText) { oldValue, newValue in
                        let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 2, locale: .current, oldValue: oldValue)
                        if validated != newValue { filterState.minAmountText = validated }
                    }
                TextField(L.personalFilterMax.localized, text: $filterState.maxAmountText)
                    .keyboardType(.decimalPad)
                    .onChange(of: filterState.maxAmountText) { oldValue, newValue in
                        let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 2, locale: .current, oldValue: oldValue)
                        if validated != newValue { filterState.maxAmountText = validated }
                    }
            }
            Button(L.done.localized, action: onApply)
        } label: {
            Text(L.personalFilterTitle.localized)
        }
    }
}

struct PersonalAccountsView: View {
    @ObservedObject var root: PersonalLedgerRootViewModel
    @StateObject private var viewModel: PersonalAccountsViewModel
    @State private var showingAccountForm = false
    @State private var editingAccount: UUID?
    @State private var showingTransferForm = false
    @State private var pendingDeleteId: UUID?

    init(root: PersonalLedgerRootViewModel, viewModel: PersonalAccountsViewModel) {
        self.root = root
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            Section(header: Text(L.personalAccountsSummary.localized)) {
                if viewModel.totalSummary.entries.isEmpty {
                    Text(L.personalNetWorthEmpty.localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.totalSummary.entries) { entry in
                        HStack {
                            Text("\(L.personalNetWorth.localized) (\(entry.currency.rawValue))")
                            Spacer()
                            Text(AmountFormatter.string(minorUnits: entry.totalMinorUnits,
                                                        currency: entry.currency,
                                                        locale: Locale.current))
                                .font(.headline)
                        }
                    }
                }
            }
            Section {
                Toggle(L.personalShowArchived.localized, isOn: $viewModel.showArchived)
                    .tint(Color.appToggleOn)
            }
            Section(header: Text(L.personalAccountsList.localized)) {
                ForEach(viewModel.accounts) { account in
                    AccountRow(account: account,
                               onEdit: { editingAccount = account.id; showingAccountForm = true },
                               onArchive: { Task { await viewModel.archiveAccount(account.id) } },
                               onActivate: { Task { await viewModel.activateAccount(account.id) } },
                               onDelete: { pendingDeleteId = account.id })
                }
                .onMove(perform: viewModel.move)
                .onDelete { indexSet in
                    pendingDeleteId = indexSet.first.map { viewModel.accounts[$0].id }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(L.personalAccountsTitle.localized)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingTransferForm = true }) {
                    Image(systemName: "arrow.left.arrow.right")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                ControlGroup {
                    Button(action: { editingAccount = nil; showingAccountForm = true }) {
                        Image(systemName: "plus")
                    }
                    EditButton()
                }
            }
        }
        .sheet(isPresented: $showingAccountForm) {
            PersonalAccountFormHost(root: root, accountId: editingAccount) {
                showingAccountForm = false
                Task { await viewModel.refresh() }
            }
        }
        .sheet(isPresented: $showingTransferForm) {
            PersonalTransferFormHost(root: root) {
                showingTransferForm = false
                Task { await viewModel.refresh() }
            }
        }
        .task { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
        .alert(viewModel.lastError ?? "", isPresented: Binding(get: { viewModel.lastError != nil }, set: { _ in viewModel.lastError = nil })) {
            Button(L.ok.localized, action: {})
        }
        .alert(L.delete.localized, isPresented: Binding(get: { pendingDeleteId != nil }, set: { v in if !v { pendingDeleteId = nil } })) {
            Button(L.cancel.localized, role: .cancel) { pendingDeleteId = nil }
            Button(L.delete.localized, role: .destructive) {
                if let id = pendingDeleteId {
                    Task { await viewModel.deleteAccount(id) }
                    pendingDeleteId = nil
                }
            }
        } message: {
            Text(L.personalDeleteConfirm.localized)
        }
    }
}

private struct AccountRow: View {
    var account: PersonalAccountRowViewData
    var onEdit: () -> Void
    var onArchive: () -> Void
    var onActivate: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(account.name)
                    .font(.headline)
                Spacer()
                if account.includeInNetWorth {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(.green)
                }
            }
            HStack {
                Text(account.typeDisplay)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(AmountFormatter.string(minorUnits: account.balanceMinorUnits,
                                            currency: account.currency,
                                            locale: Locale.current))
                    .font(.headline)
            }
        }
        .padding(.vertical, 6)
        .swipeActions {
            Button(L.edit.localized, action: onEdit).tint(Color.appTextPrimary)
            if account.status == .active {
                Button(L.personalArchive.localized, action: onArchive).tint(Color.appTextPrimary)
            } else {
                Button(L.personalActivate.localized, action: onActivate).tint(Color.appTextPrimary)
            }
            Button(role: .destructive, action: onDelete) {
                Label(L.delete.localized, systemImage: "trash")
            }
        }
        .contextMenu {
            Button(L.edit.localized, action: onEdit)
            if account.status == .active {
                Button(L.personalArchive.localized, action: onArchive)
            } else {
                Button(L.personalActivate.localized, action: onActivate)
            }
            Button(L.delete.localized, role: .destructive, action: onDelete)
        }
    }
}

struct PersonalAccountFormHost: View {
    @StateObject private var viewModel: PersonalAccountFormViewModel
    var onDismiss: () -> Void

    init(root: PersonalLedgerRootViewModel, accountId: UUID?, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: root.makeAccountFormViewModel(accountId: accountId))
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            PersonalAccountFormView(viewModel: viewModel, onDone: onDismiss)
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
    }
}

struct PersonalAccountFormView: View {
    @ObservedObject var viewModel: PersonalAccountFormViewModel
    var onDone: () -> Void
    @State private var balanceText: String
    @State private var creditLimitText: String
    @FocusState private var balanceFieldFocused: Bool

    init(viewModel: PersonalAccountFormViewModel, onDone: @escaping () -> Void) {
        self.viewModel = viewModel
        self.onDone = onDone
        if viewModel.draft.initialBalance == 0 {
            _balanceText = State(initialValue: "")
        } else {
            _balanceText = State(initialValue: NSDecimalNumber(decimal: viewModel.draft.initialBalance).stringValue)
        }
        if let limit = viewModel.draft.creditLimit {
            _creditLimitText = State(initialValue: NSDecimalNumber(decimal: limit).stringValue)
        } else {
            _creditLimitText = State(initialValue: "")
        }
    }

    var body: some View {
        Form {
            Section(header: Text(L.personalFieldName.localized)) {
                TextField(L.personalFieldName.localized, text: $viewModel.draft.name)
                Picker(L.personalAccountTypeLabel.localized, selection: $viewModel.draft.type) {
                    ForEach(PersonalAccountType.allCases, id: \.self) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                Picker(L.personalFieldCurrency.localized, selection: $viewModel.draft.currency) {
                    ForEach(CurrencyCode.allCases, id: \.self) { code in
                        Text(code.rawValue).tag(code)
                    }
                }
            }
            Section(header: Text(L.personalFieldBalance.localized)) {
                TextField(L.personalFieldBalance.localized, text: $balanceText)
                    .keyboardType(.decimalPad)
                    .focused($balanceFieldFocused)
                    .onChange(of: balanceText) { oldValue, newValue in
                        let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 2, locale: .current, oldValue: oldValue)
                        if validated != newValue { balanceText = validated }
                        let trimmed = validated.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            viewModel.draft.initialBalance = 0
                        } else if let decimal = NumberParsing.parseDecimal(trimmed) {
                            viewModel.draft.initialBalance = decimal
                        }
                    }
                Toggle(L.personalIncludeInNet.localized, isOn: $viewModel.draft.includeInNetWorth)
                    .tint(Color.appToggleOn)
                if viewModel.draft.type == .creditCard {
                    TextField(L.personalFieldCreditLimit.localized, text: $creditLimitText)
                        .keyboardType(.decimalPad)
                        .onChange(of: creditLimitText) { oldValue, newValue in
                            let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 2, locale: .current, oldValue: oldValue)
                            if validated != newValue { creditLimitText = validated }
                            let trimmed = validated.trimmingCharacters(in: .whitespacesAndNewlines)
                            if trimmed.isEmpty {
                                viewModel.draft.creditLimit = nil
                            } else if let decimal = NumberParsing.parseDecimal(trimmed) {
                                viewModel.draft.creditLimit = decimal
                            }
                        }
                }
                if viewModel.draft.id != nil {
                    Picker(L.personalAccountStatus.localized, selection: $viewModel.draft.status) {
                        Text(L.personalStatusActive.localized).tag(PersonalAccountStatus.active)
                        Text(L.personalStatusArchived.localized).tag(PersonalAccountStatus.archived)
                    }
                }
                TextField(L.personalFieldNote.localized, text: Binding($viewModel.draft.note, replacingNilWith: ""), axis: .vertical)
            }
        }
        .dismissKeyboardOnTap()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L.cancel.localized, action: onDone)
            }
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Button(L.save.localized) {
                        Task {
                            let success = await viewModel.submit()
                            if success { onDone() }
                        }
                    }
                }
            }
        }
        .alert(viewModel.errorMessage ?? "", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })) {
            Button(L.ok.localized, action: {})
        }
        .onAppear {
            if viewModel.draft.id == nil {
                DispatchQueue.main.async {
                    balanceFieldFocused = true
                }
            }
        }
        .onChange(of: viewModel.draft.type) { _, newValue in
            if newValue != .creditCard {
                creditLimitText = ""
                viewModel.draft.creditLimit = nil
            }
        }
    }
}

struct PersonalTransferFormHost: View {
    @StateObject private var viewModel: PersonalTransferFormViewModel
    var onDismiss: () -> Void

    init(root: PersonalLedgerRootViewModel, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: root.makeTransferFormViewModel())
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            PersonalTransferFormView(viewModel: viewModel, onDone: onDismiss)
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
    }
}

struct PersonalTransferFormView: View {
    @ObservedObject var viewModel: PersonalTransferFormViewModel
    var onDone: () -> Void

    var body: some View {
        Form {
            Section(header: Text(L.personalTransferAccounts.localized)) {
                Picker(L.personalTransferFrom.localized, selection: $viewModel.fromAccountId) {
                    ForEach(viewModel.accounts) { account in
                        Text(account.name).tag(account.remoteId as UUID?)
                    }
                }
                Picker(L.personalTransferTo.localized, selection: $viewModel.toAccountId) {
                    ForEach(viewModel.accounts) { account in
                        Text(account.name).tag(account.remoteId as UUID?)
                    }
                }
            }
            Section(header: Text(L.personalTransferAmount.localized)) {
                TextField(L.personalFieldAmount.localized, text: $viewModel.amountText)
                    .keyboardType(.decimalPad)
                    .onChange(of: viewModel.amountText) { oldValue, newValue in
                        let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 2, locale: .current, oldValue: oldValue)
                        if validated != newValue { viewModel.amountText = validated }
                    }
                TextField(L.personalFieldFXRate.localized,
                          text: $viewModel.fxRateText,
                          prompt: Text(viewModel.fxRatePlaceholder).foregroundStyle(.secondary))
                    .keyboardType(.decimalPad)
                    .onChange(of: viewModel.fxRateText) { oldValue, newValue in
                        let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 6, locale: .current, oldValue: oldValue)
                        if validated != newValue { viewModel.fxRateText = validated }
                    }
                    .disabled(!viewModel.fxRateEditable)
                    .allowsHitTesting(viewModel.fxRateEditable)
                    .opacity(viewModel.fxRateEditable ? 1 : 0.6)
                if viewModel.fxRateEditable {
                    HStack(spacing: 8) {
                        Text(viewModel.fxInfoText)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button(L.personalTransferInvert.localized) {
                            viewModel.invertFXRate()
                        }
                        .font(.caption)
                    }
                }
                TextField(L.personalTransferFee.localized,
                          text: $viewModel.feeText,
                          prompt: Text(viewModel.feePlaceholder).foregroundStyle(.secondary))
                    .keyboardType(.decimalPad)
                    .onChange(of: viewModel.feeText) { oldValue, newValue in
                        let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 2, locale: .current, oldValue: oldValue)
                        if validated != newValue { viewModel.feeText = validated }
                    }
                Picker(L.personalTransferFeeSide.localized, selection: $viewModel.selectedFeeSide) {
                    Text(L.personalTransferFeeFrom.localized).tag(PersonalTransferFeeSide.from)
                    Text(L.personalTransferFeeTo.localized).tag(PersonalTransferFeeSide.to)
                }
                Text(L.personalTransferFeeHint.localized)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                DatePicker(L.personalFieldDate.localized, selection: $viewModel.occurredAt, displayedComponents: [.date, .hourAndMinute])
                TextField(L.personalFieldNote.localized, text: $viewModel.note)
            }
        }
        .dismissKeyboardOnTap()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L.cancel.localized, action: onDone)
            }
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Button(L.save.localized) {
                        Task {
                            let success = await viewModel.submit()
                            if success { onDone() }
                        }
                    }
                }
            }
        }
        .alert(viewModel.errorMessage ?? "", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })) {
            Button(L.ok.localized, action: {})
        }
    }
}

struct PersonalStatsView: View {
    @ObservedObject var viewModel: PersonalStatsViewModel
    @State private var focus: Focus = .expense

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
                insightsSection
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
                                .fill(Color(.systemGray5))
                        )
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 32) {
                        donutView()
                            .frame(maxWidth: 220)
                        summaryDetails(isCompact: false)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    VStack(spacing: 24) {
                        donutView()
                            .frame(maxWidth: .infinity)
                        summaryDetails(isCompact: true)
                    }
                }
                .frame(minHeight: 280, alignment: .top)

                Divider()

                if filteredBreakdown.isEmpty {
                    Text(L.personalStatsEmpty.localized)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                } else {
                    VStack(spacing: 12) {
                        ForEach(filteredBreakdown) { item in
                            categoryRow(for: item)
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    @ViewBuilder
    private var insightsSection: some View {
        if focus == .expense && !viewModel.insights.isEmpty {
            statsContainer {
                VStack(alignment: .leading, spacing: 12) {
                    Text(L.personalStatsInsightsTitle.localized)
                        .font(.headline)
                    ForEach(viewModel.insights) { insight in
                        let streakText = L.personalStatsInsightStreak.localized(insight.increasingStreak)
                        let growthText = L.personalStatsInsightRecentGrowth.localized
                        let detailText = L.personalStatsInsightDetail.localized(
                            localizedCategoryName(insight.categoryKey),
                            streakText,
                            growthText,
                            formatPercent(insight.recentGrowthRate)
                        )
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Focus.expense.secondaryColor)
                                .padding(8)
                                .background(Focus.expense.secondaryColor.opacity(0.12), in: Circle())
                            Text(detailText)
                                .font(.callout)
                                .multilineTextAlignment(.leading)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.yellow.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
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
                            Label(code.rawValue, systemImage: "checkmark")
                        } else {
                            Text(code.rawValue)
                        }
                    }
                }
            } label: {
                Label(viewModel.selectedCurrency.rawValue, systemImage: "coloncurrencysign.circle")
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
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 4)
        )
    }

    private func statsContainer<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 20, content: content)
            .padding(.vertical, 22)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 12)
    }

    private func donutView() -> some View {
        ZStack {
            if filteredBreakdown.isEmpty {
                Circle()
                    .fill(Color(.systemGray5))
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
                        .foregroundStyle(categoryColor(for: item.categoryKey))
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

    private func summaryDetails(isCompact: Bool) -> some View {
        VStack(alignment: .leading, spacing: isCompact ? 18 : 22) {
            summaryTotalCard()

            if isCompact {
                VStack(spacing: 14) {
                    summaryChip(title: L.personalStatsFocusExpense.localized,
                                amount: totalExpense,
                                color: Focus.expense.accentColor)
                    summaryChip(title: L.personalStatsFocusIncome.localized,
                                amount: totalIncome,
                                color: Focus.income.accentColor)
                }
            } else {
                HStack(spacing: 16) {
                    summaryChip(title: L.personalStatsFocusExpense.localized,
                                amount: totalExpense,
                                color: Focus.expense.accentColor)
                    summaryChip(title: L.personalStatsFocusIncome.localized,
                                amount: totalIncome,
                                color: Focus.income.accentColor)
                }
            }

            if focus == .expense, let growth = viewModel.expenseGrowthRate {
                growthView(growth)
            }

            if focus == .expense, let structure = viewModel.structure, structure.total > 0 {
                structureView(structure)
            }
        }
    }

    private func summaryTotalCard() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(focus.localizedTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(formattedAmount(totalForFocus, currency: viewModel.selectedCurrency))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.65)

            Text(L.personalStatsRecordCount.localized(filteredBreakdown.reduce(0) { $0 + $1.transactionCount }))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.06), radius: 14, x: 0, y: 10)
        )
    }

    private func summaryChip(title: String, amount: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(color)
            Text(formattedAmount(amount, currency: viewModel.selectedCurrency))
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(Color.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(color.opacity(0.12))
        )
    }

    private func growthView(_ value: Double) -> some View {
        let up = value >= 0
        let arrow = up ? "arrow.up.right" : "arrow.down.right"
        let tint = up ? Color.red : Color.green
        return HStack(spacing: 8) {
            Image(systemName: arrow)
                .font(.caption.weight(.bold))
            Text("\(L.personalStatsExpenseGrowth.localized): \(formatPercent(value))")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(tint)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(tint.opacity(0.12), in: Capsule())
    }

    private func structureView(_ structure: PersonalSpendingStructure) -> some View {
        let essentialShare = structure.essentialShare
        let discretionaryShare = structure.discretionaryShare
        return VStack(alignment: .leading, spacing: 8) {
            Text(L.personalStatsStructureTitle.localized)
                .font(.subheadline.weight(.semibold))
            GeometryReader { proxy in
                let width = proxy.size.width
                let essentialWidth = width * CGFloat(max(min(essentialShare, 1), 0))
                let discretionaryWidth = width - essentialWidth
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    if essentialWidth > 0 {
                        Capsule()
                            .fill(Focus.expense.accentColor)
                            .frame(width: essentialWidth)
                    }
                    if discretionaryWidth > 0 {
                        Capsule()
                            .fill(Focus.expense.secondaryColor)
                            .frame(width: discretionaryWidth)
                            .offset(x: essentialWidth)
                    }
                }
            }
            .frame(height: 12)

            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Focus.expense.accentColor)
                    Text("\(L.personalStatsEssential.localized) · \(formatPercent(essentialShare))")
                }
                .foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(Focus.expense.secondaryColor)
                    Text("\(L.personalStatsDiscretionary.localized) · \(formatPercent(discretionaryShare))")
                }
                .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding(14)
        .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func categoryRow(for item: PersonalStatsCategoryShare) -> some View {
        let color = categoryColor(for: item.categoryKey)
        let share = totalForFocus > 0 ? Double(item.amountMinorUnits) / Double(totalForFocus) : 0
        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 46, height: 46)
                Image(systemName: iconForCategory(key: item.categoryKey))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(localizedCategoryName(item.categoryKey))
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

    private func categoryColor(for key: String) -> Color {
        let hash = key.unicodeScalars.reduce(into: UInt64(0)) { partial, scalar in
            partial = partial &* 31 &+ UInt64(scalar.value)
        }
        let index = Int(hash % UInt64(Self.categoryPalette.count))
        return Self.categoryPalette[index]
    }

    private static let categoryPalette: [Color] = [
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
}


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

private func formatPercent(_ v: Double) -> String {
    let f = NumberFormatter()
    f.numberStyle = .percent
    f.maximumFractionDigits = 1
    return f.string(from: NSNumber(value: v)) ?? String(format: "%.1f%%", v * 100)
}

private func localizedCategoryName(_ key: String) -> String {
    if let match = (expenseCategories + incomeCategories + feeCategories).first(where: { $0.key == key }) {
        return match.localizedName
    }
    return key
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

private enum ShareSheet {
    static func present(url: URL) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        root.present(controller, animated: true)
    }
}

// MARK: - Personal CSV Export UI

struct PersonalCSVExportView: View {
    @ObservedObject var root: PersonalLedgerRootViewModel
    @StateObject var viewModel: PersonalCSVExportViewModel
    @State private var showingRecordForm = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            PersonalCSVExportContent(viewModel: viewModel, store: root.store)
            FloatingActionButton(systemImage: "plus") {
                showingRecordForm = true
            }
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
        .navigationTitle(L.personalExportCSV.localized)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingRecordForm) {
            PersonalRecordFormHost(root: root, existing: nil) {
                showingRecordForm = false
                Task { await viewModel.refresh() }
            }
        }
    }
}

private struct PersonalCSVExportContent: View {
    @ObservedObject var viewModel: PersonalCSVExportViewModel
    let store: PersonalLedgerStore

    var body: some View {
        List {
            Section(header: Text(L.personalFilterTitle.localized)) {
                Picker(L.personalStatsPeriod.localized, selection: $viewModel.periodMode) {
                    Text(L.personalStatsMonth.localized).tag(PersonalCSVExportViewModel.PeriodMode.month)
                    Text(L.personalStatsQuarter.localized).tag(PersonalCSVExportViewModel.PeriodMode.quarter)
                    Text(L.personalStatsYear.localized).tag(PersonalCSVExportViewModel.PeriodMode.year)
                    Text(L.personalFilterTitle.localized).tag(PersonalCSVExportViewModel.PeriodMode.range)
                }
                .pickerStyle(.segmented)

                if viewModel.periodMode == .range {
                    DatePicker(L.personalFilterFrom.localized, selection: $viewModel.fromDate, displayedComponents: .date)
                    DatePicker(L.personalExportUntil.localized, selection: $viewModel.toDate, displayedComponents: .date)
                } else {
                    HStack(spacing: 8) {
                        Text(L.personalExportUntil.localized)
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $viewModel.anchorDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                        .labelsHidden()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(L.personalAccountsList.localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.activeAccounts) { account in
                                let selected = viewModel.selectedAccountIds.contains(account.remoteId)
                                Button(action: {
                                    if selected { viewModel.selectedAccountIds.remove(account.remoteId) }
                                    else { viewModel.selectedAccountIds.insert(account.remoteId) }
                                }) {
                                    Text(account.name)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Color.accentColor.opacity(0.2) : Color(.systemGray6)))
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(L.personalPrimaryCurrency.localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(Set(store.activeAccounts.map { $0.currency })).sorted { $0.rawValue < $1.rawValue }, id: \.self) { code in
                                let selected = viewModel.selectedCurrencies.contains(code)
                                Button(action: {
                                    if selected { viewModel.selectedCurrencies.remove(code) }
                                    else { viewModel.selectedCurrencies.insert(code) }
                                }) {
                                    Text(code.rawValue)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(RoundedRectangle(cornerRadius: 10).fill(selected ? Color.accentColor.opacity(0.2) : Color(.systemGray6)))
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section(header: Text(L.personalAccountsSummary.localized)) {
                let selectedIds = viewModel.selectedAccountIds
                let accounts = store.activeAccounts.filter { selectedIds.isEmpty || selectedIds.contains($0.remoteId) }
                if accounts.isEmpty {
                    Text(L.recordsEmpty.localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(accounts) { account in
                        HStack {
                            Text(account.name)
                                .font(.footnote)
                            Spacer()
                            Text(AmountFormatter.string(minorUnits: account.balanceMinorUnits,
                                                        currency: account.currency,
                                                        locale: Locale.current))
                                .font(.footnote)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section(header: Text(L.personalAllRecordsTitle.localized)) {
                if viewModel.records.isEmpty {
                    Text(L.recordsEmpty.localized)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.records) { record in
                        PersonalRecordRow(record: record,
                                          onTap: {},
                                          onEdit: {},
                                          onDelete: {},
                                          timestampText: record.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("", selection: $viewModel.sortMode) {
                        ForEach(PersonalAllRecordsViewModel.SortMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    do {
                        let url = try viewModel.exportCSV()
                        ShareSheet.present(url: url)
                    } catch { }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel(Text(L.personalExportCSV.localized))
            }
        }
    }
}
