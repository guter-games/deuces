import XCTest
@testable import DeucesCore

@MainActor
final class SessionControllerTests: XCTestCase {
    func testLocalTransportSyncsJoinAndPlay() async throws {
        let (leftTransport, rightTransport) = LocalGameTransport.paired()

        let left = GameSessionController(
            transport: leftTransport,
            identityStore: InMemoryIdentityStore(),
            membershipStore: TestSupport.ephemeralMembershipStore()
        )
        let right = GameSessionController(
            transport: rightTransport,
            identityStore: InMemoryIdentityStore(),
            membershipStore: TestSupport.ephemeralMembershipStore()
        )

        left.createGame(numPlayers: 2, openLocally: true)
        await TestSupport.waitUntil { right.state?.gameID == left.state?.gameID }

        left.setDisplayName("Andrew")
        left.joinIfNeeded()
        await TestSupport.waitUntil { right.state?.players.filter(\.claimed).count == 1 }

        right.setDisplayName("Sarah")
        right.joinIfNeeded()
        await TestSupport.waitUntil {
            left.state?.allSeatsClaimed == true && right.state?.allSeatsClaimed == true
        }

        let beforeTurn = left.state!.turn
        let turnID = left.state!.players[beforeTurn].id
        let actor = turnID == left.identity!.id ? left : right
        let lowest = actor.state!.players[beforeTurn].hand.min()!
        actor.play(cards: [lowest])

        await TestSupport.waitUntil {
            left.state?.ply == 1
                && right.state?.ply == 1
                && left.state?.turn == (beforeTurn + 1) % 2
        }
        XCTAssertEqual(left.state?.run.last, [lowest])
    }
}
