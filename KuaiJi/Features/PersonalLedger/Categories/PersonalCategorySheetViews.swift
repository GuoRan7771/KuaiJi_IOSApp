//
//  PersonalCategorySheetViews.swift
//  KuaiJi
//
//  Personal category auxiliary sheet views.
//

import SwiftUI

struct SystemCategoryColorEditor: View {
    let target: ColorEditingTarget
    @ObservedObject var viewModel: PersonalCategorySettingsViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedColor: Color
    
    init(target: ColorEditingTarget, viewModel: PersonalCategorySettingsViewModel) {
        self.target = target
        self.viewModel = viewModel
        _selectedColor = State(initialValue: viewModel.systemColor(for: target.key, fallback: target.originalColor))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                ColorPicker(L.personalCategoriesColor.localized, selection: $selectedColor, supportsOpacity: false)
            }
            .navigationTitle(L.edit.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel.localized) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L.save.localized) {
                        viewModel.updateSystemCategoryColor(selectedColor, key: target.key)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(200)])
    }
}

struct CategoryReassignmentPicker: View {
    @ObservedObject var viewModel: PersonalCategorySettingsViewModel
    let kind: PersonalTransactionKind
    let currentCategoryId: UUID
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(L.personalCategoriesSystem.localized)) {
                    ForEach(systemOptions) { option in
                        categoryRow(option)
                    }
                }
                .listRowBackground(Color.appSurface)
                
                Section(header: Text(L.personalCategoriesCustom.localized)) {
                    ForEach(customOptions) { option in
                        categoryRow(option)
                    }
                }
                .listRowBackground(Color.appSurface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle(L.personalCategoryDeleteSelectNew.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.cancel.localized) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var systemOptions: [PersonalCategoryOption] {
        viewModel.categoryOptions(for: kind).filter { !$0.isCustom }
    }
    
    private var customOptions: [PersonalCategoryOption] {
        viewModel.categoryOptions(for: kind).filter { $0.isCustom && $0.key != currentCategoryKey }
    }
    
    private var currentCategoryKey: String? {
        viewModel.customCategories.first(where: { $0.id == currentCategoryId })?.key
    }
    
    private func categoryRow(_ option: PersonalCategoryOption) -> some View {
        Button {
            onSelect(option.key)
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(option.color)
                    .frame(width: 26, height: 26)
                
                Image(systemName: option.systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(option.color)

                Text(option.localizedName)
                    .foregroundStyle(Color.primary)
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
