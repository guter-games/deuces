import XCTest
@testable import DeucesCore

@MainActor
final class SessionControllerTests: XCTestCase {
    func testInMemoryBackendCreateJoinPlay() async {
        let backend = InMemoryDeucesBackend()
        let left = GameSessionController(
            backend: backend,
            seatStore: InMemorySeatStore(),
            identityStore: InMemoryIdentityStore()
        )
        let right = GameSessionController(
            backend: backend,
            seatStore: InMemorySeatStore(),
            identityStore: InMemoryIdentityStore()
        )

        left.createGame(numPlayers: 2, openLocally: true)
        await TestSupport.waitUntil { left.invite != nil }
        let invite = left.invite!
        await right.openInvite(invite)

        left.setDisplayName("A")
        left.joinIfNeeded()
        await TestSupport.waitUntil { left.update?.me != nil }

        right.setDisplayName("B")
        right.joinIfNeeded()
        await TestSupport.waitUntil { right.update?.me != nil && left.update?.others.contains(where: { $0.name == "B" }) == true }

        let actor = left.update?.me?.isMyTurn == true ? left : right
        let lowest = actor.update!.me!.cards.min()!
        actor.play(cards: [lowest])
        await TestSupport.waitUntil { left.update?.run.isEmpty == false }
        XCTAssertEqual(left.update?.run.last, [lowest])
        XCTAssertEqual(right.update?.run.last, [lowest])
    }
}
