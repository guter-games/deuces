import XCTest
@testable import DeucesCore

final class HandTests: XCTestCase {
    func testPairValuesMatchSpadeTieBreak() {
        let heartsClubs = Hand(cards: [
            Card(suit: .hearts, rank: .nine),
            Card(suit: .clubs, rank: .nine),
        ])
        let diamondsSpades = Hand(cards: [
            Card(suit: .diamonds, rank: .nine),
            Card(suit: .spades, rank: .nine),
        ])

        XCTAssertEqual(heartsClubs.value, diamondsSpades.value)
        XCTAssertFalse(heartsClubs.isBetterThan(diamondsSpades))
        XCTAssertTrue(diamondsSpades.isBetterThan(heartsClubs))
    }

    func testHighCardIsValid() {
        let hand = Hand(cards: [Card(suit: .diamonds, rank: .three)])
        XCTAssertEqual(hand.handType, .highCard)
        XCTAssertGreaterThan(hand.value, 0)
    }

    func testInvalidTwoCardHand() {
        let hand = Hand(cards: [
            Card(suit: .hearts, rank: .three),
            Card(suit: .clubs, rank: .four),
        ])
        XCTAssertEqual(hand.handType, .invalid)
        XCTAssertEqual(hand.value, 0)
    }

    func testStraightFlushAndRoyal() {
        let straightFlush = Hand(cards: [
            Card(suit: .hearts, rank: .three),
            Card(suit: .hearts, rank: .four),
            Card(suit: .hearts, rank: .five),
            Card(suit: .hearts, rank: .six),
            Card(suit: .hearts, rank: .seven),
        ])
        XCTAssertEqual(straightFlush.handType, .straightFlush)

        let royal = Hand(cards: [
            Card(suit: .spades, rank: .ten),
            Card(suit: .spades, rank: .jack),
            Card(suit: .spades, rank: .queen),
            Card(suit: .spades, rank: .king),
            Card(suit: .spades, rank: .ace),
        ])
        XCTAssertEqual(royal.handType, .royalFlush)
        XCTAssertTrue(royal.isBetterThan(straightFlush))
    }

    func testFullHouseAndFourOfAKind() {
        let fullHouse = Hand(cards: [
            Card(suit: .hearts, rank: .eight),
            Card(suit: .clubs, rank: .eight),
            Card(suit: .diamonds, rank: .eight),
            Card(suit: .spades, rank: .three),
            Card(suit: .hearts, rank: .three),
        ])
        XCTAssertEqual(fullHouse.handType, .fullHouse)

        let quads = Hand(cards: [
            Card(suit: .hearts, rank: .five),
            Card(suit: .clubs, rank: .five),
            Card(suit: .diamonds, rank: .five),
            Card(suit: .spades, rank: .five),
            Card(suit: .hearts, rank: .nine),
        ])
        XCTAssertEqual(quads.handType, .fourOfAKind)
        XCTAssertTrue(quads.isBetterThan(fullHouse))
    }

    func testThreeOfAKind() {
        let trips = Hand(cards: [
            Card(suit: .hearts, rank: .king),
            Card(suit: .clubs, rank: .king),
            Card(suit: .diamonds, rank: .king),
        ])
        XCTAssertEqual(trips.handType, .threeOfAKind)
        XCTAssertGreaterThan(trips.value, 0)
    }
}
