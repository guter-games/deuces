import XCTest
@testable import DeucesCore

final class EngineTests: XCTestCase {
    func testCreateDealsExpectedCounts() {
        var rng = LCG(seed: 42)
        let two = DeucesEngine.createGame(numPlayers: 2, rng: &rng)
        XCTAssertEqual(two.players[0].hand.count, 17)
        XCTAssertEqual(two.players[1].hand.count, 17)
        XCTAssertEqual(two.pool.count, 18)
        XCTAssertEqual(two.phase, .playing)
        XCTAssertTrue(two.players.allSatisfy { !$0.claimed })

        var rng1 = LCG(seed: 1)
        let one = DeucesEngine.createGame(numPlayers: 1, rng: &rng1)
        XCTAssertEqual(one.players.count, 1)
        XCTAssertEqual(one.players[0].hand.count, 4)
        XCTAssertEqual(one.pool.count, 0)
        XCTAssertEqual(Set(one.players[0].hand), Set(DeucesEngine.soloPracticeDeck))
        XCTAssertEqual(one.phase, .playing)

        var rng3 = LCG(seed: 7)
        let three = DeucesEngine.createGame(numPlayers: 3, rng: &rng3)
        // 17*3 + 1 to starter = 52
        XCTAssertEqual(three.players.map(\.hand.count).reduce(0, +), 52)
        XCTAssertEqual(three.pool.count, 0)

        var rng4 = LCG(seed: 9)
        let four = DeucesEngine.createGame(numPlayers: 4, rng: &rng4)
        XCTAssertTrue(four.players.allSatisfy { $0.hand.count == 13 })
        XCTAssertEqual(four.pool.count, 0)
    }

    func testEveryoneJoinsTheSameWay() throws {
        let a = UUID()
        let b = UUID()
        var state = DeucesEngine.createGame(numPlayers: 2)
        XCTAssertEqual(state.players.filter(\.claimed).count, 0)

        state = try DeucesEngine.join(state: state, playerID: a, displayName: "Andrew")
        XCTAssertEqual(state.players.filter(\.claimed).count, 1)
        XCTAssertFalse(state.allSeatsClaimed)

        state = try DeucesEngine.join(state: state, playerID: b, displayName: "Sarah")
        XCTAssertTrue(state.allSeatsClaimed)
        XCTAssertEqual(state.revision, 2)
    }

    func testTurnAdvancesToOtherPlayer() throws {
        let host = UUID()
        let guest = UUID()
        var state = makeReadyTwoPlayerGame(host: host, guest: guest)
        let first = state.turn
        let firstID = state.players[first].id
        let lowest = state.players[first].hand.min()!

        state = try DeucesEngine.playCards(state: state, playerID: firstID, cards: [lowest])
        XCTAssertEqual(state.turn, (first + 1) % 2)
        XCTAssertNotEqual(state.players[state.turn].id, firstID)
    }

    func testCanPlayBeforeAllPlayersJoinWhenItIsYourTurn() throws {
        let host = UUID()
        var state = DeucesEngine.createGame(numPlayers: 2)
        state = try DeucesEngine.join(state: state, playerID: host, displayName: "Host")
        XCTAssertFalse(state.allSeatsClaimed)
        XCTAssertEqual(state.playerIndex(for: host), state.turn)

        let card = state.players[state.turn].hand.min()!
        state = try DeucesEngine.playCards(state: state, playerID: host, cards: [card])
        XCTAssertEqual(state.ply, 1)
        XCTAssertEqual(state.run.last, [card])
    }

    func testConcurrentJoinsMergeBothClaims() throws {
        let andrew = UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!
        let sarah = UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!
        let base = DeucesEngine.createGame(numPlayers: 2)

        let phoneOnly = try DeucesEngine.join(state: base, playerID: andrew, displayName: "Andrew")
        let padOnly = try DeucesEngine.join(state: base, playerID: sarah, displayName: "Sarah")
        XCTAssertEqual(phoneOnly.players.filter(\.claimed).count, 1)
        XCTAssertEqual(padOnly.players.filter(\.claimed).count, 1)
        XCTAssertEqual(phoneOnly.revision, padOnly.revision)

        let merged = DeucesEngine.mergeRemote(local: phoneOnly, remote: padOnly)
        let names = Set(merged.players.filter(\.claimed).map(\.displayName))
        XCTAssertEqual(names, ["Andrew", "Sarah"])
        XCTAssertTrue(merged.allSeatsClaimed)
        XCTAssertGreaterThan(merged.revision, max(phoneOnly.revision, padOnly.revision))

        // Symmetric merge must converge.
        let mergedFlip = DeucesEngine.mergeRemote(local: padOnly, remote: phoneOnly)
        XCTAssertEqual(
            Set(merged.players.filter(\.claimed).map(\.id)),
            Set(mergedFlip.players.filter(\.claimed).map(\.id))
        )
    }

    func testPartialJoinIsStillYourTurn() throws {
        let host = UUID()
        var state = DeucesEngine.createGame(numPlayers: 2)
        state = try DeucesEngine.join(state: state, playerID: host, displayName: "Host")
        let view = DeucesEngine.view(for: state, localPlayerID: host)
        XCTAssertTrue(view.isMyTurn)
        XCTAssertFalse(state.allSeatsClaimed)
    }

    func testFirstPlayMustIncludeLowestCard() throws {
        let host = UUID()
        let guest = UUID()
        var state = makeReadyTwoPlayerGame(host: host, guest: guest)

        let turnID = state.players[state.turn].id
        let hand = state.players[state.turn].hand
        let lowest = hand.min()!
        let notLowest = hand.filter { $0 != lowest }.sorted().last!

        XCTAssertThrowsError(
            try DeucesEngine.playCards(state: state, playerID: turnID, cards: [notLowest])
        ) { error in
            XCTAssertEqual(error as? DeucesError, .mustPlayLowestCard)
        }

        state = try DeucesEngine.playCards(state: state, playerID: turnID, cards: [lowest])
        XCTAssertEqual(state.ply, 1)
        XCTAssertEqual(state.run.last, [lowest])
        XCTAssertFalse(state.players[state.playerIndex(for: turnID)!].hand.contains(lowest))
    }

    func testCannotPassOnFreeTurn() throws {
        let host = UUID()
        let guest = UUID()
        let state = makeReadyTwoPlayerGame(host: host, guest: guest)
        let turnID = state.players[state.turn].id

        XCTAssertThrowsError(try DeucesEngine.pass(state: state, playerID: turnID)) { error in
            XCTAssertEqual(error as? DeucesError, .cannotPassOnFreeTurn)
        }
    }

    func testPassClearsRunWhenEveryonePasses() throws {
        let host = UUID()
        let guest = UUID()
        var state = makeReadyTwoPlayerGame(host: host, guest: guest)
        let first = state.players[state.turn].id
        let lowest = state.players[state.turn].hand.min()!
        state = try DeucesEngine.playCards(state: state, playerID: first, cards: [lowest])

        let second = state.players[state.turn].id
        let poolBefore = state.pool.count
        state = try DeucesEngine.pass(state: state, playerID: second)

        XCTAssertTrue(state.run.isEmpty)
        XCTAssertEqual(state.passes, 0)
        XCTAssertEqual(state.pool.count, poolBefore - 1)
    }

    func testNotYourTurnRejected() throws {
        let host = UUID()
        let guest = UUID()
        let state = makeReadyTwoPlayerGame(host: host, guest: guest)
        let other = state.players.first(where: { $0.id != state.players[state.turn].id })!.id
        let card = state.players[state.playerIndex(for: other)!].hand[0]

        XCTAssertThrowsError(
            try DeucesEngine.playCards(state: state, playerID: other, cards: [card])
        ) { error in
            XCTAssertEqual(error as? DeucesError, .notYourTurn)
        }
    }

    func testMergeRemotePrefersHigherRevision() {
        var local = DeucesEngine.createGame(numPlayers: 2)
        var remote = local
        remote.revision = 3
        remote.ply = 2

        let merged = DeucesEngine.mergeRemote(local: local, remote: remote)
        XCTAssertEqual(merged.revision, 3)

        local.revision = 5
        let kept = DeucesEngine.mergeRemote(local: local, remote: remote)
        XCTAssertEqual(kept.revision, 5)
    }

    func testWinWhenHandEmptied() throws {
        let player = UUID()
        var state = GameState(
            revision: 0,
            phase: .playing,
            players: [
                PlayerState(id: player, displayName: "Solo", hand: [Card(suit: .diamonds, rank: .three)], claimed: true),
                PlayerState(id: UUID(), displayName: "Other", hand: [Card(suit: .spades, rank: .two)], claimed: true),
            ],
            pool: [],
            run: [],
            turn: 0,
            ply: 1
        )

        state = try DeucesEngine.playCards(
            state: state,
            playerID: player,
            cards: [Card(suit: .diamonds, rank: .three)]
        )
        XCTAssertEqual(state.phase, .finished)
        XCTAssertEqual(state.winnerName, "Solo")
    }

    private func makeReadyTwoPlayerGame(host: UUID, guest: UUID) -> GameState {
        var rng = LCG(seed: 123)
        var state = DeucesEngine.createGame(numPlayers: 2, rng: &rng)
        state = try! DeucesEngine.join(state: state, playerID: host, displayName: "Host")
        state = try! DeucesEngine.join(state: state, playerID: guest, displayName: "Guest")
        return state
    }
}

struct LCG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 0xDEADBEEF : seed
    }

    mutating func next() -> UInt64 {
        state = 2862933555777941757 &* state &+ 3037000493
        return state
    }
}
