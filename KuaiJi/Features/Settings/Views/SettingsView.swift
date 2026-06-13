//
//  SettingsView.swift
//  KuaiJi
//
//  Settings screen, data management, and related navigation.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct SettingsView<Model: SettingsViewModelProtocol>: View {
    @ObservedObject var viewModel: Model
    @ObservedObject var rootViewModel: AppRootViewModel
    @ObservedObject var personalSettingsViewModel: PersonalLedgerSettingsViewModel
    @ObservedObject var personalLedgerRoot: PersonalLedgerRootViewModel
    @EnvironmentObject var appState: AppState
    @AppStorage("theme") private var theme = "default"
    @State private var showingContactSheet = false
    @State private var showingClearDataAlert = false
    @State private var showingProfileEdit = false
    @State private var showingGuide = false
    @State private var navigateToUsageGuide = false
    @State private var navigateToPersonalAccounts = false
    @State private var navigateToPersonalCSVExport = false
    @State private var navigateToTemplates = false
    @State private var navigateToPersonalCategories = false
    @State private var showingImportPicker = false
    @State private var showingImportConfirmation = false
    @State private var pendingImportURL: URL?
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingPersonalExportError = false
    @State private var showingPersonalClearAlert = false
    @State private var showingEraseAbsolutelyAllAlert = false
    @State private var quickActionSelection: QuickActionSelection = .none
    @State private var showingSharedCSVPicker = false
    @State private var showingSupport = false

    private enum QuickActionSelection: Hashable, Identifiable {
        case none
        case shared(UUID)
        case personal

        var id: String {
            switch self {
            case .none: return "none"
            case .personal: return "personal"
            case .shared(let id): return id.uuidString
            }
        }
    }

    private func selection(from target: QuickActionTarget?) -> QuickActionSelection {
        switch target {
        case .shared(let id): return .shared(id)
        case .personal: return .personal
        case .none: return .none
        }
    }

    private enum SharedCSVExportError: LocalizedError {
        case ledgerMissing

        var errorDescription: String? {
            switch self {
            case .ledgerMissing:
                return L.settingsExportSharedCSVNotFound.localized
            }
        }
    }

    private enum SettingsScrollTarget: Hashable {
        case dataManagement
    }
    var body: some View {
        ScrollViewReader { proxy in
            Form {
            // 个人信息
            Section {
                if let currentUser = viewModel.getCurrentUser() {
                    Button {
                        showingProfileEdit = true
                    } label: {
                        HStack(spacing: 12) {
                            Text(currentUser.avatarEmoji ?? "👤")
                                .font(.largeTitle)
                                .frame(width: 50, height: 50)
                                .background(Circle().fill(Color.secondary.opacity(0.1)))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(currentUser.name)
                                    .font(.headline)
                                    .foregroundStyle(Color.appTextPrimary)
                                Text(L.profileUserIdLabel.localized(currentUser.userId))
                                    .appSecondaryTextStyle()
                                Text(L.profileCurrencyLabel.localized(currentUser.currency.rawValue))
                                    .appSecondaryTextStyle()
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.appSecondaryText)
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text(L.profileTitle.localized)
            } footer: {
                Text(L.profileViewInfo.localized)
                    .appSecondaryTextStyle()
            }
            
            Section(L.settingsInterfaceDisplay.localized) {
                Button {
                    openSystemSettings()
                } label: {
                    HStack {
                        Text(L.settingsLanguage.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }

                Picker(selection: $theme) {
                    Text(L.themeDefault.localized).tag("default")
                    Text(L.themeForest.localized).tag("forest")
                    Text(L.themePeach.localized).tag("peach")
                    Text(L.themeLavender.localized).tag("lavender")
                    Text(L.themeAlps.localized).tag("alps")
                    Text(L.themeMorandi.localized).tag("morandi")
                    Text(L.themeChristmas.localized).tag("christmas")
                } label: {
                    Text(L.settingsColorScheme.localized)
                        .foregroundStyle(Color.appLedgerContentText)
                }
                .tint(Color.appToggleOn)
                Toggle(L.settingsShowSharedLedger.localized, isOn: $appState.showSharedLedgerTab)
                    .tint(Color.appToggleOn)
                    .foregroundStyle(Color.appLedgerContentText)
                
                Toggle(L.settingsShowPersonalLedger.localized, isOn: $appState.showPersonalLedgerTab)
                    .tint(Color.appToggleOn)
                    .foregroundStyle(Color.appLedgerContentText)
                
                HStack {
                    Text(L.settingsSharedLanding.localized)
                        .foregroundStyle(Color.appLedgerContentText)
                    Spacer()
                    Picker(selection: Binding(get: {
                        switch appState.getSharedLandingPreference() {
                        case .list: return "list"
                        case .ledger(let id): return id.uuidString
                        }
                    }, set: { (raw: String) in
                        if raw == "list" {
                            appState.setSharedLandingPreference(.list)
                        } else if let id = UUID(uuidString: raw) {
                            appState.setSharedLandingPreference(.ledger(id))
                        }
                    })) {
                        Text(L.settingsSharedLandingList.localized).tag("list")
                        ForEach(rootViewModel.ledgerSummaries, id: \.id) { ledger in
                            Text(ledger.name).tag(ledger.id.uuidString)
                        }
                    } label: { EmptyView() }
                    .pickerStyle(.menu)
                    .tint(Color.appToggleOn)
                    .accessibilityIdentifier("settings.sharedLandingPicker")
                }
            }
            
            // 快速记账默认账本设置
            Section {
                Picker(selection: $quickActionSelection) {
                    Text(L.settingsDefaultLedgerNone.localized)
                        .tag(QuickActionSelection.none)
                    Text(L.settingsQuickActionPersonal.localized)
                        .tag(QuickActionSelection.personal)
                    ForEach(rootViewModel.ledgerSummaries, id: \.id) { ledger in
                        Text(ledger.name)
                            .tag(QuickActionSelection.shared(ledger.id))
                    }
                } label: {
                    Text(L.settingsDefaultLedger.localized)
                        .foregroundStyle(Color.appLedgerContentText)
                }
                .onChangeCompat(of: quickActionSelection) {
                    switch quickActionSelection {
                    case .none:
                        appState.setQuickActionTarget(nil)
                    case .personal:
                        appState.setQuickActionTarget(.personal)
                    case .shared(let id):
                        appState.setQuickActionTarget(.shared(id))
                    }
                }
                .tint(Color.appToggleOn)
            } header: {
                Text(L.settingsQuickActionSection.localized)
            } footer: {
                Text(L.settingsDefaultLedgerDesc.localized)
                    .appSecondaryTextStyle()
            }
            
            // 个人账本设置
            Section {
                Toggle(L.personalFeeInclude.localized, isOn: $personalSettingsViewModel.countFeeInStats)
                    .tint(Color.appToggleOn)
                    .foregroundStyle(Color.appLedgerContentText)
                    .onChangeCompat(of: personalSettingsViewModel.countFeeInStats) {
                        Task { await personalSettingsViewModel.save() }
                    }
                Button {
                    navigateToPersonalAccounts = true
                } label: {
                    HStack {
                        Text(L.personalAccountsManage.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }
                Button {
                    navigateToTemplates = true
                } label: {
                    HStack {
                        Text(L.personalTemplatesTitle.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }
                Button {
                    navigateToPersonalCategories = true
                } label: {
                    HStack {
                        Text(L.personalCategoriesManage.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }
            } header: {
                Text(L.personalSettingsTitle.localized)
            }

            Section(L.settingsAbout.localized) {
                Button {
                    showingGuide = true
                } label: {
                    HStack {
                        Text(L.settingsGuide.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }
                Button {
                    navigateToUsageGuide = true
                } label: {
                    HStack {
                        Text(L.settingsUsageGuide.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }

                Button {
                    showingSupport = true
                } label: {
                    HStack {
                        Text(L.settingsSupportMe.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(Color.appToggleOn)
                    }
                }

                Button {
                    AppReviewManager.requestInAppReview()
                } label: {
                    HStack {
                        Text(L.settingsRateApp.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(Color.appToggleOn)
                    }
                }

                Button {
                    showingContactSheet = true
                } label: {
                    HStack {
                        Text(L.settingsContactMe.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }

                Button {
                    openPrivacySupport()
                } label: {
                    HStack {
                        Text(L.contactSupport.localized)
                            .foregroundStyle(Color.appLedgerContentText)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }

                // 版本信息
                HStack {
                    Text(L.settingsVersion.localized)
                        .foregroundStyle(Color.appLedgerContentText)
                    Spacer()
                    Text(versionString())
                        .foregroundStyle(Color.appLedgerContentText)
                }
            }

            // 数据管理
            Section {
                Button {
                    exportData()
                } label: {
                    HStack {
                        Text(L.settingsExportData.localized)
                            .foregroundStyle(Color.appTextPrimary)
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }

                Button {
                    showingImportPicker = true
                } label: {
                    HStack {
                        Text(L.settingsImportData.localized)
                            .foregroundStyle(Color.appTextPrimary)
                        Spacer()
                        Image(systemName: "square.and.arrow.down")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }

                Button {
                    if rootViewModel.ledgerSummaries.isEmpty {
                        alertTitle = L.settingsExportSharedCSVEmptyTitle.localized
                        alertMessage = L.settingsExportSharedCSVEmptyMessage.localized
                        showingAlert = true
                    } else {
                        showingSharedCSVPicker = true
                    }
                } label: {
                    HStack {
                        Text(L.settingsExportSharedCSV.localized)
                            .foregroundStyle(Color.appTextPrimary)
                        Spacer()
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }

                Button {
                    navigateToPersonalCSVExport = true
                } label: {
                    HStack {
                        Text(L.personalExportCSV.localized)
                            .foregroundStyle(Color.appTextPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.appSecondaryText)
                    }
                }
            } header: {
                Text(L.settingsDataSection.localized)
            } footer: {
                Text(L.settingsExportDataDesc.localized)
                    .appSecondaryTextStyle()
            }
            .id(SettingsScrollTarget.dataManagement)
            .confirmationDialog(L.settingsExportSharedCSV.localized, isPresented: $showingSharedCSVPicker, titleVisibility: .visible) {
                ForEach(rootViewModel.ledgerSummaries, id: \.id) { ledger in
                    Button(ledger.name) {
                        exportSharedLedgerCSV(for: ledger)
                    }
                }
                Button(L.cancel.localized, role: .cancel) { }
            }

            Section {
                Button(role: .destructive) {
                    showingClearDataAlert = true
                } label: {
                    Text(L.settingsClearData.localized)
                        .frame(maxWidth: .infinity)
                }
            } footer: {
                Text(L.settingsClearDataWarning.localized)
                    .appSecondaryTextStyle()
            }

            Section {
                Button(role: .destructive) {
                    showingPersonalClearAlert = true
                } label: {
                    Text(L.personalClearData.localized)
                        .frame(maxWidth: .infinity)
                }
            } footer: {
                Text(L.personalClearHint.localized)
                    .appSecondaryTextStyle()
            }

            // 彻底抹除所有数据（共享+个人+设置）
            Section {
                Button(role: .destructive) {
                    showingEraseAbsolutelyAllAlert = true
                } label: {
                    Text(L.eraseAllData.localized)
                        .frame(maxWidth: .infinity)
                }
            } footer: {
                Text(L.eraseAllDataWarning.localized)
                    .appSecondaryTextStyle()
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationDestination(isPresented: $navigateToUsageGuide) {
            UsageGuideView()
        }
        .navigationDestination(isPresented: $navigateToPersonalAccounts) {
            PersonalAccountsView(root: personalLedgerRoot, viewModel: personalLedgerRoot.makeAccountsViewModel())
        }
        .navigationDestination(isPresented: $navigateToPersonalCSVExport) {
            PersonalCSVExportView(root: personalLedgerRoot, viewModel: personalLedgerRoot.makeCSVExportViewModel())
        }
        .navigationDestination(isPresented: $navigateToTemplates) {
            PersonalRecordTemplatesView(root: personalLedgerRoot, viewModel: personalLedgerRoot.makeTemplatesViewModel())
        }
        .navigationDestination(isPresented: $navigateToPersonalCategories) {
            PersonalCategorySettingsView(viewModel: personalLedgerRoot.makeCategorySettingsViewModel())
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .navigationTitle(L.settingsTitle.localized)
        .onChangeCompat(of: appState.settingsDeepLink) {
            handleSettingsDeepLink(using: proxy)
        }
        .onAppear {
            // 初始化快速操作目标
            quickActionSelection = selection(from: appState.getQuickActionTarget())
            handleSettingsDeepLink(using: proxy)
        }
        .sheet(isPresented: $showingContactSheet) {
            ContactView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSupport) {
            SupportMeView()
                .presentationDetents([.fraction(0.67), .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingProfileEdit) {
            if let currentUser = viewModel.getCurrentUser() {
                ProfileEditView(currentUser: currentUser) { name, emoji, currency in
                    viewModel.updateUserProfile(name: name, emoji: emoji, currency: currency)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .sheet(isPresented: $showingGuide) {
            WelcomeGuideView {
                showingGuide = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openPersonalTemplates)) { _ in
            navigateToTemplates = true
        }
        .alert(L.settingsConfirmDelete.localized, isPresented: $showingClearDataAlert) {
            Button(L.cancel.localized, role: .cancel) { }
            Button(L.delete.localized, role: .destructive) {
                viewModel.clearAllData()
                // 清除数据后，检查并重新显示首次设置界面
                appState.checkOnboardingStatus()
            }
        } message: {
            Text(L.settingsDeleteMessage.localized)
        }
        .alert(L.eraseAllConfirmTitle.localized, isPresented: $showingEraseAbsolutelyAllAlert) {
            Button(L.cancel.localized, role: .cancel) { }
            Button(L.delete.localized, role: .destructive) {
                viewModel.eraseAbsolutelyAll()
            }
        } message: {
            Text(L.eraseAllConfirmMessage.localized)
        }
        .alert(L.settingsImportConfirmTitle.localized, isPresented: $showingImportConfirmation) {
            Button(L.cancel.localized, role: .cancel) {
                pendingImportURL = nil
            }
            Button(L.settingsImportConfirmButton.localized, role: .destructive) {
                performImport()
            }
        } message: {
            Text(L.settingsImportConfirmMessage.localized)
        }
        .alert(L.personalExportFailed.localized, isPresented: $showingPersonalExportError) {
            Button(L.ok.localized, action: {})
        }
        .alert(L.personalClearConfirmTitle.localized, isPresented: $showingPersonalClearAlert) {
            Button(L.cancel.localized, role: .cancel) { }
            Button(L.personalClearData.localized, role: .destructive) {
                clearPersonalData()
            }
        } message: {
            Text(L.personalClearConfirmMessage.localized)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button(L.ok.localized, role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
        .fileImporter(isPresented: $showingImportPicker, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                pendingImportURL = url
                showingImportConfirmation = true
            case .failure(let error):
                alertTitle = L.settingsImportError.localized
                alertMessage = error.localizedDescription
                showingAlert = true
            }
        }
        }
    }
    
    private func handleSettingsDeepLink(using proxy: ScrollViewProxy) {
        guard let deepLink = appState.settingsDeepLink else { return }
        switch deepLink {
        case .dataManagement:
            withAnimation(.easeInOut) {
                proxy.scrollTo(SettingsScrollTarget.dataManagement, anchor: .top)
            }
        }
        appState.settingsDeepLink = nil
    }
    
    private func exportSharedLedgerCSV(for ledger: LedgerSummaryViewData) {
        do {
            let url = try makeSharedLedgerCSV(for: ledger)
            presentShare(url: url)
        } catch {
            alertTitle = L.settingsExportError.localized
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }

    private func makeSharedLedgerCSV(for ledger: LedgerSummaryViewData) throws -> URL {
        guard let info = rootViewModel.ledgerInfos[ledger.id] else {
            throw SharedCSVExportError.ledgerMissing
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        var lines: [String] = ["日期,标题,金额,币种,类别,付款人,参与者,备注"]
        let sortedExpenses = info.expenses.sorted { $0.date > $1.date }
        for expense in sortedExpenses {
            let totalMinor = expense.amountMinorUnits + expense.metadata.tipMinorUnits + expense.metadata.taxMinorUnits
            let amount = SettlementMath.decimal(fromMinorUnits: totalMinor, scale: 2)
            let payerName = rootViewModel.member(with: expense.payerId)?.name ?? L.defaultUnknownMember.localized
            let categoryName = expense.category.displayName
            let dateString = formatter.string(from: expense.date)
            let participants = expense.participants.map { share -> String in
                let name = rootViewModel.member(with: share.userId)?.name ?? L.defaultUnknownMember.localized
                return name
                    .replacingOccurrences(of: ",", with: " ")
                    .replacingOccurrences(of: "\n", with: " ")
            }.joined(separator: ";")
            let displayTitle = rootViewModel.resolvedTitle(for: expense)
            let sanitizedTitle = displayTitle
                .replacingOccurrences(of: ",", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
            let sanitizedCategory = categoryName
                .replacingOccurrences(of: ",", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
            let sanitizedPayer = payerName
                .replacingOccurrences(of: ",", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
            let sanitizedNote = expense.note
                .replacingOccurrences(of: ",", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
            lines.append("\(dateString),\(sanitizedTitle),\(amount),\(info.currency.rawValue),\(sanitizedCategory),\(sanitizedPayer),\(participants),\(sanitizedNote)")
        }

        let csv = lines.joined(separator: "\n") + "\n"
        let safeName = ledger.name.isEmpty ? "Ledger" : ledger.name.replacingOccurrences(of: " ", with: "_")
        let filename = "SharedLedger-\(safeName)-\(UUID().uuidString).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func exportPersonalCSV() throws -> URL {
        let records = try personalLedgerRoot.store.records(filter: PersonalRecordFilter())
        var lines: [String] = ["日期,账户,类型,分类,金额,币种,备注"]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        for record in records {
            let dateString = formatter.string(from: record.occurredAt)
            let typeString: String
            switch record.kind {
            case .income: typeString = "Income"
            case .expense: typeString = "Expense"
            case .fee: typeString = "Fee"
            }
            let account = personalLedgerRoot.store.account(with: record.accountId)
            let accountName = account?.name ?? ""
            let note = record.note.replacingOccurrences(of: ",", with: " ")
            let amount = SettlementMath.decimal(fromMinorUnits: record.amountMinorUnits, scale: 2)
            let currencyCode = account?.currency.rawValue ?? personalLedgerRoot.store.safePrimaryDisplayCurrency().rawValue
            lines.append("\(dateString),\(accountName),\(typeString),\(record.categoryKey),\(amount),\(currencyCode),\(note)")
        }
        let csv = lines.joined(separator: "\n") + "\n"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PersonalLedger-\(UUID().uuidString).csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func presentShare(url: URL) {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = scene.windows.first?.rootViewController else { return }
        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = rootVC.view
        rootVC.present(controller, animated: true)
    }

    private func clearPersonalData() {
        do {
            try personalLedgerRoot.store.clearAllPersonalData()
            alertTitle = L.personalClearSuccess.localized
            alertMessage = L.personalClearSuccessMessage.localized
            showingAlert = true
        } catch {
            alertTitle = L.personalClearFailed.localized
            alertMessage = error.localizedDescription
            showingAlert = true
        }
    }

    private func exportData() {
        let visibility = FeatureVisibilitySnapshot(showSharedAndFriends: appState.showSharedLedgerTab,
                                                   showPersonal: appState.showPersonalLedgerTab,
                                                   quickAction: appState.getQuickActionTarget())
        if let exportURL = viewModel.exportFullData(personalStore: personalLedgerRoot.store, visibility: visibility) {
            // 使用 UIActivityViewController 分享文件
            let activityVC = UIActivityViewController(activityItems: [exportURL], applicationActivities: nil)
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                activityVC.popoverPresentationController?.sourceView = rootVC.view
                rootVC.present(activityVC, animated: true)
            }
        } else {
            alertTitle = L.settingsExportError.localized
            alertMessage = L.settingsExportErrorMessage.localized
            showingAlert = true
        }
    }
    
    private func performImport() {
        guard let url = pendingImportURL else { return }
        
        do {
            // 需要访问安全作用域资源
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            let visibility = try viewModel.importFullData(from: url, personalStore: personalLedgerRoot.store)
            if let visibility {
                appState.showSharedLedgerTab = visibility.showSharedAndFriends
                appState.showPersonalLedgerTab = visibility.showPersonal
                appState.setQuickActionTarget(visibility.quickActionTarget())
                quickActionSelection = selection(from: appState.getQuickActionTarget())
            }
            personalSettingsViewModel.reloadFromStore()
            alertTitle = L.settingsImportSuccess.localized
            alertMessage = L.settingsImportSuccessMessage.localized
            showingAlert = true
            pendingImportURL = nil
        } catch {
            alertTitle = L.settingsImportError.localized
            alertMessage = error.localizedDescription
            showingAlert = true
            pendingImportURL = nil
        }
    }
    
    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            }
        }
    }
    
    private func openPrivacySupport() {
        if let url = URL(string: "https://guoran7771.github.io/KuaiJiPrivacy-Support/kuaji_privacy_support_trilingual.html") {
            UIApplication.shared.open(url)
        }
    }

    private func binding<Value>(get: @escaping () -> Value, set: @escaping (Value) -> Void) -> Binding<Value> {
        Binding(get: get, set: set)
    }

    // Local helper for SettingsView scope
    private func versionString() -> String {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String) ?? ""
        let build = (info?["CFBundleVersion"] as? String) ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }
}
