//
//  SharedLedgerExportModels.swift
//  KuaiJi
//

import Foundation

// MARK: - Export Data Structures

struct ExportData: Codable {
    let version: String
    let exportDate: Date
    let currentUserId: UUID
    let hasCompletedOnboarding: Bool
    let users: [ExportUserProfile]
    let ledgers: [ExportLedger]
}

struct FeatureVisibilitySnapshot: Codable {
    let showSharedAndFriends: Bool
    let showPersonal: Bool
    private let quickActionIdentifier: String?

    init(showSharedAndFriends: Bool, showPersonal: Bool, quickAction: QuickActionTarget?) {
        self.showSharedAndFriends = showSharedAndFriends
        self.showPersonal = showPersonal
        switch quickAction {
        case .personal:
            quickActionIdentifier = "personal"
        case .shared(let id):
            quickActionIdentifier = id.uuidString
        case .none:
            quickActionIdentifier = nil
        }
    }

    func quickActionTarget() -> QuickActionTarget? {
        guard let value = quickActionIdentifier, !value.isEmpty else { return nil }
        if value == "personal" { return .personal }
        if let uuid = UUID(uuidString: value) { return .shared(uuid) }
        return nil
    }
}

struct FullAppExportData: Codable {
    let version: String
    let shared: ExportData
    let personal: PersonalLedgerSnapshot
    let visibility: FeatureVisibilitySnapshot
}

struct ExportUserProfile: Codable {
    let remoteId: UUID
    let userId: String
    let name: String
    let avatarEmoji: String?
    let localeIdentifier: String
    let currency: CurrencyCode
    let createdAt: Date
    let updatedAt: Date
    
    init(from user: UserProfile) {
        self.remoteId = user.remoteId
        self.userId = user.userId
        self.name = user.name
        self.avatarEmoji = user.avatarEmoji
        self.localeIdentifier = user.localeIdentifier
        self.currency = user.currency
        self.createdAt = user.createdAt
        self.updatedAt = user.updatedAt
    }
}

struct ExportLedger: Codable {
    let remoteId: UUID
    let name: String
    let ownerId: UUID
    let currency: CurrencyCode
    let createdAt: Date
    let updatedAt: Date
    let settings: LedgerSettings
    let memberships: [ExportMembership]
    let expenses: [ExportExpense]
    
    init(from ledger: Ledger) {
        self.remoteId = ledger.remoteId
        self.name = ledger.name
        self.ownerId = ledger.ownerId
        self.currency = ledger.currency
        self.createdAt = ledger.createdAt
        self.updatedAt = ledger.updatedAt
        self.settings = ledger.settings
        self.memberships = ledger.memberships.map { ExportMembership(from: $0) }
        self.expenses = ledger.expenses.map { ExportExpense(from: $0) }
    }
}

struct ExportMembership: Codable {
    let remoteId: UUID
    let userId: UUID
    let role: LedgerRole
    let joinedAt: Date
    
    init(from membership: Membership) {
        self.remoteId = membership.remoteId
        self.userId = membership.userId
        self.role = membership.role
        self.joinedAt = membership.joinedAt
    }
}

struct ExportExpense: Codable {
    let remoteId: UUID
    let ledgerId: UUID
    let payerId: UUID
    let title: String
    let amountMinorUnits: Int
    let currency: CurrencyCode
    let date: Date
    let note: String
    let category: ExpenseCategory
    let createdAt: Date
    let updatedAt: Date
    let metadata: ExpenseMetadata
    let splitStrategy: SplitStrategy
    let isSettlement: Bool?
    let participants: [ExportExpenseParticipant]
    
    init(from expense: Expense) {
        self.remoteId = expense.remoteId
        self.ledgerId = expense.ledgerId
        self.payerId = expense.payerId
        self.title = expense.title
        self.amountMinorUnits = expense.amountMinorUnits
        self.currency = expense.currency
        self.date = expense.date
        self.note = expense.note
        self.category = expense.category
        self.createdAt = expense.createdAt
        self.updatedAt = expense.updatedAt
        self.metadata = expense.metadata
        self.splitStrategy = expense.splitStrategy
        self.isSettlement = expense.isSettlement
        self.participants = expense.participants.map { ExportExpenseParticipant(from: $0) }
    }
}

struct ExportExpenseParticipant: Codable {
    let remoteId: UUID
    let expenseId: UUID
    let userId: UUID
    let shareType: ShareType
    let shareValue: Decimal?
    
    init(from participant: ExpenseParticipant) {
        self.remoteId = participant.remoteId
        self.expenseId = participant.expenseId
        self.userId = participant.userId
        self.shareType = participant.shareType
        self.shareValue = participant.shareValue
    }
}
