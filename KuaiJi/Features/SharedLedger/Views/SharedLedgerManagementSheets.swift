//
//  SharedLedgerManagementSheets.swift
//  KuaiJi
//

import SwiftUI

struct AddFriendSheet<Model: FriendListViewModelProtocol>: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: Model
    @State private var name = ""
    @State private var selectedCurrency: CurrencyCode = .cny
    @State private var selectedEmoji = "👤"
    @State private var showAllEmojis = false
    
    // 所有 emoji 选项：黄色表情 + 职位 emoji（与 OnboardingView 一致）
    private let emojiOptions = [
        // 基础黄色表情
        "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "😉", "😊",
        "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙", "🥲", "😋", "😛", "😜",
        "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔", "🤐", "🤨", "😐", "😑", "😶",
        "😏", "😒", "🙄", "😬", "🤥", "😌", "😔", "😪", "🤤", "😴", "😷", "🤒",
        "🤕", "🤢", "🤮", "🤧", "🥵", "🥶", "😶‍🌫️", "🥴", "😵", "🤯", "🤠", "🥳",
        "🥸", "😎", "🤓", "🧐", "😕", "😟", "🙁", "😮", "😯", "😲", "😳", "🥺",
        "😦", "😧", "😨", "😰", "😥", "😢", "😭", "😱", "😖", "😣", "😞", "😓",
        "😩", "😫", "🥱", "😤", "😡", "😠", "🤬",
        // 职位和角色 emoji
        "👨‍⚕️", "👩‍⚕️", "👨‍🎓", "👩‍🎓", "👨‍🏫", "👩‍🏫", "👨‍⚖️", "👩‍⚖️", "👨‍🌾", "👩‍🌾",
        "👨‍🍳", "👩‍🍳", "👨‍🔧", "👩‍🔧", "👨‍🏭", "👩‍🏭", "👨‍💼", "👩‍💼", "👨‍🔬", "👩‍🔬",
        "👨‍💻", "👩‍💻", "👨‍🎤", "👩‍🎤", "👨‍🎨", "👩‍🎨", "👨‍✈️", "👩‍✈️", "👨‍🚀", "👩‍🚀",
        "👨‍🚒", "👩‍🚒", "👮‍♂️", "👮‍♀️", "🕵️‍♂️", "🕵️‍♀️", "💂‍♂️", "💂‍♀️", "👷‍♂️", "👷‍♀️",
        "🤴", "👸", "👳‍♂️", "👳‍♀️", "👲", "🧕", "🤵‍♂️", "🤵‍♀️", "👰‍♂️", "👰‍♀️",
        "🤰", "🤱", "👶", "🧒", "👦", "👧", "🧑", "👨", "👩", "🧓", "👴", "👵",
        // 超级英雄和幻想角色
        "🦸‍♂️", "🦸‍♀️", "🦹‍♂️", "🦹‍♀️", "🧙‍♂️", "🧙‍♀️", "🧚‍♂️", "🧚‍♀️", "🧛‍♂️", "🧛‍♀️",
        "🧜‍♂️", "🧜‍♀️", "🧝‍♂️", "🧝‍♀️", "🧞‍♂️", "🧞‍♀️", "🧟‍♂️", "🧟‍♀️",
        // 其他常用
        "👤", "👥", "🫂", "👣"
    ]
    
    // 默认显示的 emoji（前 12 个）
    private var defaultEmojis: [String] {
        Array(emojiOptions.prefix(12))
    }

    var body: some View {
        NavigationStack {
        Form {
                Section(L.friendsInfo.localized) {
                    TextField(L.friendsName.localized, text: $name)
                    Picker(L.friendsCurrency.localized, selection: $selectedCurrency) {
                        ForEach(CurrencyCode.allCases) { currency in
                            Text(currency.displayLabel).tag(currency)
                        }
                    }
                }
                
                Section {
                    VStack(spacing: 12) {
                        // 标题和"全部"按钮
                        HStack {
                            Text(L.friendsSelectAvatar.localized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Button {
                                showAllEmojis = true
                            } label: {
                                Text(L.all.localized)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appSelection)
                            }
                        }
                        
                        // Emoji 选择网格（默认显示前 12 个）
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(defaultEmojis, id: \.self) { emoji in
                                Button {
                                    selectedEmoji = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 32))
                                        .frame(width: 50, height: 50)
                                        .background(
                                            Circle()
                                                .fill(selectedEmoji == emoji ? Color.appSelection.opacity(0.2) : Color.secondary.opacity(0.1))
                                        )
                                        .overlay(
                                            Circle()
                                                .strokeBorder(selectedEmoji == emoji ? Color.appSelection : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(L.friendsAddTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel.localized) { dismiss() }
                    .tint(Color.appTextPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.save.localized) {
                        viewModel.addFriend(named: name, emoji: selectedEmoji, currency: selectedCurrency)
                        dismiss()
                    }
                    .tint(Color.appTextPrimary)
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showAllEmojis) {
                AllEmojisSheet(selectedEmoji: $selectedEmoji, emojiOptions: emojiOptions)
            }
        }
    }
}

struct EditFriendSheet<Model: FriendListViewModelProtocol>: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: Model
    let friend: MemberSummaryViewData
    @State private var name: String
    @State private var selectedCurrency: CurrencyCode
    @State private var selectedEmoji: String
    @State private var showAllEmojis = false
    
    // 所有 emoji 选项：黄色表情 + 职位 emoji（与 OnboardingView 一致）
    private let emojiOptions = [
        // 基础黄色表情
        "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "😉", "😊",
        "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙", "🥲", "😋", "😛", "😜",
        "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔", "🤐", "🤨", "😐", "😑", "😶",
        "😏", "😒", "🙄", "😬", "🤥", "😌", "😔", "😪", "🤤", "😴", "😷", "🤒",
        "🤕", "🤢", "🤮", "🤧", "🥵", "🥶", "😶‍🌫️", "🥴", "😵", "🤯", "🤠", "🥳",
        "🥸", "😎", "🤓", "🧐", "😕", "😟", "🙁", "😮", "😯", "😲", "😳", "🥺",
        "😦", "😧", "😨", "😰", "😥", "😢", "😭", "😱", "😖", "😣", "😞", "😓",
        "😩", "😫", "🥱", "😤", "😡", "😠", "🤬",
        // 职位和角色 emoji
        "👨‍⚕️", "👩‍⚕️", "👨‍🎓", "👩‍🎓", "👨‍🏫", "👩‍🏫", "👨‍⚖️", "👩‍⚖️", "👨‍🌾", "👩‍🌾",
        "👨‍🍳", "👩‍🍳", "👨‍🔧", "👩‍🔧", "👨‍🏭", "👩‍🏭", "👨‍💼", "👩‍💼", "👨‍🔬", "👩‍🔬",
        "👨‍💻", "👩‍💻", "👨‍🎤", "👩‍🎤", "👨‍🎨", "👩‍🎨", "👨‍✈️", "👩‍✈️", "👨‍🚀", "👩‍🚀",
        "👨‍🚒", "👩‍🚒", "👮‍♂️", "👮‍♀️", "🕵️‍♂️", "🕵️‍♀️", "💂‍♂️", "💂‍♀️", "👷‍♂️", "👷‍♀️",
        "🤴", "👸", "👳‍♂️", "👳‍♀️", "👲", "🧕", "🤵‍♂️", "🤵‍♀️", "👰‍♂️", "👰‍♀️",
        "🤰", "🤱", "👶", "🧒", "👦", "👧", "🧑", "👨", "👩", "🧓", "👴", "👵",
        // 超级英雄和幻想角色
        "🦸‍♂️", "🦸‍♀️", "🦹‍♂️", "🦹‍♀️", "🧙‍♂️", "🧙‍♀️", "🧚‍♂️", "🧚‍♀️", "🧛‍♂️", "🧛‍♀️",
        "🧜‍♂️", "🧜‍♀️", "🧝‍♂️", "🧝‍♀️", "🧞‍♂️", "🧞‍♀️", "🧟‍♂️", "🧟‍♀️",
        // 其他常用
        "👤", "👥", "🫂", "👣"
    ]
    
    // 默认显示的 emoji（前 12 个）
    private var defaultEmojis: [String] {
        Array(emojiOptions.prefix(12))
    }

    init(viewModel: Model, friend: MemberSummaryViewData) {
        self.viewModel = viewModel
        self.friend = friend
        _name = State(initialValue: friend.name)
        _selectedCurrency = State(initialValue: friend.currency)
        _selectedEmoji = State(initialValue: friend.avatarEmoji ?? "👤")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L.friendsInfo.localized) {
                    TextField(L.friendsName.localized, text: $name)
                    Picker(L.friendsCurrency.localized, selection: $selectedCurrency) {
                        ForEach(CurrencyCode.allCases) { currency in
                            Text(currency.displayLabel).tag(currency)
                        }
                    }
                }
                
                Section {
                    VStack(spacing: 12) {
                        // 标题和"全部"按钮
                        HStack {
                            Text(L.friendsSelectAvatar.localized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Button {
                                showAllEmojis = true
                            } label: {
                                Text(L.all.localized)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appSelection)
                            }
                        }
                        
                        // Emoji 选择网格（默认显示前 12 个）
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(defaultEmojis, id: \.self) { emoji in
                                Button {
                                    selectedEmoji = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 32))
                                        .frame(width: 50, height: 50)
                                        .background(
                                            Circle()
                                                .fill(selectedEmoji == emoji ? Color.appSelection.opacity(0.2) : Color.secondary.opacity(0.1))
                                        )
                                        .overlay(
                                            Circle()
                                                .strokeBorder(selectedEmoji == emoji ? Color.appSelection : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(L.friendsEditTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel.localized) { dismiss() }
                    .tint(Color.appTextPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.save.localized) {
                        viewModel.updateFriend(id: friend.id, name: name, currency: selectedCurrency, emoji: selectedEmoji)
                        dismiss()
                    }
                    .tint(Color.appTextPrimary)
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showAllEmojis) {
                AllEmojisSheet(selectedEmoji: $selectedEmoji, emojiOptions: emojiOptions)
            }
        }
    }
}

struct CreateLedgerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: LedgerListScreenModel
    @State private var ledgerName = ""
    @State private var selectedCurrency: CurrencyCode = .cny
    @State private var selectedMemberIds: Set<UUID> = []

    var body: some View {
        NavigationStack {
            Form {
                Section(L.createLedgerInfo.localized) {
                    TextField(L.createLedgerName.localized, text: $ledgerName)
                    Picker(L.createLedgerCurrency.localized, selection: $selectedCurrency) {
                        ForEach(CurrencyCode.allCases) { currency in
                            Text(currency.displayLabel).tag(currency)
                        }
                    }
                }
                
                Section {
                    HStack {
                        Text(viewModel.currentUser.displayAvatar)
                            .font(.title2)
                        Text(L.createLedgerMe.localized)
                            .font(.headline)
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                } header: {
                    Text(L.createLedgerMembers.localized)
                } footer: {
                    Text(L.createLedgerSelectedCount.localized(selectedMemberIds.count + 1))
                }
                
                Section(L.createLedgerSelectFriends.localized) {
                    ForEach(viewModel.availableMembers) { member in
                        Button {
                            if selectedMemberIds.contains(member.id) {
                                selectedMemberIds.remove(member.id)
                            } else {
                                selectedMemberIds.insert(member.id)
                            }
                        } label: {
                    HStack {
                                Text(member.displayAvatar)
                                    .font(.title2)
                                Text(member.name)
                                    .foregroundStyle(Color.appTextPrimary)
                        Spacer()
                                if selectedMemberIds.contains(member.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                    }
                }
            }
        }
    }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(L.createLedgerTitle.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel.localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.createLedgerCreate.localized) {
                        var memberIds = Array(selectedMemberIds)
                        memberIds.append(viewModel.currentUser.id)
                        viewModel.createLedger(name: ledgerName, memberIds: memberIds, currency: selectedCurrency)
                        dismiss()
                    }
                    .disabled(ledgerName.isEmpty || selectedMemberIds.count < 1)
                }
            }
        }
    }
}

// MARK: - 个人信息编辑视图

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    let currentUser: UserProfile
    let onSave: (String, String, CurrencyCode) -> Void
    
    @State private var name: String
    @State private var selectedEmoji: String
    @State private var selectedCurrency: CurrencyCode
    @State private var showAllEmojis = false
    
    // 所有 emoji 选项：黄色表情 + 职位 emoji（与 OnboardingView 一致）
    private let emojiOptions = [
        // 基础黄色表情
        "😀", "😃", "😄", "😁", "😆", "😅", "🤣", "😂", "🙂", "🙃", "😉", "😊",
        "😇", "🥰", "😍", "🤩", "😘", "😗", "😚", "😙", "🥲", "😋", "😛", "😜",
        "🤪", "😝", "🤑", "🤗", "🤭", "🤫", "🤔", "🤐", "🤨", "😐", "😑", "😶",
        "😏", "😒", "🙄", "😬", "🤥", "😌", "😔", "😪", "🤤", "😴", "😷", "🤒",
        "🤕", "🤢", "🤮", "🤧", "🥵", "🥶", "😶‍🌫️", "🥴", "😵", "🤯", "🤠", "🥳",
        "🥸", "😎", "🤓", "🧐", "😕", "😟", "🙁", "😮", "😯", "😲", "😳", "🥺",
        "😦", "😧", "😨", "😰", "😥", "😢", "😭", "😱", "😖", "😣", "😞", "😓",
        "😩", "😫", "🥱", "😤", "😡", "😠", "🤬",
        // 职位和角色 emoji
        "👨‍⚕️", "👩‍⚕️", "👨‍🎓", "👩‍🎓", "👨‍🏫", "👩‍🏫", "👨‍⚖️", "👩‍⚖️", "👨‍🌾", "👩‍🌾",
        "👨‍🍳", "👩‍🍳", "👨‍🔧", "👩‍🔧", "👨‍🏭", "👩‍🏭", "👨‍💼", "👩‍💼", "👨‍🔬", "👩‍🔬",
        "👨‍💻", "👩‍💻", "👨‍🎤", "👩‍🎤", "👨‍🎨", "👩‍🎨", "👨‍✈️", "👩‍✈️", "👨‍🚀", "👩‍🚀",
        "👨‍🚒", "👩‍🚒", "👮‍♂️", "👮‍♀️", "🕵️‍♂️", "🕵️‍♀️", "💂‍♂️", "💂‍♀️", "👷‍♂️", "👷‍♀️",
        "🤴", "👸", "👳‍♂️", "👳‍♀️", "👲", "🧕", "🤵‍♂️", "🤵‍♀️", "👰‍♂️", "👰‍♀️",
        "🤰", "🤱", "👶", "🧒", "👦", "👧", "🧑", "👨", "👩", "🧓", "👴", "👵",
        // 超级英雄和幻想角色
        "🦸‍♂️", "🦸‍♀️", "🦹‍♂️", "🦹‍♀️", "🧙‍♂️", "🧙‍♀️", "🧚‍♂️", "🧚‍♀️", "🧛‍♂️", "🧛‍♀️",
        "🧜‍♂️", "🧜‍♀️", "🧝‍♂️", "🧝‍♀️", "🧞‍♂️", "🧞‍♀️", "🧟‍♂️", "🧟‍♀️",
        // 其他常用
        "👤", "👥", "🫂", "👣"
    ]
    
    // 默认显示的 emoji（前 12 个）
    private var defaultEmojis: [String] {
        Array(emojiOptions.prefix(12))
    }
    
    init(currentUser: UserProfile, onSave: @escaping (String, String, CurrencyCode) -> Void) {
        self.currentUser = currentUser
        self.onSave = onSave
        _name = State(initialValue: currentUser.name)
        _selectedEmoji = State(initialValue: currentUser.avatarEmoji ?? "👤")
        _selectedCurrency = State(initialValue: currentUser.currency)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L.profileNamePlaceholder.localized, text: $name)
                        .font(.body)
                } header: {
                    Text(L.profileName.localized)
                } footer: {
                    Text(L.profileNameFooter.localized)
                        .font(.caption)
                }
                
                Section {
                    Picker(selection: $selectedCurrency) {
                        ForEach(CurrencyCode.allCases) { currency in
                            Text(currency.displayLabel).tag(currency)
                        }
                    } label: {
                        Text(L.profileCurrencyPicker.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text(L.profileCurrency.localized)
                }
                
                Section {
                    VStack(spacing: 16) {
                        // 当前选中的头像预览
                        HStack {
                            Text(L.profileCurrentAvatar.localized)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(selectedEmoji)
                                .font(.system(size: 50))
                                .frame(width: 70, height: 70)
                                .background(
                                    Circle()
                                        .fill(Color.appSelection.opacity(0.1))
                                )
                        }
                        .padding(.vertical, 8)
                        
                        Divider()
                        
                        // 标题和"全部"按钮
                        HStack {
                            Text(L.onboardingAvatarSection.localized)
                                .font(.subheadline)
                                .foregroundStyle(Color.appLedgerContentText)
                            
                            Spacer()
                            
                            Button {
                                showAllEmojis = true
                            } label: {
                                Text(L.all.localized)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.appLedgerContentText)
                            }
                        }
                        
                        // Emoji 选择网格（默认显示前 12 个）
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                            ForEach(defaultEmojis, id: \.self) { emoji in
                                Button {
                                    selectedEmoji = emoji
                                } label: {
                                    Text(emoji)
                                        .font(.system(size: 32))
                                        .frame(width: 50, height: 50)
                                        .background(
                                            Circle()
                                                .fill(selectedEmoji == emoji ? Color.appSelection.opacity(0.2) : Color.secondary.opacity(0.1))
                                        )
                                        .overlay(
                                            Circle()
                                                .strokeBorder(selectedEmoji == emoji ? Color.appSelection : Color.clear, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text(L.profileAvatar.localized)
                } footer: {
                    Text(L.profileAvatarFooter.localized)
                        .font(.caption)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(L.profileEdit.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel.localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.save.localized) {
                        onSave(name, selectedEmoji, selectedCurrency)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .sheet(isPresented: $showAllEmojis) {
                AllEmojisSheet(selectedEmoji: $selectedEmoji, emojiOptions: emojiOptions)
            }
        }
    }
}
