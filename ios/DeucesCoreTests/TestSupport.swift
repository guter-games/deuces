import XCTest
@testable import DeucesCore

@MainActor
enum TestSupport {
    static func waitUntil(
        timeout: TimeInterval = 2,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ condition: @escaping () -> Bool
    ) async {
        let start = Date()
        while !condition() {
            if Date().timeIntervalSince(start) > timeout {
                XCTFail("Timed out waiting for condition", file: file, line: line)
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    static func ephemeralMembershipStore() -> GameMembershipStore {
        GameMembershipStore(defaults: UserDefaults(suiteName: UUID().uuidString)!)
    }
}

/// Two-device simulator that follows the real Messages UX:
/// create → dismiss → tap bubble → name/join → play → reopen.
@MainActor
final class TwoDeviceMessagesSimulator {
    let phoneTransport: MessagesLikeTransport
    let padTransport: MessagesLikeTransport
    let phone: GameSessionController
    let pad: GameSessionController

    init() {
        let (a, b) = MessagesLikeTransport.paired()
        phoneTransport = a
        padTransport = b

        phone = GameSessionController(
            transport: a,
            identityStore: InMemoryIdentityStore(),
            membershipStore: TestSupport.ephemeralMembershipStore()
        )
        pad = GameSessionController(
            transport: b,
            identityStore: InMemoryIdentityStore(),
            membershipStore: TestSupport.ephemeralMembershipStore()
        )

        a.controller = phone
        b.controller = pad

        // After inserting a new game, Messages collapses and clears local game UI.
        a.onNewGameInserted = { [weak phone] in
            phone?.clearGame()
        }
        b.onNewGameInserted = { [weak pad] in
            pad?.clearGame()
        }
    }

    var latestBubbleURL: URL? {
        phoneTransport.thread.latestBubbleURL
    }

    var claimedCountInLatestBubble: Int {
        phoneTransport.thread.bubbles.last?.state.players.filter(\.claimed).count ?? 0
    }

    func createOnPhone(players: Int) async {
        phone.createGame(numPlayers: players, openLocally: false)
        XCTAssertNil(phone.state)
        XCTAssertNotNil(latestBubbleURL)
    }

    func tapBubble(on device: GameSessionController) {
        guard let url = latestBubbleURL else {
            XCTFail("No bubble URL to open")
            return
        }
        XCTAssertTrue(device.open(url: url), "Bubble URL should decode")
    }

    func join(on device: GameSessionController, name: String) {
        let bubblesBefore = phoneTransport.thread.bubbles.count
        XCTAssertTrue(device.needsToJoin, "Device should need to join before claiming a seat")
        device.setDisplayName(name)
        device.joinIfNeeded()
        XCTAssertNotNil(device.view?.me)
        XCTAssertFalse(device.needsToJoin)
        XCTAssertGreaterThan(phoneTransport.thread.bubbles.count, bubblesBefore)
    }

    /// Full happy-path setup: create 2p, both devices join.
    func startJoinedTwoPlayerGame(phoneName: String = "Andrew", padName: String = "Sarah") async {
        await createOnPhone(players: 2)
        tapBubble(on: phone)
        join(on: phone, name: phoneName)
        XCTAssertEqual(claimedCountInLatestBubble, 1)

        tapBubble(on: pad)
        join(on: pad, name: padName)

        XCTAssertTrue(phone.state?.allSeatsClaimed == true, "Phone should see both seats after pad join")
        XCTAssertTrue(pad.state?.allSeatsClaimed == true, "Pad should have both seats after join")
        XCTAssertEqual(claimedCountInLatestBubble, 2)
    }

    func currentActor() -> GameSessionController? {
        guard let state = phone.state ?? pad.state else {
            XCTFail("No open game")
            return nil
        }
        let turnID = state.players[state.turn].id
        if phone.identity?.id == turnID { return phone }
        if pad.identity?.id == turnID { return pad }
        XCTFail("Turn belongs to neither device")
        return nil
    }

    func playLowestCard(from actor: GameSessionController) {
        guard let state = actor.state,
              let me = actor.view?.me,
              let index = state.playerIndex(for: me.id) else {
            XCTFail("Actor has no seat")
            return
        }
        let beforeTurn = state.turn
        let beforeRevision = state.revision
        let lowest = state.players[index].hand.min()!
        actor.play(cards: [lowest])
        XCTAssertEqual(phone.state?.revision, beforeRevision + 1)
        XCTAssertEqual(pad.state?.revision, beforeRevision + 1)
        XCTAssertNotEqual(phone.state?.turn, beforeTurn)
        XCTAssertNotEqual(pad.state?.turn, beforeTurn)
    }
}

final class InMemoryIdentityStore: PlayerIdentityStore {
    private var identity: PlayerIdentity?

    init(_ identity: PlayerIdentity? = nil) {
        self.identity = identity
    }

    func load() -> PlayerIdentity? { identity }
    func save(_ identity: PlayerIdentity) { self.identity = identity }
}
