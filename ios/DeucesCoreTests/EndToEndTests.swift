import XCTest
@testable import DeucesCore

/// Server-backed flow (invite bubble is only a game id pointer).
@MainActor
final class EndToEndTests: XCTestCase {

    func testCreateSendsInviteWithoutOpeningLocally() async throws {
        let sim = TwoClientSimulator()
        await sim.createOnPhone(players: 2)
        let invite = try XCTUnwrap(sim.lastInvite)
        XCTAssertEqual(invite.numPlayers, 2)
        XCTAssertFalse(invite.gameID.isEmpty)
        XCTAssertNil(sim.phone.update)
        XCTAssertNil(sim.pad.invite)
    }

    func testBothClientsJoinSameServerGame() async {
        let sim = TwoClientSimulator()
        await sim.createOnPhone(players: 2)
        await sim.tapInvite(on: sim.phone)
        await sim.join(on: sim.phone, name: "Andrew")
        await sim.tapInvite(on: sim.pad)
        await sim.join(on: sim.pad, name: "Sarah")

        XCTAssertEqual(sim.phone.update?.me?.name, "Andrew")
        XCTAssertEqual(sim.pad.update?.me?.name, "Sarah")
        XCTAssertEqual(sim.phone.invite?.gameID, sim.pad.invite?.gameID)
        // Both see the other player.
        XCTAssertTrue(sim.phone.update?.others.contains(where: { $0.name == "Sarah" }) == true)
        XCTAssertTrue(sim.pad.update?.others.contains(where: { $0.name == "Andrew" }) == true)
    }

    func testPlaySyncsOverServerNotInviteBubble() async {
        let sim = TwoClientSimulator()
        await sim.createOnPhone(players: 2)
        await sim.tapInvite(on: sim.phone)
        await sim.join(on: sim.phone, name: "Andrew")
        await sim.tapInvite(on: sim.pad)
        await sim.join(on: sim.pad, name: "Sarah")

        let inviteBefore = sim.lastInvite
        let actorIsPhone = sim.phone.update?.me?.isMyTurn == true
        let actor = actorIsPhone ? sim.phone : sim.pad
        let other = actorIsPhone ? sim.pad : sim.phone
        let lowest = actor.update!.me!.cards.min()!
        actor.play(cards: [lowest])

        await TestSupport.waitUntil {
            other.update?.run.last == [lowest] && actor.update?.run.last == [lowest]
        }
        // Invite bubble must not be rewritten for plays.
        XCTAssertEqual(sim.lastInvite, inviteBefore)
        XCTAssertNotEqual(actor.update?.me?.isMyTurn, true)
        XCTAssertEqual(other.update?.me?.isMyTurn, true)
    }

    func testRematchCreatesNewGameId() async {
        let sim = TwoClientSimulator()
        await sim.createOnPhone(players: 2)
        let first = sim.lastInvite!.gameID
        await sim.tapInvite(on: sim.phone)
        await sim.join(on: sim.phone, name: "Solo")

        // Force finish isn't trivial; just call startRematch (= new create).
        sim.phone.startRematch()
        await TestSupport.waitUntil { sim.lastInvite?.gameID != first }
        XCTAssertNotEqual(sim.lastInvite?.gameID, first)
        XCTAssertNil(sim.phone.invite, "Rematch clears local until the new bubble is tapped")
    }

    func testReopenRestoresSeatWithoutJoiningAgain() async {
        let sim = TwoClientSimulator()
        await sim.createOnPhone(players: 2)
        await sim.tapInvite(on: sim.phone)
        await sim.join(on: sim.phone, name: "Andrew")
        let invite = sim.lastInvite!

        sim.phone.clearGame()
        XCTAssertNil(sim.phone.invite)

        await sim.phone.openInvite(invite)
        await TestSupport.waitUntil { sim.phone.needsToJoin == false && sim.phone.update?.me?.name == "Andrew" }
        XCTAssertFalse(sim.phone.needsToJoin)
    }
}
