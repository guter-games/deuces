import XCTest
@testable import DeucesCore

final class CodecTests: XCTestCase {
    func testInviteURLRoundTrip() throws {
        let invite = GameInvite(gameID: "abc123XYZ", numPlayers: 3)
        let url = try GameInviteURL.makeURL(invite)
        XCTAssertEqual(url.host, "deuces.game")
        XCTAssertTrue(url.path.contains("abc123XYZ"))
        let parsed = try GameInviteURL.parse(url)
        XCTAssertEqual(parsed, invite)
    }

    func testInviteURLRejectsStatePayloadStyleURLs() {
        let url = URL(string: "https://deuces.game/g?s=not-a-game-id")!
        XCTAssertThrowsError(try GameInviteURL.parse(url))
    }

    func testBubbleCopy() {
        let invite = GameInvite(gameID: "x", numPlayers: 2)
        XCTAssertEqual(GameBubbleCopy.title(for: invite), "Deuces (2 players)")
        XCTAssertEqual(GameBubbleCopy.subtitle(for: invite), "Tap to join")
    }

    func testWebDeepLinkShape() throws {
        let url = URL(string: "https://gregoryguterman.com/deuces/shortIdHere")!
        let invite = try GameInviteURL.parse(url)
        XCTAssertEqual(invite.gameID, "shortIdHere")
    }
}
