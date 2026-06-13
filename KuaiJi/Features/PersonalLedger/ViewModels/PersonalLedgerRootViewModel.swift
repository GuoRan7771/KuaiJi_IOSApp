//
//  PersonalLedgerRootViewModel.swift
//  KuaiJi
//

import Combine
import Foundation
import SwiftData
import SwiftUI

@MainActor
final class PersonalLedgerRootViewModel: ObservableObject {
    let store: PersonalLedgerStore

    init(modelContext: ModelContext, defaultCurrency: CurrencyCode) {
        do {
            self.store = try PersonalLedgerStore(context: modelContext, defaultCurrency: defaultCurrency)
        } catch {
            #if DEBUG
            preconditionFailure("Failed to create PersonalLedgerStore: \(error)")
            #else
            // Fallback: attempt to create an in-memory container and store
            let schema = Schema([
                PersonalCategoryDefinition.self,
                PersonalAccount.self,
                PersonalTransaction.self,
                AccountTransfer.self,
                PersonalRecordTemplate.self,
                PersonalPreferences.self
            ])
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let container = try? ModelContainer(for: schema, configurations: [configuration]),
               let fallback = try? PersonalLedgerStore(context: container.mainContext, defaultCurrency: defaultCurrency) {
                self.store = fallback
            } else {
                fatalError("Fatal: cannot initialize PersonalLedgerStore even in fallback: \(error)")
            }
            #endif
        }
    }

    func makeHomeViewModel() -> PersonalLedgerHomeViewModel {
        PersonalLedgerHomeViewModel(store: store)
    }

    func makeRecordFormViewModel(existing transaction: PersonalRecordRowViewData? = nil) -> PersonalRecordFormViewModel {
        PersonalRecordFormViewModel(store: store, editingRecord: transaction)
    }

    func makeAccountsViewModel() -> PersonalAccountsViewModel {
        PersonalAccountsViewModel(store: store)
    }

    func makeAccountFormViewModel(accountId: UUID? = nil) -> PersonalAccountFormViewModel {
        PersonalAccountFormViewModel(store: store, accountId: accountId)
    }

    func makeTransferFormViewModel(transferId: UUID? = nil) -> PersonalTransferFormViewModel {
        PersonalTransferFormViewModel(store: store, transferId: transferId)
    }

    func makeAllRecordsViewModel(anchorDate: Date = Date()) -> PersonalAllRecordsViewModel {
        PersonalAllRecordsViewModel(store: store, anchorDate: anchorDate)
    }

    func makeAllRecordsViewModelForAll() -> PersonalAllRecordsViewModel {
        let vm = PersonalAllRecordsViewModel(store: store, anchorDate: Date())
        vm.filterState = .default
        return vm
    }

    func makeStatsViewModel() -> PersonalStatsViewModel {
        PersonalStatsViewModel(store: store)
    }

    func makeSettingsViewModel() -> PersonalLedgerSettingsViewModel {
        PersonalLedgerSettingsViewModel(store: store)
    }

    func makeCSVExportViewModel() -> PersonalCSVExportViewModel {
        PersonalCSVExportViewModel(store: store)
    }

    func makeTemplatesViewModel() -> PersonalRecordTemplatesViewModel {
        PersonalRecordTemplatesViewModel(store: store)
    }

    func makeTemplateFormViewModel(templateId: UUID? = nil) -> PersonalRecordTemplateFormViewModel {
        PersonalRecordTemplateFormViewModel(store: store, templateId: templateId)
    }

    func makeCategorySettingsViewModel() -> PersonalCategorySettingsViewModel {
        PersonalCategorySettingsViewModel(store: store)
    }
}
