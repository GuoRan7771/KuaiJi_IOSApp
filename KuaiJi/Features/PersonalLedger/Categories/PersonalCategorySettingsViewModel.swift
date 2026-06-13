//
//  PersonalCategorySettingsViewModel.swift
//  KuaiJi
//

import Combine
import Foundation
import SwiftData
import SwiftUI

struct PersonalCategoryRowViewData: Identifiable {
    var id: UUID
    var key: String
    var name: String
    var kind: PersonalTransactionKind
    var systemImage: String
    var colorHex: String
    var mappedSystemCategory: ExpenseCategory?

    var color: Color {
        Color(hex: colorHex) ?? Color.appBrand
    }
}

struct PersonalCategoryDraft: Identifiable {
    var id: UUID? = nil
    var name: String = ""
    var kind: PersonalTransactionKind = .expense
    var systemImage: String = "tag"
    var color: Color = Color.appBrand
    var mappedSystemCategory: ExpenseCategory? = nil
}

@MainActor
final class PersonalCategorySettingsViewModel: ObservableObject {
    @Published private(set) var customCategories: [PersonalCategoryRowViewData] = []
    @Published var lastError: String?

    var systemExpenseOptions: [PersonalCategoryOption] { systemExpenseCategories }
    var systemIncomeOptions: [PersonalCategoryOption] { systemIncomeCategories }
    var systemFeeOptions: [PersonalCategoryOption] { feeCategories }

    private let store: PersonalLedgerStore
    private var cancellables: Set<AnyCancellable> = []

    init(store: PersonalLedgerStore) {
        self.store = store
        rebuild()
        store.$customCategories
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuild() }
            .store(in: &cancellables)
    }

    func rebuild() {
        customCategories = store.customCategories.map { category in
            PersonalCategoryRowViewData(id: category.remoteId,
                                        key: category.key,
                                        name: category.name,
                                        kind: category.kind,
                                        systemImage: category.systemImage,
                                        colorHex: category.colorHex,
                                        mappedSystemCategory: category.mappedSystemCategory)
        }
    }

    func systemColor(for key: String, fallback: Color) -> Color {
        store.systemCategoryColorHex(for: key).flatMap(Color.init(hex:)) ?? fallback
    }

    func isHiddenSystemCategory(_ key: String) -> Bool {
        store.systemCategoryHidden(key)
    }

    func updateSystemCategoryColor(_ color: Color, key: String) {
        do {
            try store.setSystemCategoryColor(color, for: key)
            objectWillChange.send()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func updateSystemCategoryHidden(_ hidden: Bool, key: String) {
        do {
            try store.setSystemCategoryHidden(hidden, for: key)
            objectWillChange.send()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func makeDraft(for id: UUID? = nil) -> PersonalCategoryDraft {
        guard let id, let existing = store.customCategories.first(where: { $0.remoteId == id }) else {
            return PersonalCategoryDraft()
        }
        return PersonalCategoryDraft(id: existing.remoteId,
                                     name: existing.name,
                                     kind: existing.kind,
                                     systemImage: existing.systemImage,
                                     color: Color(hex: existing.colorHex) ?? Color.appBrand,
                                     mappedSystemCategory: existing.mappedSystemCategory)
    }

    func save(draft: PersonalCategoryDraft) -> Bool {
        do {
            let input = PersonalCategoryInput(id: draft.id,
                                              name: draft.name,
                                              kind: draft.kind,
                                              systemImage: draft.systemImage,
                                              color: draft.color,
                                              mappedSystemCategory: draft.kind == .expense ? draft.mappedSystemCategory : nil,
                                              sortIndex: nil)
            _ = try store.saveCategory(input)
            rebuild()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func transactionCount(for id: UUID) -> Int {
        return (try? store.transactionCount(forCategoryId: id)) ?? 0
    }

    func categoryOptions(for kind: PersonalTransactionKind) -> [PersonalCategoryOption] {
        store.categoryOptions(for: kind)
    }

    func delete(id: UUID, reassignTo newKey: String? = nil) {
        do {
            if let newKey = newKey {
                try store.reassignTransactions(fromCategoryId: id, toCategoryKey: newKey)
            }
            try store.deleteCategory(id: id)
            rebuild()
        } catch {
            lastError = error.localizedDescription
        }
    }
}
