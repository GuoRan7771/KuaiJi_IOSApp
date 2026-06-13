//
//  SharedLedgerQuickAdd.swift
//  KuaiJi
//
//  Encapsulates split strategy helpers for quick shared ledger entries.
//

import Foundation

struct SharedLedgerQuickAdd {
    enum SplitMode: CaseIterable, Identifiable {
        case equalShares
        case payerTreat

        var id: String {
            switch self {
            case .equalShares: return "equal"
            case .payerTreat: return "treat"
            }
        }
    }

    struct Configuration {
        let splitStrategy: SplitStrategy
        let includePayer: Bool
        let participants: [ExpenseParticipantShare]
    }

    static func configuration(for mode: SplitMode, members: [UUID], payerId: UUID) throws -> Configuration {
        guard !members.isEmpty else { throw SharedLedgerQuickAddError.noMembers }

        switch mode {
        case .equalShares:
            let participants = members.map { ExpenseParticipantShare(userId: $0, shareType: .aa) }
            return Configuration(splitStrategy: .payerAA,
                                 includePayer: true,
                                 participants: participants)
        case .payerTreat:
            let participants = [ExpenseParticipantShare(userId: payerId, shareType: .treat)]
            return Configuration(splitStrategy: .payerTreat,
                                 includePayer: false,
                                 participants: participants)
        }
    }
}

enum SharedLedgerQuickAddError: LocalizedError, Equatable {
    case noMembers

    var errorDescription: String? {
        switch self {
        case .noMembers:
            return L.personalSaveAndShareMembersMissing.localized
        }
    }
}

