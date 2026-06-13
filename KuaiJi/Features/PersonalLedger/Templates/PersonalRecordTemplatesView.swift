//
//  PersonalRecordTemplatesView.swift
//  KuaiJi
//

import SwiftUI

struct PersonalRecordTemplateFormHost: View {
    @StateObject private var viewModel: PersonalRecordTemplateFormViewModel
    var onDismiss: () -> Void

    init(root: PersonalLedgerRootViewModel, templateId: UUID?, onDismiss: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: root.makeTemplateFormViewModel(templateId: templateId))
        self.onDismiss = onDismiss
    }

    var body: some View {
        NavigationStack {
            PersonalRecordTemplateFormView(viewModel: viewModel, onDone: onDismiss)
        }
        .scrollDismissesKeyboard(.interactively)
        .dismissKeyboardOnTap()
        .tint(AppColors.brandPrimary)
    }
}

struct PersonalRecordTemplateFormView: View {
    @ObservedObject var viewModel: PersonalRecordTemplateFormViewModel
    var onDone: () -> Void

    var body: some View {
        Form {
            Section(header: Text(L.personalTemplatesName.localized)) {
                TextField(L.personalTemplatesName.localized, text: $viewModel.name)
            }

            Section(header: Text(L.personalFieldAccount.localized)) {
                Picker(L.personalFieldAccount.localized, selection: $viewModel.accountId) {
                    Text(L.personalTemplatesNoAccount.localized).tag(nil as UUID?)
                    ForEach(viewModel.accounts) { account in
                        Text("\(account.name) · \(account.currency.rawValue)").tag(account.remoteId as UUID?)
                    }
                }
            }

            Section(header: Text(L.expenseBasicInfo.localized)) {
                HStack {
                    TextField(L.personalFieldAmount.localized, text: $viewModel.amountText)
                        .keyboardType(.decimalPad)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .onChange(of: viewModel.amountText) { oldValue, newValue in
                            let validated = NumberParsing.validateDecimalInput(newValue, maxDecimalPlaces: 2, locale: .current, oldValue: oldValue)
                            if validated != newValue { viewModel.amountText = validated }
                        }
                    Menu {
                        ForEach(viewModel.currencyOptions, id: \.self) { code in
                            Button(action: { viewModel.currency = code }) {
                                Text(code.displayLabel)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.currency.displayLabel)
                                .foregroundStyle(AppColors.textPrimary)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                                .foregroundStyle(AppColors.secondaryText)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 8).fill(AppColors.surfaceAlt))
                    }
                    .accessibilityLabel(Text(L.personalFieldCurrency.localized))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appListRowSeparatorLeading()

                Picker(L.personalFieldCategory.localized, selection: $viewModel.categoryKey) {
                    Text(L.personalTemplatesNoCategory.localized).tag("")
                    ForEach(viewModel.categoryOptions, id: \.key) { option in
                        Text(option.localizedName).tag(option.key)
                    }
                }

                TextField(L.expensePurpose.localized, text: $viewModel.note, axis: .vertical)
            }
            Section(footer: Text(L.personalTemplatesOptionalHint.localized)
                .font(.footnote)
                .foregroundStyle(AppColors.secondaryText)) { EmptyView() }
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.background)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L.cancel.localized, action: onDone)
                    .tint(AppColors.brandPrimary)
            }
            ToolbarItem(placement: .confirmationAction) {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Button(L.save.localized) {
                        Task {
                            let success = await viewModel.save()
                            if success { onDone() }
                        }
                    }
                    .fontWeight(.semibold)
                    .tint(AppColors.brandPrimary)
                }
            }
        }
        .navigationTitle(viewModel.isEditing ? L.edit.localized : L.personalTemplatesCreate.localized)
        .alert(viewModel.errorMessage ?? "", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { _ in viewModel.errorMessage = nil })) {
            Button(L.ok.localized, action: {})
        }
    }
}

struct PersonalRecordTemplatesView: View {
    @ObservedObject var root: PersonalLedgerRootViewModel
    @StateObject private var viewModel: PersonalRecordTemplatesViewModel
    @State private var showingForm = false
    @State private var editingTemplateId: UUID?
    @State private var pendingDeleteId: UUID?

    init(root: PersonalLedgerRootViewModel, viewModel: PersonalRecordTemplatesViewModel) {
        self.root = root
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            if viewModel.templates.isEmpty {
                Section {
                    Text(L.personalTemplatesEmpty.localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(viewModel.templates) { template in
                        PersonalTemplateLabel(template: template)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editingTemplateId = template.id
                                showingForm = true
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    pendingDeleteId = template.id
                                } label: {
                                    Label(L.delete.localized, systemImage: "trash")
                                }
                                Button {
                                    editingTemplateId = template.id
                                    showingForm = true
                                } label: {
                                    Label(L.edit.localized, systemImage: "pencil")
                                }
                                .tint(Color.appBrand)
                            }
                    }
                    .onMove(perform: viewModel.move)
                    .onDelete { indexSet in
                        pendingDeleteId = indexSet.first.map { viewModel.templates[$0].id }
                    }
                } footer: {
                    Text(L.personalTemplatesQuickFillHint.localized)
                        .appSecondaryTextStyle()
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(L.personalTemplatesTitle.localized)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { editingTemplateId = nil; showingForm = true }) {
                    Image(systemName: "plus")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
        }
        .task { await viewModel.refresh() }
        .refreshable { await viewModel.refresh() }
        .sheet(isPresented: $showingForm) {
            PersonalRecordTemplateFormHost(root: root, templateId: editingTemplateId) {
                showingForm = false
                Task { await viewModel.refresh() }
            }
        }
        .alert(viewModel.lastError ?? "", isPresented: Binding(get: { viewModel.lastError != nil }, set: { _ in viewModel.lastError = nil })) {
            Button(L.ok.localized, action: {})
        }
        .alert(L.delete.localized, isPresented: Binding(get: { pendingDeleteId != nil }, set: { v in if !v { pendingDeleteId = nil } })) {
            Button(L.cancel.localized, role: .cancel) { pendingDeleteId = nil }
            Button(L.delete.localized, role: .destructive) {
                if let id = pendingDeleteId {
                    Task { await viewModel.deleteTemplate(id: id) }
                    pendingDeleteId = nil
                }
            }
        } message: {
            Text(L.personalDeleteConfirm.localized)
        }
    }
}

struct PersonalTemplateLabel: View {
    var template: PersonalRecordTemplateViewData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(template.name)
                    .font(.headline)
                    .foregroundStyle(Color.appTextPrimary)
                Spacer()
                if template.amountMinorUnits > 0 {
                    AmountView(amountMinorUnits: template.amountMinorUnits,
                               currency: template.currency,
                               tint: Color.appTextPrimary)
                } else {
                    Text(L.personalTemplatesNoAmount.localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 12) {
                Label(template.accountName ?? L.personalTemplatesNoAccount.localized, systemImage: "creditcard")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label(template.categoryName.isEmpty ? L.personalTemplatesNoCategory.localized : template.categoryName,
                      systemImage: template.systemImage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            if let note = template.note, !note.isEmpty {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
