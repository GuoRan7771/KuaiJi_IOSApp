//
//  OnboardingView.swift
//  KuaiJi
//
//  首次设置界面
//

import SwiftUI

struct OnboardingView: View {
    var onComplete: (String, String, CurrencyCode) -> Void
    
    @State private var name = ""
    @State private var selectedEmoji = "👤"
    @State private var selectedCurrency: CurrencyCode = .cny
    @State private var showError = false
    @State private var showAllEmojis = false
    
    // 所有 emoji 选项：黄色表情 + 职位 emoji
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
    
    private var isFormComplete: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()
                ScrollView {
                VStack(spacing: 24) {
                    // 标题和描述
                    VStack(spacing: 12) {
                        Text(L.onboardingTitle.localized)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.appLedgerContentText)
                        
                        Text(L.onboardingDescription.localized)
                            .font(.subheadline)
                            .foregroundStyle(Color.appLedgerContentText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)
                    
                    // 表单内容
                    VStack(spacing: 32) {
                        // 姓名输入
                        VStack(alignment: .leading, spacing: 12) {
                            Text(L.onboardingNameSection.localized)
                                .font(.headline)
                                .foregroundStyle(Color.appLedgerContentText)
                            
                            TextField(L.onboardingNamePlaceholder.localized, text: $name)
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal)
                            
                            Text(L.onboardingNameFooter.localized)
                                .font(.caption)
                                .foregroundStyle(Color.appLedgerContentText)
                                .padding(.horizontal)
                        }
                        
                        // 货币选择
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(L.onboardingCurrencySection.localized)
                                    .font(.headline)
                                    .foregroundStyle(Color.appLedgerContentText)
                                Spacer()
                                Picker("", selection: $selectedCurrency) {
                                    ForEach(CurrencyCode.allCases) { currency in
                                        Text(currency.displayLabel).tag(currency)
                                    }
                                }
                                .pickerStyle(.menu)
                                .labelsHidden()
                                .tint(Color.appTextPrimary)
                            }
                            .padding(.horizontal)
                            
                            Text(L.onboardingCurrencyFooter.localized)
                                .font(.caption)
                                .foregroundStyle(Color.appLedgerContentText)
                                .padding(.horizontal)
                        }
                        
                        // 头像选择
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(L.onboardingAvatarSection.localized)
                                    .font(.headline)
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
                            .padding(.horizontal)
                            
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
                                }
                            }
                            .padding(.horizontal)
                            
                            Text(L.onboardingAvatarFooter.localized)
                                .font(.caption)
                                .foregroundStyle(Color.appLedgerContentText)
                                .padding(.horizontal)
                        }
                    }
                    .padding(.horizontal)
                    
                    // 底部提示文字
                    Text(L.onboardingCompleteFooter.localized)
                        .font(.caption)
                        .foregroundStyle(Color.appLedgerContentText)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .dismissKeyboardOnTap()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmedName.isEmpty {
                            showError = true
                        } else {
                            onComplete(trimmedName, selectedEmoji, selectedCurrency)
                        }
                    } label: {
                        Text(L.onboardingStartButton.localized)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.appLedgerContentText)
                    }
                    .disabled(!isFormComplete)
                }
            }
            .interactiveDismissDisabled()
            .alert(L.onboardingErrorTitle.localized, isPresented: $showError) {
                Button(L.ok.localized, role: .cancel) { }
            } message: {
                Text(L.onboardingErrorMessage.localized)
            }
            .sheet(isPresented: $showAllEmojis) {
                AllEmojisSheet(selectedEmoji: $selectedEmoji, emojiOptions: emojiOptions)
            }
        }
        .background(Color.appBackground)
    }
}

// MARK: - 全部 Emoji 选择器
struct AllEmojisSheet: View {
    @Binding var selectedEmoji: String
    let emojiOptions: [String]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 16) {
                    ForEach(emojiOptions, id: \.self) { emoji in
                        Button {
                            selectedEmoji = emoji
                            dismiss()
                        } label: {
                            Text(emoji)
                                .font(.system(size: 40))
                                .frame(width: 55, height: 55)
                                .background(
                                    Circle()
                                        .fill(selectedEmoji == emoji ? Color.appSelection.opacity(0.2) : Color.secondary.opacity(0.1))
                                )
                                .overlay(
                                    Circle()
                                        .strokeBorder(selectedEmoji == emoji ? Color.appSelection : Color.clear, lineWidth: 2)
                                )
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(L.onboardingAllEmojis.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text(L.done.localized)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
    }
}
