import XCTest
@testable import DeucesCore

/// Mirrors key cases from `server/tests` and `server/hand.js` scoring behavior.
final class JSParityTests: XCTestCase {
    func testCardValuesMatchJSOrdering() {
        // 3♦ is the lowest card in Deuces.
        let threeDiamonds = Card(suit: .diamonds, rank: .three)
        let threeClubs = Card(suit: .clubs, rank: .three)
        let twoSpades = Card(suit: .spades, rank: .two)

        XCTAssertEqual(threeDiamonds.value, 1)
        XCTAssertEqual(threeClubs.value, 2)
        XCTAssertLessThan(threeDiamonds.value, threeClubs.value)
        XCTAssertLessThan(threeClubs.value, twoSpades.value)
        XCTAssertEqual(twoSpades.value, 52)
    }

    func testPairsOfSameRankFromServerTest() {
        // server/tests/_test_pairs_of_same_rank.js
        let mine = Hand(cards: [
            Card(suit: .hearts, rank: .nine),
            Card(suit: .clubs, rank: .nine),
        ])
        let hers = Hand(cards: [
            Card(suit: .diamonds, rank: .nine),
            Card(suit: .spades, rank: .nine),
        ])

        XCTAssertEqual(mine.value, hers.value)
        XCTAssertFalse(mine.isBetterThan(hers))
        XCTAssertTrue(hers.isBetterThan(mine))
    }

    func testPlayValidationWrongLength() {
        let error = DeucesEngine.validatePlay(
            playerCards: [
                Card(suit: .hearts, rank: .five),
                Card(suit: .clubs, rank: .five),
                Card(suit: .diamonds, rank: .six),
            ],
            cards: [Card(suit: .diamonds, rank: .six)],
            run: [[
                Card(suit: .spades, rank: .three),
                Card(suit: .hearts, rank: .three),
            ]],
            ply: 2
        )
        XCTAssertEqual(error, .wrongNumberOfCards)
    }
}
