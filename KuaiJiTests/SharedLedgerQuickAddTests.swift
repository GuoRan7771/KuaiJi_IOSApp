import XCTest
@testable import KuaiJi

final class SharedLedgerQuickAddTests: XCTestCase {
    func testEqualSharesIncludesAllMembers() throws {
        let payer = UUID()
        let other = UUID()
        let members = [payer, other]

        let configuration = try SharedLedgerQuickAdd.configuration(for: .equalShares, members: members, payerId: payer)

        XCTAssertEqual(configuration.splitStrategy, .payerAA)
        XCTAssertTrue(configuration.includePayer)
        XCTAssertEqual(configuration.participants.count, 2)
        XCTAssertTrue(configuration.participants.contains(where: { $0.userId == payer && $0.shareType == .aa }))
        XCTAssertTrue(configuration.participants.contains(where: { $0.userId == other && $0.shareType == .aa }))
    }

    func testPayerTreatUsesOnlyPayer() throws {
        let payer = UUID()
        let members = [UUID(), UUID(), payer]

        let configuration = try SharedLedgerQuickAdd.configuration(for: .payerTreat, members: members, payerId: payer)

        XCTAssertEqual(configuration.splitStrategy, .payerTreat)
        XCTAssertFalse(configuration.includePayer)
        XCTAssertEqual(configuration.participants.count, 1)
        XCTAssertEqual(configuration.participants.first?.userId, payer)
        XCTAssertEqual(configuration.participants.first?.shareType, .treat)
    }

    func testNoMembersThrows() {
        XCTAssertThrowsError(try SharedLedgerQuickAdd.configuration(for: .equalShares, members: [], payerId: UUID())) { error in
            guard let quickAddError = error as? SharedLedgerQuickAddError else {
                return XCTFail("Unexpected error type: \(error)")
            }
            XCTAssertEqual(quickAddError, .noMembers)
        }
    }
}

