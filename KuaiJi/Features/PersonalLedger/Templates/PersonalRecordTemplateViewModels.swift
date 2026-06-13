//
//  PersonalRecordTemplateViewModels.swift
//  KuaiJi
//

import Combine
import Foundation
import SwiftData
import SwiftUI

@MainActor
final class PersonalRecordTemplatesViewModel: ObservableObject {
    @Published private(set) var templates: [PersonalRecordTemplateViewData] = []
    @Published var lastError: String?

    private let store: PersonalLedgerStore
    private var cancellables: Set<AnyCancellable> = []

    init(store: PersonalLedgerStore) {
        self.store = store
        Task { await refresh() }
        store.$recordTemplates
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildTemplates() }
            .store(in: &cancellables)
        store.$activeAccounts
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildTemplates() }
            .store(in: &cancellables)
        store.$archivedAccounts
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildTemplates() }
            .store(in: &cancellables)
        store.$customCategories
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildTemplates() }
            .store(in: &cancellables)
    }

    func refresh() async {
        do {
            try store.refreshTemplates()
            rebuildTemplates()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteTemplate(id: UUID) async {
        do {
            try store.deleteTemplate(id: id)
            await refresh()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func move(from source: IndexSet, to destination: Int) {
        var newList = templates
        newList.move(fromOffsets: source, toOffset: destination)
        templates = newList
        Task {
            do {
                try store.reorderTemplates(idsInDisplayOrder: newList.map { $0.id })
            } catch {
                lastError = error.localizedDescription
            }
        }
    }

    private func rebuildTemplates() {
        templates = store.recordTemplates.map { template in
            let accountName: String?
            if let id = template.accountId, let account = store.account(with: id) {
                accountName = account.name
            } else {
                accountName = nil
            }
            let category = store.categoryOption(for: template.categoryKey)
            return PersonalRecordTemplateViewData(id: template.remoteId,
                                                  name: template.name,
                                                  accountId: template.accountId,
                                                  accountName: accountName,
                                                  amountMinorUnits: template.amountMinorUnits,
                                                  currency: template.currency,
                                                  categoryKey: template.categoryKey,
                                                  categoryName: category?.localizedName ?? (template.categoryKey.isEmpty ? L.personalTemplatesNoCategory.localized : template.categoryKey),
                                                  systemImage: category?.systemImage ?? store.categoryIcon(for: template.categoryKey),
                                                  note: template.note)
        }
    }
}

@MainActor
final class PersonalRecordTemplateFormViewModel: ObservableObject {
    @Published var name: String
    @Published var accountId: UUID?
    @Published var amountText: String
    @Published var currency: CurrencyCode
    @Published var categoryKey: String
    @Published var note: String
    @Published var isSaving = false
    @Published var errorMessage: String?
    @Published private(set) var categoryOptions: [PersonalCategoryOption] = []

    var accounts: [PersonalAccount] { store.activeAccounts }
    var currencyOptions: [CurrencyCode] { CurrencyCode.allCases }
    var isEditing: Bool { editingId != nil }

    private let store: PersonalLedgerStore
    private let editingId: UUID?
    private var cancellables: Set<AnyCancellable> = []

    init(store: PersonalLedgerStore, templateId: UUID? = nil) {
        self.store = store
        self.editingId = templateId
        if let templateId, let template = store.template(with: templateId) {
            name = template.name
            if let accountId = template.accountId, store.account(with: accountId) != nil {
                self.accountId = accountId
            } else {
                self.accountId = nil
            }
            amountText = template.amountMinorUnits > 0 ? Self.decimalString(from: template.amountMinorUnits) : ""
            currency = template.currency
            categoryKey = template.categoryKey
            note = template.note ?? ""
        } else {
            name = ""
            self.accountId = nil
            amountText = ""
            currency = store.safePrimaryDisplayCurrency()
            categoryKey = ""
            note = ""
        }
        reloadCategories()
        enforceValidCategory()
        subscribeToStore()
    }

    func save() async -> Bool {
        isSaving = true
        defer { isSaving = false }
        do {
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
            var parsedAmount: Decimal = 0
            if !amountText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                guard let amount = NumberParsing.parseDecimal(amountText), amount >= 0 else {
                    throw PersonalLedgerError.amountMustBePositive
                }
                parsedAmount = amount
            }
            let input = PersonalRecordTemplateInput(id: editingId,
                                                    name: trimmedName,
                                                    accountId: accountId,
                                                    amount: parsedAmount,
                                                    currency: currency,
                                                    categoryKey: categoryKey,
                                                    note: cleanedNote.isEmpty ? nil : cleanedNote)
            _ = try store.saveTemplate(input)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private static func decimalString(from minorUnits: Int) -> String {
        let decimal = SettlementMath.decimal(fromMinorUnits: minorUnits, scale: 2)
        return NSDecimalNumber(decimal: decimal).stringValue
    }

    private func reloadCategories() {
        let includeHiddenKey = store.systemCategoryHidden(categoryKey) ? categoryKey : nil
        categoryOptions = store.categoryOptions(for: .expense, includeHiddenKey: includeHiddenKey)
    }

    private func enforceValidCategory() {
        if store.systemCategoryHidden(categoryKey), !isEditing {
            let visible = store.categoryOptions(for: .expense, includeHiddenKey: nil)
            if let first = visible.first {
                categoryKey = first.key
                return
            }
        }
        if categoryKey.isEmpty { return }
        if !categoryOptions.contains(where: { $0.key == categoryKey }) {
            categoryKey = categoryOptions.first?.key ?? ""
        }
    }

    private func subscribeToStore() {
        store.$customCategories
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadCategories()
                self?.enforceValidCategory()
            }
            .store(in: &cancellables)
        store.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadCategories()
                self?.enforceValidCategory()
            }
            .store(in: &cancellables)
    }
}
