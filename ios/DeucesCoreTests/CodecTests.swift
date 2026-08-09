import XCTest
@testable import DeucesCore

final class CodecTests: XCTestCase {
    func testRoundTripPreservesState() throws {
        var rng = LCG(seed: 99)
        var state = DeucesEngine.createGame(
            numPlayers: 4,
            now: Date(timeIntervalSince1970: 1_700_000_000),
            rng: &rng
        )
        state = try DeucesEngine.join(state: state, playerID: UUID(), displayName: "Andrew")
        state = try DeucesEngine.join(state: state, playerID: UUID(), displayName: "Sarah")
        state = try DeucesEngine.join(state: state, playerID: UUID(), displayName: "John")
        state = try DeucesEngine.join(state: state, playerID: UUID(), displayName: "Maya")

        let turnID = state.players[state.turn].id
        let lowest = state.players[state.turn].hand.min()!
        state = try DeucesEngine.playCards(state: state, playerID: turnID, cards: [lowest])

        // Normalize dates to whole seconds so codec round-trip compares cleanly.
        state.createdAt = Date(timeIntervalSince1970: state.createdAt.timeIntervalSince1970.rounded())
        for index in state.players.indices {
            if let active = state.players[index].lastActiveAt {
                state.players[index].lastActiveAt = Date(timeIntervalSince1970: active.timeIntervalSince1970.rounded())
            }
        }

        let encoded = try GameStateCodec.encode(state)
        let decoded = try GameStateCodec.decode(encoded)
        XCTAssertEqual(decoded, state)

        let url = try GameStateCodec.makeURL(state: state)
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "deuces.game")
        let fromURL = try GameStateCodec.parseURL(url)
        XCTAssertEqual(fromURL, state)

        XCTAssertLessThan(url.absoluteString.count, 6000, "URL payload growing large for MSMessage.url")
        print("Encoded URL length: \(url.absoluteString.count), binary bytes: \(encoded.count)")
    }

    func testBubbleTitle() {
        let state = DeucesEngine.createGame(numPlayers: 2)
        XCTAssertEqual(GameBubbleCopy.title(for: state), "Deuces (2 players)")
        XCTAssertEqual(GameBubbleCopy.subtitle(for: state), "Tap to join")
    }

    func testActivityLabels() {
        let now = Date()
        XCTAssertEqual(ActivityLabel.format(lastActiveAt: now, now: now), "active just now")
        XCTAssertEqual(
            ActivityLabel.format(lastActiveAt: now.addingTimeInterval(-120), now: now),
            "2m ago"
        )
        XCTAssertEqual(
            ActivityLabel.format(lastActiveAt: now.addingTimeInterval(-18 * 60), now: now),
            "18m ago"
        )
        XCTAssertEqual(ActivityLabel.format(lastActiveAt: nil, now: now), "not yet active")
    }
}
