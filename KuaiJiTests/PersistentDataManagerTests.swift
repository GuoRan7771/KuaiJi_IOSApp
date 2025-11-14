//
//  PersistentDataManagerTests.swift
//  KuaiJiTests
//
//  Ensures data lifecycle helpers keep personal ledger models in sync.
//

import Foundation
import SwiftData
import Testing
@testable import KuaiJi

@Suite("Persistent Data Manager")
struct PersistentDataManagerTests {
    @MainActor
    private func makeManager() throws -> PersistentDataManager {
        let schema = Schema([
            UserProfile.self,
            Ledger.self,
            Membership.self,
            Expense.self,
            ExpenseParticipant.self,
            BalanceSnapshot.self,
            TransferPlan.self,
            AuditLog.self,
            PersonalAccount.self,
            PersonalTransaction.self,
            AccountTransfer.self,
            PersonalPreferences.self,
            PersonalCategory.self,
            PersonalStatsGroup.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return PersistentDataManager(modelContext: container.mainContext)
    }

    @Test("Importing shared data clears all personal stats groups")
    @MainActor
    func sharedImportClearsPersonalStatsGroups() throws {
        let manager = try makeManager()
        let context = manager.modelContext
        let legacyGroup = PersonalStatsGroup(name: "Legacy",
                                             colorHex: nil,
                                             isVisibleByDefault: true,
                                             sortIndex: 0,
                                             kind: .expense,
                                             role: .custom,
                                             categoryKeys: [])
        context.insert(legacyGroup)
        try context.save()

        let preImport = try context.fetch(FetchDescriptor<PersonalStatsGroup>())
        #expect(preImport.count == 1)

        let payload = ExportData(version: "1.0",
                                 exportDate: Date(),
                                 currentUserId: UUID(),
                                 hasCompletedOnboarding: false,
                                 users: [],
                                 ledgers: [])
        try manager.importSharedData(payload)

        let remainingGroups = try context.fetch(FetchDescriptor<PersonalStatsGroup>())
        #expect(remainingGroups.isEmpty)
    }
}
