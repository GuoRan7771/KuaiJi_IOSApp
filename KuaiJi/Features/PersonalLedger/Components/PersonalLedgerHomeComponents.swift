//
//  PersonalLedgerHomeComponents.swift
//  KuaiJi
//

import SwiftUI

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

struct AmountView: View {
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
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(AmountFormatter.string(minorUnits: record.amountMinorUnits,
                                            currency: record.currency,
                                            locale: Locale.current))
                    .foregroundStyle(record.amountIsPositive ? Color.appSuccess : Color.appDanger)
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
                    let categoryName = localizedCategoryName(tx.categoryKey, store: root.store)
                    DetailRow(title: L.personalDetailCategory.localized, value: categoryName)
                    DetailRow(title: L.personalDetailAccount.localized, value: root.store.account(with: tx.accountId)?.name ?? record.accountName)
                    let kindDisplay = PersonalRecordRowViewData(id: tx.remoteId,
                                                                categoryKey: tx.categoryKey,
                                                                categoryName: categoryName,
                                                                categoryColorHex: root.store.categoryColor(for: tx.categoryKey).toHexRGB(),
                                                                systemImage: root.store.categoryIcon(for: tx.categoryKey),
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
        .navigationTitle(latest != nil ? localizedCategoryName(latest!.categoryKey, store: root.store) : record.categoryName)
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

enum PersonalTransferEditSheet {
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
