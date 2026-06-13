//
//  PersonalCategorySettingsView.swift
//  KuaiJi
//

import SwiftUI
import UIKit

struct ColorEditingTarget: Identifiable {
    var id: String { key }
    let key: String
    let originalColor: Color
}

struct PersonalCategorySettingsView: View {
    @StateObject private var viewModel: PersonalCategorySettingsViewModel
    @State private var showingForm = false
    @State private var editingDraft = PersonalCategoryDraft()
    @State private var pendingDeleteId: UUID?
    @State private var colorEditingTarget: ColorEditingTarget?
    @State private var showReassignOptions = false
    @State private var showCategoryPicker = false
    @State private var categoryToDelete: PersonalCategoryRowViewData?

    init(viewModel: PersonalCategorySettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
            Section(header: Text(L.personalCategoriesSystem.localized)) {
                systemCategorySectionContent(title: L.personalTypeExpense.localized, items: viewModel.systemExpenseOptions, showHint: true)
                systemCategorySectionContent(title: L.personalTypeIncome.localized, items: viewModel.systemIncomeOptions)
                systemCategorySectionContent(title: L.personalTypeFee.localized, items: viewModel.systemFeeOptions)
            }

            Section(header: Text(L.personalCategoriesCustom.localized),
                    footer: Text(L.personalCategoriesMappingHint.localized)
                .appSecondaryTextStyle()) {
                if viewModel.customCategories.isEmpty {
                    Text(L.personalCategoriesEmpty.localized)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.customCategories) { category in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(category.color)
                                .frame(width: 26, height: 26)
                            
                            Image(systemName: category.systemImage)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(category.color)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(category.name)
                                    .font(.system(.headline, design: .rounded))
                                Text(mappingDescription(for: category))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editingDraft = viewModel.makeDraft(for: category.id)
                            showingForm = true
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                let count = viewModel.transactionCount(for: category.id)
                                if count > 0 {
                                    categoryToDelete = category
                                    showReassignOptions = true
                                } else {
                                    pendingDeleteId = category.id
                                }
                            } label: {
                                Label(L.delete.localized, systemImage: "trash")
                            }
                            Button {
                                editingDraft = viewModel.makeDraft(for: category.id)
                                showingForm = true
                            } label: {
                                Label(L.edit.localized, systemImage: "pencil")
                            }
                            .tint(Color.appBrand)
                        }
                    }
                }

                Button {
                    editingDraft = viewModel.makeDraft()
                    showingForm = true
                } label: {
                    Label(L.personalCategoriesAdd.localized, systemImage: "plus")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle(L.personalCategoriesManage.localized)
        .sheet(isPresented: $showingForm) {
            PersonalCategoryFormView(draft: editingDraft,
                                     expenseOptions: viewModel.systemExpenseOptions) { draft in
                viewModel.save(draft: draft)
            }
        }
        .sheet(item: $colorEditingTarget) { target in
            SystemCategoryColorEditor(target: target, viewModel: viewModel)
        }
        .alert(viewModel.lastError ?? "", isPresented: Binding(get: { viewModel.lastError != nil }, set: { _ in viewModel.lastError = nil })) {
            Button(L.ok.localized, action: {})
        }
        .alert(L.delete.localized, isPresented: Binding(get: { pendingDeleteId != nil }, set: { _ in pendingDeleteId = nil })) {
            Button(L.cancel.localized, role: .cancel) { pendingDeleteId = nil }
            Button(L.delete.localized, role: .destructive) {
                if let id = pendingDeleteId {
                    viewModel.delete(id: id)
                }
                pendingDeleteId = nil
            }
        } message: {
            Text(L.personalDeleteConfirm.localized)
        }
        .alert(L.delete.localized, isPresented: $showReassignOptions) {
            Button(L.personalCategoryDeleteMoveToOther.localized) {
                if let category = categoryToDelete {
                    let otherKey: String
                    switch category.kind {
                    case .expense: otherKey = ExpenseCategory.other.rawValue
                    case .income: otherKey = "otherIncome"
                    case .fee: otherKey = "fees"
                    }
                    viewModel.delete(id: category.id, reassignTo: otherKey)
                }
                categoryToDelete = nil
            }
            Button(L.personalCategoryDeleteSelectNew.localized) {
                showCategoryPicker = true
            }
            Button(L.cancel.localized, role: .cancel) {
                categoryToDelete = nil
            }
        } message: {
            Text(L.personalCategoryDeleteHasTransactions.localized)
        }
        .sheet(isPresented: $showCategoryPicker) {
            if let category = categoryToDelete {
                CategoryReassignmentPicker(viewModel: viewModel, kind: category.kind, currentCategoryId: category.id) { selectedKey in
                    viewModel.delete(id: category.id, reassignTo: selectedKey)
                    categoryToDelete = nil
                    showCategoryPicker = false
                }
            }
        }
    }

    @ViewBuilder
    private func systemCategorySectionContent(title: String, items: [PersonalCategoryOption], showHint: Bool = false) -> some View {
        if showHint {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(L.personalCategoriesHideHint.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        
        ForEach(items, id: \.key) { option in
            HStack(spacing: 12) {
                Circle()
                    .fill(viewModel.systemColor(for: option.key, fallback: option.color))
                    .frame(width: 26, height: 26)

                HStack(spacing: 6) {
                    Image(systemName: option.systemImage)
                        .foregroundStyle(viewModel.systemColor(for: option.key, fallback: option.color))
                    Text(option.localizedName)
                        .foregroundStyle(Color.appLedgerContentText)
                }
                
                Spacer()
                
                Toggle("", isOn: Binding(get: {
                    !viewModel.isHiddenSystemCategory(option.key)
                }, set: { isVisible in
                    viewModel.updateSystemCategoryHidden(!isVisible, key: option.key)
                }))
                .labelsHidden()
                .tint(Color.appToggleOn)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                colorEditingTarget = ColorEditingTarget(key: option.key, originalColor: option.color)
            }
            .swipeActions(edge: .trailing) {
                Button {
                    colorEditingTarget = ColorEditingTarget(key: option.key, originalColor: option.color)
                } label: {
                    Label(L.edit.localized, systemImage: "pencil")
                }
                .tint(Color.appBrand)
            }
        }
    }

    private func mappingDescription(for category: PersonalCategoryRowViewData) -> String {
        switch category.kind {
        case .expense:
            if let mapped = category.mappedSystemCategory {
                return L.personalCategoriesMappingValue.localized(mapped.localizedName)
            } else {
                return L.personalCategoriesMappingNone.localized
            }
        case .income:
            return L.personalTypeIncome.localized
        case .fee:
            return L.personalTypeFee.localized
        }
    }
}

struct PersonalCategoryFormView: View {
    @Environment(\.dismiss) private var dismiss

    @State var draft: PersonalCategoryDraft
    let expenseOptions: [PersonalCategoryOption]
    let onSave: (PersonalCategoryDraft) -> Bool

    private var symbolGroups: [(String, [String])] {
        [
            (L.personalSymbolGroupCommon.localized, [
                "tag", "bookmark.fill", "bell.fill", "calendar", "tray.fill", "heart.fill", "leaf.fill", "star.fill", "flag.fill", "location.fill", "archivebox.fill", "lightbulb.fill", "hourglass", "lock.fill", "key.fill", "gearshape.fill", "magnifyingglass", "clock.fill", "alarm.fill", "timer",
                "star.circle.fill", "checkmark.seal.fill", "exclamationmark.triangle.fill", "info.circle.fill", "questionmark.circle.fill", "plus.circle.fill", "minus.circle.fill", "xmark.circle.fill", "bolt.fill", "cloud.fill"
            ]),
            (L.personalSymbolGroupLife.localized, [
                "fork.knife", "cup.and.saucer.fill", "house.fill", "cart.fill", "drop.fill", "water.waves", "figure.walk", "bed.double.fill", "tshirt.fill", "pills.fill", "cross.case.fill", "pawprint.fill", "gift.fill", "basket.fill", "oven.fill", "washer.fill", "comb.fill", "scissors", "eyeglasses", "facemask.fill", "lamp.table.fill", "chair.lounge.fill",
                "house.lodge.fill", "building.columns.fill", "lightbulb.circle.fill", "fanblades.fill", "sofa.fill", "fireplace.fill", "toilet.fill", "shower.fill", "bathtub.fill", "bed.double.circle.fill", "refrigerator.fill", "cabinet.fill"
            ]),
            (L.personalSymbolGroupTravel.localized, [
                "car.fill", "tram.fill", "bicycle", "airplane", "fuelpump.fill", "suitcase.fill", "map.fill", "bus.fill", "ferry.fill", "ticket.fill", "globe", "sailboat.fill", "train.side.front.car", "cablecar.fill", "scooter", "parkingsign.circle.fill", "signpost.right.and.left.fill",
                "car.side.fill", "bus.doubledecker.fill", "tram.fill.tunnel", "bicycle.circle.fill", "figure.walk.circle.fill", "figure.run", "figure.hiking", "mountain.2.fill", "beach.umbrella.fill", "binoculars.fill", "airplane.circle.fill", "car.ferry.fill"
            ]),
            (L.personalSymbolGroupFinance.localized, [
                "banknote", "creditcard", "dollarsign.circle.fill", "chart.line.uptrend.xyaxis", "bitcoinsign.circle.fill", "wallet.pass", "giftcard.fill", "chart.pie.fill", "signature", "yensign.circle.fill", "eurosign.circle.fill", "sterlingsign.circle.fill", "chineseyuanrenminbisign.circle.fill", "banknote.fill", "scroll.fill", "chart.bar.fill",
                "creditcard.circle.fill", "chart.bar.xaxis", "chart.line.downtrend.xyaxis", "arrow.up.arrow.down.circle.fill", "arrow.triangle.2.circlepath.circle.fill", "bag.fill.badge.plus", "cart.fill.badge.plus", "basket.fill", "percent", "sum"
            ]),
            (L.personalSymbolGroupFun.localized, [
                "gamecontroller.fill", "music.note.list", "film.fill", "ticket.fill", "sparkles", "paintpalette.fill", "party.popper", "sportscourt.fill", "tv.fill", "tent.fill", "camera.fill", "theatermasks.fill", "dice.fill", "puzzlepiece.fill", "guitars.fill", "pianokeys", "headphones", "book.fill", "magazine.fill",
                "gamecontroller.circle.fill", "headphones.circle.fill", "mic.fill", "video.fill", "photo.fill", "paintbrush.pointed.fill", "paintbrush.fill", "pencil.tip.crop.circle.fill", "camera.macro", "popcorn.fill", "balloon.fill", "fireworks"
            ]),
            (L.personalSymbolGroupWork.localized, [
                "briefcase.fill", "laptopcomputer", "doc.text.fill", "person.2.fill", "paperclip", "hammer.fill", "building.2.fill", "printer.fill", "folder.fill", "phone.fill", "envelope.fill", "desktopcomputer", "keyboard.fill", "mouse.fill", "server.rack", "network", "wrench.and.screwdriver.fill", "ruler.fill",
                "briefcase.circle.fill", "person.crop.circle.fill.badge.plus", "person.3.fill", "phone.circle.fill", "envelope.circle.fill", "tray.full.fill", "archivebox.circle.fill", "doc.fill", "doc.text.image.fill", "printer.fill.and.paper.fill", "scanner.fill", "faxmachine"
            ])
        ]
    }

    private var symbolIsValid: Bool {
        let trimmed = draft.systemImage.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && UIImage(systemName: trimmed) != nil
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && symbolIsValid
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(L.personalCategoriesName.localized, text: $draft.name, prompt: Text(L.personalCategoriesNamePlaceholder.localized))
                    Picker(L.personalCategoriesType.localized, selection: $draft.kind) {
                        Text(L.personalTypeExpense.localized).tag(PersonalTransactionKind.expense)
                        Text(L.personalTypeIncome.localized).tag(PersonalTransactionKind.income)
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.appSurface)

                Section(header: Text(L.personalCategoriesIcon.localized)) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(symbolGroups, id: \.0) { title, symbols in
                            Text(title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(symbols, id: \.self) { symbol in
                                        Button {
                                            draft.systemImage = symbol
                                        } label: {
                                            Image(systemName: symbol)
                                                .font(.title3)
                                                .frame(width: 44, height: 44)
                                                .background(draft.systemImage == symbol ? Color.appSelection : Color.appSurfaceAlt, in: Circle())
                                                .foregroundStyle(draft.systemImage == symbol ? .white : .primary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.appSurface)

                Section {
                    ColorPicker(L.personalCategoriesColor.localized, selection: $draft.color, supportsOpacity: false)
                }
                .listRowBackground(Color.appSurface)

                if draft.kind == .expense {
                    Section(header: Text(L.personalCategoriesMapping.localized),
                            footer: Text(L.personalCategoriesMappingHint.localized)
                        .appSecondaryTextStyle()) {
                        Picker(L.personalCategoriesMapping.localized, selection: Binding(get: {
                            draft.mappedSystemCategory
                        }, set: { draft.mappedSystemCategory = $0 })) {
                            Text(L.personalCategoriesMappingNone.localized).tag(ExpenseCategory?.none)
                            ForEach(expenseOptions, id: \.key) { option in
                                if let category = ExpenseCategory(rawValue: option.key) {
                                    Text(option.localizedName).tag(Optional(category))
                                }
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .listRowBackground(Color.appSurface)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(draft.id == nil ? L.personalCategoriesAdd.localized : L.edit.localized)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel.localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.save.localized) {
                        var adjusted = draft
                        if draft.kind != .expense {
                            adjusted.mappedSystemCategory = nil
                        }
                        if onSave(adjusted) {
                            dismiss()
                        }
                    }
                    .disabled(!canSave)
                }
            }
            .onChange(of: draft.kind) { _, newValue in
                if newValue != .expense {
                    draft.mappedSystemCategory = nil
                }
            }
        }
    }
}
