import XCTest
@testable import DeucesCore

/// Automated stand-in for iPhone + iPad Messages testing.
/// These cover the regressions reported in device QA before hardware is needed.
@MainActor
final class EndToEndTests: XCTestCase {

    // MARK: - Composer / bubble lifecycle

    func testCreateDoesNotAskForNameAndDoesNotAutoOpenGame() async throws {
        let sim = TwoDeviceMessagesSimulator()

        XCTAssertNil(sim.phone.identity)
        await sim.createOnPhone(players: 2)

        XCTAssertNil(sim.phone.state)
        XCTAssertNil(sim.pad.state)
        XCTAssertFalse(sim.phone.needsToJoin)

        let url = try XCTUnwrap(sim.latestBubbleURL)
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "deuces.game")

        let state = try GameStateCodec.parseURL(url)
        XCTAssertEqual(state.numPlayers, 2)
        XCTAssertTrue(state.players.allSatisfy { !$0.claimed })
        XCTAssertEqual(GameBubbleCopy.title(for: state), "Deuces (2 players)")
        XCTAssertEqual(GameBubbleCopy.subtitle(for: state), "Tap to join")
    }

    func testBubbleTitlesForAllPlayerCounts() {
        for count in DeucesEngine.allowedPlayerCounts {
            let state = DeucesEngine.createGame(numPlayers: count)
            let title = GameBubbleCopy.title(for: state)
            if count == 1 {
                XCTAssertEqual(title, "Deuces (1 player)")
            } else {
                XCTAssertEqual(title, "Deuces (\(count) players)")
            }
            XCTAssertFalse(title.contains("rev"))
            XCTAssertFalse(title.contains("·"))
        }
    }

    func testTappingBubbleShowsJoinNotComposer() async {
        let sim = TwoDeviceMessagesSimulator()
        await sim.createOnPhone(players: 2)

        sim.tapBubble(on: sim.phone)
        XCTAssertNotNil(sim.phone.state)
        XCTAssertTrue(sim.phone.needsToJoin)
        XCTAssertNil(sim.phone.view?.me)
    }

    // MARK: - Shared join flow

    func testSenderAndRecipientJoinTheSameWay() async {
        let sim = TwoDeviceMessagesSimulator()
        await sim.startJoinedTwoPlayerGame()

        let names = Set(sim.phone.state!.players.map(\.displayName))
        XCTAssertEqual(names, ["Andrew", "Sarah"])
        XCTAssertFalse(sim.phone.needsToJoin)
        XCTAssertFalse(sim.pad.needsToJoin)
        XCTAssertEqual(sim.phone.view?.me?.displayName, "Andrew")
        XCTAssertEqual(sim.pad.view?.me?.displayName, "Sarah")
    }

    // MARK: - Turns / play

    func testCannotPlayUntilEveryoneJoined() async {
        let sim = TwoDeviceMessagesSimulator()
        await sim.createOnPhone(players: 2)
        sim.tapBubble(on: sim.phone)
        sim.join(on: sim.phone, name: "Andrew")

        XCTAssertFalse(sim.phone.view?.isMyTurn ?? true)
        let card = sim.phone.view!.me!.hand.min()!
        sim.phone.play(cards: [card])
        XCTAssertEqual(sim.phone.errorMessage, DeucesError.waitingForPlayers.errorDescription)
    }

    func testAfterPlayTurnPassesToOtherPlayer() async {
        let sim = TwoDeviceMessagesSimulator()
        await sim.startJoinedTwoPlayerGame()

        let before = sim.phone.state!.turn
        let actor = sim.currentActor()!
        XCTAssertTrue(actor.view?.isMyTurn == true)

        sim.playLowestCard(from: actor)

        let after = sim.phone.state!.turn
        XCTAssertEqual(after, (before + 1) % 2)
        XCTAssertFalse(actor.view?.isMyTurn == true)

        let other = actor === sim.phone ? sim.pad : sim.phone
        XCTAssertTrue(other.view?.isMyTurn == true)
    }

    func testPassAdvancesTurnAndDraws() async {
        let sim = TwoDeviceMessagesSimulator()
        await sim.startJoinedTwoPlayerGame()

        let first = sim.currentActor()!
        sim.playLowestCard(from: first)

        let second = sim.currentActor()!
        let poolBefore = second.state!.poolSize
        let handBefore = second.view!.me!.hand.count
        let turnBefore = second.state!.turn
        let passerID = second.identity!.id
        second.pass()

        XCTAssertNotEqual(sim.phone.state?.turn, turnBefore)
        XCTAssertNotEqual(sim.pad.state?.turn, turnBefore)
        XCTAssertTrue(sim.phone.state?.run.isEmpty == true)
        XCTAssertEqual(sim.phone.state!.poolSize, poolBefore - 1)
        let passerHand = sim.phone.state!.players.first(where: { $0.id == passerID })!.hand.count
        XCTAssertEqual(passerHand, handBefore + 1)
    }

    // MARK: - Reopen / identity

    func testReopenBubbleRestoresSeatWithoutComposer() async throws {
        let sim = TwoDeviceMessagesSimulator()
        await sim.startJoinedTwoPlayerGame()

        let gameID = try XCTUnwrap(sim.phone.state?.gameID)
        let phonePlayerID = try XCTUnwrap(sim.phone.identity?.id)
        let bubble = try XCTUnwrap(sim.latestBubbleURL)

        sim.phone.clearGame()
        XCTAssertNil(sim.phone.state)

        XCTAssertTrue(sim.phone.open(url: bubble))
        XCTAssertEqual(sim.phone.state?.gameID, gameID)
        XCTAssertFalse(sim.phone.needsToJoin)
        XCTAssertEqual(sim.phone.view?.me?.id, phonePlayerID)
        XCTAssertEqual(sim.phone.view?.me?.displayName, "Andrew")
    }

    func testLiveUpdateWhileBothHaveGameOpen() async {
        let sim = TwoDeviceMessagesSimulator()
        await sim.startJoinedTwoPlayerGame()

        let actor = sim.currentActor()!
        let other = actor === sim.phone ? sim.pad : sim.phone
        let beforeRev = other.state!.revision

        sim.playLowestCard(from: actor)

        XCTAssertEqual(other.state?.revision, beforeRev + 1)
        XCTAssertEqual(other.state?.ply, 1)
        XCTAssertEqual(sim.phone.state?.run, sim.pad.state?.run)
    }

    // MARK: - Solo

    func testOnePlayerFlowCanPlayImmediatelyAfterJoin() async throws {
        let sim = TwoDeviceMessagesSimulator()
        await sim.createOnPhone(players: 1)
        let url = try XCTUnwrap(sim.latestBubbleURL)
        XCTAssertEqual(GameBubbleCopy.title(for: try GameStateCodec.parseURL(url)), "Deuces (1 player)")

        sim.tapBubble(on: sim.phone)
        sim.join(on: sim.phone, name: "Solo")
        XCTAssertTrue(sim.phone.state!.allSeatsClaimed)
        XCTAssertTrue(sim.phone.view?.isMyTurn == true)

        let lowest = try XCTUnwrap(sim.phone.view?.me?.hand.min())
        sim.phone.play(cards: [lowest])
        XCTAssertEqual(sim.phone.state?.ply, 1)
        XCTAssertEqual(sim.phone.state?.turn, 0)
        XCTAssertTrue(sim.phone.view?.isMyTurn == true)
    }

    // MARK: - URL resilience

    func testBubbleURLSurvivesPercentEncodingRoundTrip() throws {
        var state = DeucesEngine.createGame(numPlayers: 3)
        state = try DeucesEngine.join(state: state, playerID: UUID(), displayName: "A")
        state = try DeucesEngine.join(state: state, playerID: UUID(), displayName: "B")
        state = try DeucesEngine.join(state: state, playerID: UUID(), displayName: "C")

        let url = try GameStateCodec.makeURL(state: state)
        let echoed = try XCTUnwrap(URL(string: url.absoluteString))
        let decoded = try GameStateCodec.parseURL(echoed)
        XCTAssertEqual(decoded.gameID, state.gameID)
        XCTAssertEqual(decoded.players.map(\.displayName), state.players.map(\.displayName))
        XCTAssertLessThan(url.absoluteString.count, 6000)
    }

    func testLegacyCustomSchemeStillOpens() throws {
        let state = DeucesEngine.createGame(numPlayers: 2)
        let payload = try GameStateCodec.encode(state).base64URLEncodedString()
        let legacy = URL(string: "deuces://game?s=\(payload)")!
        let decoded = try GameStateCodec.parseURL(legacy)
        XCTAssertEqual(decoded.gameID, state.gameID)
    }
}
