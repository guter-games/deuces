import XCTest
@testable import DeucesCore

/// End-to-end against the real Node server over LAN (`ServerConfig.lan`).
/// Skips cleanly when the server is not reachable.
@MainActor
final class LiveServerEndToEndTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        let reachable = await LiveServerProbe.isReachable(config: .lan)
        try XCTSkipUnless(
            reachable,
            "LAN server not reachable at \(ServerConfig.lan.createGameURL.absoluteString). Run `make up-server`."
        )
    }

    func testCreateGameHTTP() async throws {
        let backend = HTTPDeucesBackend(config: .lan)
        let id = try await backend.createGame(numPlayers: 2)
        XCTAssertFalse(id.isEmpty)
        XCTAssertLessThan(id.count, 32)
    }

    func testTwoDevicesJoinAndSeeEachOther() async throws {
        let pair = try await LivePair.connected(players: 2)
        defer { pair.shutdown() }

        XCTAssertEqual(pair.phone.update?.me?.name, "Andrew")
        XCTAssertEqual(pair.pad.update?.me?.name, "Sarah")
        XCTAssertTrue(pair.phone.update?.others.contains(where: { $0.name == "Sarah" }) == true)
        XCTAssertTrue(pair.pad.update?.others.contains(where: { $0.name == "Andrew" }) == true)
        XCTAssertEqual(pair.phone.invite?.gameID, pair.pad.invite?.gameID)
    }

    func testPlayAdvancesTurnOnBothClients() async throws {
        let pair = try await LivePair.connected(players: 2)
        defer { pair.shutdown() }

        let phoneTurn = pair.phone.update?.me?.isMyTurn == true
        let actor = phoneTurn ? pair.phone : pair.pad
        let other = phoneTurn ? pair.pad : pair.phone
        let lowest = try XCTUnwrap(actor.update?.me?.cards.min())

        actor.play(cards: [lowest])

        await TestSupport.waitUntil(timeout: 8) {
            other.update?.run.last == [lowest]
                && actor.update?.run.last == [lowest]
                && other.update?.me?.isMyTurn == true
                && actor.update?.me?.isMyTurn == false
        }

        XCTAssertEqual(other.update?.run.last, [lowest])
        XCTAssertTrue(other.update?.me?.isMyTurn == true)
    }

    func testPassSyncsAndDraws() async throws {
        let pair = try await LivePair.connected(players: 2)
        defer { pair.shutdown() }

        let phoneTurn = pair.phone.update?.me?.isMyTurn == true
        let first = phoneTurn ? pair.phone : pair.pad
        let second = phoneTurn ? pair.pad : pair.phone
        let lowest = try XCTUnwrap(first.update?.me?.cards.min())
        first.play(cards: [lowest])
        await TestSupport.waitUntil(timeout: 8) { second.update?.me?.isMyTurn == true }

        let handBefore = second.update!.me!.cards.count
        let poolBefore = second.update!.poolSize
        second.pass()

        await TestSupport.waitUntil(timeout: 8) {
            second.update?.me?.cards.count == handBefore + 1
                && second.update?.poolSize == poolBefore - 1
                && first.update?.me?.isMyTurn == true
        }
        XCTAssertTrue(second.update?.run.isEmpty == true)
    }

    func testOutOfTurnPlayRejected() async throws {
        let pair = try await LivePair.connected(players: 2)
        defer { pair.shutdown() }

        let phoneTurn = pair.phone.update?.me?.isMyTurn == true
        let waiting = phoneTurn ? pair.pad : pair.phone
        let card = try XCTUnwrap(waiting.update?.me?.cards.first)
        waiting.play(cards: [card])

        await TestSupport.waitUntil(timeout: 5) {
            waiting.errorMessage != nil
        }
        XCTAssertNotNil(waiting.errorMessage)
        // Board should not have advanced from the illegal play.
        XCTAssertTrue(waiting.update?.run.isEmpty == true)
    }

    func testReopenRestoresSeatOnLiveServer() async throws {
        let pair = try await LivePair.connected(players: 2)
        let invite = try XCTUnwrap(pair.phone.invite)
        pair.phone.clearGame()
        XCTAssertNil(pair.phone.invite)

        await pair.phone.openInvite(invite)
        await TestSupport.waitUntil(timeout: 8) {
            pair.phone.needsToJoin == false && pair.phone.update?.me?.name == "Andrew"
        }
        XCTAssertEqual(pair.phone.update?.me?.name, "Andrew")
        pair.shutdown()
    }

    func testInviteURLContainsOnlyGameId() async throws {
        let backend = HTTPDeucesBackend(config: .lan)
        let id = try await backend.createGame(numPlayers: 3)
        let invite = GameInvite(gameID: id, numPlayers: 3)
        let url = try GameInviteURL.makeURL(invite)
        XCTAssertFalse(url.absoluteString.contains("s="))
        XCTAssertTrue(url.path.contains(id))
        let parsed = try GameInviteURL.parse(url)
        XCTAssertEqual(parsed.gameID, id)
        XCTAssertEqual(parsed.numPlayers, 3)
    }
}

// MARK: - Helpers

enum LiveServerProbe {
    static func isReachable(config: ServerConfig) async -> Bool {
        var request = URLRequest(url: config.createGameURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["numPlayers": 1])
        request.timeoutInterval = 2
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } ?? false
        } catch {
            return false
        }
    }
}

@MainActor
final class LivePair {
    let phone: GameSessionController
    let pad: GameSessionController

    private init(phone: GameSessionController, pad: GameSessionController) {
        self.phone = phone
        self.pad = pad
    }

    static func connected(players: Int) async throws -> LivePair {
        let backend = HTTPDeucesBackend(config: .lan)
        let phone = GameSessionController(
            backend: backend,
            seatStore: InMemorySeatStore(),
            identityStore: InMemoryIdentityStore()
        )
        let pad = GameSessionController(
            backend: HTTPDeucesBackend(config: .lan),
            seatStore: InMemorySeatStore(),
            identityStore: InMemoryIdentityStore()
        )

        let gameID = try await backend.createGame(numPlayers: players)
        let invite = GameInvite(gameID: gameID, numPlayers: players)

        await phone.openInvite(invite)
        await TestSupport.waitUntil(timeout: 8) { phone.needsToJoin || phone.update != nil }
        phone.setDisplayName("Andrew")
        phone.joinIfNeeded()
        await TestSupport.waitUntil(timeout: 8) { phone.update?.me?.name == "Andrew" }

        await pad.openInvite(invite)
        await TestSupport.waitUntil(timeout: 8) { pad.needsToJoin || pad.update != nil }
        pad.setDisplayName("Sarah")
        pad.joinIfNeeded()
        await TestSupport.waitUntil(timeout: 8) {
            pad.update?.me?.name == "Sarah"
                && phone.update?.others.contains(where: { $0.name == "Sarah" }) == true
        }

        return LivePair(phone: phone, pad: pad)
    }

    func shutdown() {
        phone.clearGame()
        pad.clearGame()
    }
}
