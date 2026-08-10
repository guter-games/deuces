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
}

final class InMemoryIdentityStore: PlayerIdentityStore {
    private var identity: PlayerIdentity?
    init(_ identity: PlayerIdentity? = nil) { self.identity = identity }
    func load() -> PlayerIdentity? { identity }
    func save(_ identity: PlayerIdentity) { self.identity = identity }
}

@MainActor
final class CaptureInviteTransport: InviteTransport {
    private(set) var last: GameInvite?
    private(set) var bumpCount = 0
    var onInvite: ((GameInvite) -> Void)?

    func sendInvite(_ invite: GameInvite) {
        last = invite
        onInvite?(invite)
    }

    func bumpInvite(_ invite: GameInvite) {
        last = invite
        bumpCount += 1
    }
}

/// Two clients on one in-memory server (same architecture as web, no Messages state).
@MainActor
final class TwoClientSimulator {
    let backend = InMemoryDeucesBackend()
    let invites = CaptureInviteTransport()
    let phone: GameSessionController
    let pad: GameSessionController

    init() {
        phone = GameSessionController(
            backend: backend,
            inviteTransport: invites,
            seatStore: InMemorySeatStore(),
            identityStore: InMemoryIdentityStore()
        )
        pad = GameSessionController(
            backend: backend,
            seatStore: InMemorySeatStore(),
            identityStore: InMemoryIdentityStore()
        )
    }

    var lastInvite: GameInvite? { invites.last }

    func createOnPhone(players: Int) async {
        phone.createGame(numPlayers: players, openLocally: false)
        await TestSupport.waitUntil { self.invites.last != nil }
        XCTAssertNil(phone.invite, "Composer should not auto-open after create")
    }

    func tapInvite(on device: GameSessionController) async {
        let invite = try! XCTUnwrap(lastInvite)
        await device.openInvite(invite)
        await TestSupport.waitUntil { device.invite?.gameID == invite.gameID }
    }

    func join(on device: GameSessionController, name: String) async {
        device.setDisplayName(name)
        XCTAssertTrue(device.needsToJoin)
        device.joinIfNeeded()
        await TestSupport.waitUntil { device.needsToJoin == false && device.update?.me != nil }
    }
}
