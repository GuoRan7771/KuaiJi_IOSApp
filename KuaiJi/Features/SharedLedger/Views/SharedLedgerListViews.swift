//
//  SharedLedgerListViews.swift
//  KuaiJi
//

import SwiftUI

struct FriendListHost: View {
    @ObservedObject var viewModel: FriendListScreenModel
    @ObservedObject var rootViewModel: AppRootViewModel
    @State private var showingAddFriend = false
    @State private var showingMyQRCode = false
    @State private var showingScanner = false
    @State private var showingDuplicateAlert = false
    @State private var duplicateMessage = ""

    var body: some View {
        FriendListView(viewModel: viewModel)
            .navigationTitle(L.friendsTitle.localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            showingAddFriend = true
                        } label: {
                            Label(L.friendMenuManualInput.localized, systemImage: "keyboard")
                        }

                        Button {
                            showingMyQRCode = true
                        } label: {
                            Label(L.friendMenuMyQRCode.localized, systemImage: "qrcode")
                        }

                        Button {
                            showingScanner = true
                        } label: {
                            Label(L.friendMenuScanQRCode.localized, systemImage: "qrcode.viewfinder")
                        }
                    } label: {
                        Label(L.friendsAdd.localized, systemImage: "plus")
                    }
                    .tint(Color.appTextPrimary)
                }
            }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showingMyQRCode) {
                if let currentUser = rootViewModel.dataManager?.currentUser {
                    MyQRCodeView(userData: UserQRCodeData(
                        userId: currentUser.userId,
                        name: currentUser.name,
                        emoji: currentUser.avatarEmoji ?? "👤",
                        currency: currentUser.currency.rawValue
                    ))
                }
            }
            .sheet(isPresented: $showingScanner) {
                QRCodeScannerView { userData in
                    // 将扫描到的朋友信息添加到朋友列表
                    // 如果朋友已存在，会自动更新其最新信息
                    if let currencyCode = CurrencyCode(rawValue: userData.currency) {
                        let success = viewModel.addFriendFromQRCode(
                            userId: userData.userId,
                            named: userData.name,
                            emoji: userData.emoji,
                            currency: currencyCode
                        )
                        
                        if !success {
                            duplicateMessage = L.qrcodeCannotAddSelf.localized
                            showingDuplicateAlert = true
                        }
                    }
                }
            }
            .alert(L.qrcodeAlertTitle.localized, isPresented: $showingDuplicateAlert) {
                Button(L.ok.localized, role: .cancel) { }
            } message: {
                Text(duplicateMessage)
            }
            .background(Color.appBackground)
    }
}

struct LedgerListView<Model: LedgerListViewModelProtocol>: View {
    @ObservedObject var viewModel: Model
    @State private var pendingDeletion: LedgerSummaryViewData?
    @AppStorage("isArchivedLedgersExpanded") private var isArchivedLedgersExpanded = false

    var body: some View {
        List {
            Section(L.ledgersRecentUpdates.localized) {
                ForEach(viewModel.ledgers) { ledger in
                    NavigationLink(value: ledger) {
                        LedgerSummaryRow(ledger: ledger)
                    }
                    .accessibilityLabel("\(ledger.name), \(L.ledgersMemberCount.localized(ledger.memberCount)), \(L.ledgersOutstanding.localized(ledger.outstandingDisplay))")
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            viewModel.archiveLedger(id: ledger.id)
                        } label: {
                            Label(L.ledgersArchiveAction.localized, systemImage: "archivebox")
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            pendingDeletion = ledger
                        } label: {
                            Label(L.delete.localized, systemImage: "trash")
                        }
                    }
                }
                .onDelete { indexSet in
                    if let first = indexSet.first, viewModel.ledgers.indices.contains(first) {
                        pendingDeletion = viewModel.ledgers[first]
                    }
                }
            }
            if !viewModel.archivedLedgers.isEmpty {
                Section {
                    if isArchivedLedgersExpanded {
                        ForEach(viewModel.archivedLedgers) { ledger in
                            NavigationLink(value: ledger) {
                                LedgerSummaryRow(ledger: ledger, isArchived: true)
                            }
                            .accessibilityLabel("\(ledger.name), \(L.ledgersMemberCount.localized(ledger.memberCount)), \(L.ledgersOutstanding.localized(ledger.outstandingDisplay)), \(L.ledgersArchived.localized)")
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    viewModel.unarchiveLedger(id: ledger.id)
                                } label: {
                                    Label(L.ledgersUnarchiveAction.localized, systemImage: "arrow.uturn.left")
                                }
                                .tint(.green)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    pendingDeletion = ledger
                                } label: {
                                    Label(L.delete.localized, systemImage: "trash")
                                }
                            }
                        }
                        .onDelete { indexSet in
                            if let first = indexSet.first, viewModel.archivedLedgers.indices.contains(first) {
                                pendingDeletion = viewModel.archivedLedgers[first]
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text(L.ledgersArchived.localized)
                        Spacer()
                        Button {
                            withAnimation {
                                isArchivedLedgersExpanded.toggle()
                            }
                        } label: {
                            Text(isArchivedLedgersExpanded ? L.collapse.localized : L.expand.localized)
                                .font(.subheadline)
                                .foregroundStyle(Color.accentColor)
                                .textCase(nil)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .alert(L.ledgersDeleteConfirmTitle.localized, isPresented: Binding(get: { pendingDeletion != nil }, set: { newValue in
            if !newValue { pendingDeletion = nil }
        })) {
            Button(L.cancel.localized, role: .cancel) {
                pendingDeletion = nil
            }
            Button(L.delete.localized, role: .destructive) {
                if let ledger = pendingDeletion {
                    viewModel.deleteLedger(id: ledger.id)
                }
                pendingDeletion = nil
            }
        } message: {
            Text(L.ledgersDeleteConfirmMessage.localized)
        }
    }
}

struct FriendListView<Model: FriendListViewModelProtocol>: View {
    @ObservedObject var viewModel: Model
    @State private var editingFriend: MemberSummaryViewData?

    var body: some View {
        List {
            ForEach(viewModel.friends) { friend in
                HStack(spacing: 12) {
                    Text(friend.displayAvatar)
                        .font(.largeTitle)
                        .frame(width: 50, height: 50)
                        .background(Circle().fill(Color.secondary.opacity(0.1)))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(friend.name)
                            .font(.headline)
                        Text(L.profileCurrencyLabel.localized(friend.currency.rawValue))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        if let index = viewModel.friends.firstIndex(where: { $0.id == friend.id }) {
                            viewModel.deleteFriend(at: IndexSet(integer: index))
                        }
                    } label: {
                        Label(L.delete.localized, systemImage: "trash")
                    }
                    
                    Button {
                        editingFriend = friend
                    } label: {
                        Label(L.edit.localized, systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .sheet(item: $editingFriend) { friend in
            EditFriendSheet(viewModel: viewModel, friend: friend)
        }
    }
}

struct LedgerSummaryRow: View {
    var ledger: LedgerSummaryViewData
    var isArchived: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shared.with.you")
                .font(.title2)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(ledger.name)
                    .font(.headline)
                Text("\(L.ledgersMemberCount.localized(ledger.memberCount)) · \(L.ledgersOutstanding.localized(ledger.outstandingDisplay))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isArchived {
                Text(L.ledgersArchivedTag.localized)
                    .font(.caption2)
                    .foregroundStyle(Color.appSecondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.secondary.opacity(0.12)))
            }
            Text(ledger.currency.rawValue)
                .font(.caption)
                .padding(6)
                .background(Capsule().fill(Color.secondary.opacity(0.1)))
        }
        .padding(.vertical, 6)
    }
}
