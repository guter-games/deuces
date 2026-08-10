import Foundation

/// Immutable pointer placed in the initial MSMessage bubble.
/// No game state is ever written into Messages — only this invite.
public struct GameInvite: Equatable, Sendable, Codable {
    public var gameID: String
    public var numPlayers: Int

    public init(gameID: String, numPlayers: Int) {
        self.gameID = gameID
        self.numPlayers = numPlayers
    }
}

public enum GameInviteURL {
    public static let host = "deuces.game"
    public static let pathPrefix = "/g/"

    public static func makeURL(_ invite: GameInvite) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = host
        components.path = "\(pathPrefix)\(invite.gameID)"
        components.queryItems = [
            URLQueryItem(name: "n", value: String(invite.numPlayers))
        ]
        guard let url = components.url else { throw InviteURLError.invalid }
        return url
    }

    public static func parse(_ url: URL) throws -> GameInvite {
        guard url.host == host || url.host == "gregoryguterman.com" else {
            throw InviteURLError.invalid
        }

        // https://deuces.game/g/{id}?n=2
        if url.path.hasPrefix(pathPrefix) {
            let id = String(url.path.dropFirst(pathPrefix.count))
                .split(separator: "/").first
                .map(String.init) ?? ""
            guard !id.isEmpty else { throw InviteURLError.invalid }
            let n = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "n" })?.value
            return GameInvite(gameID: id, numPlayers: Int(n ?? "2") ?? 2)
        }

        // https://gregoryguterman.com/deuces/{id} (web deep link shape)
        let parts = url.path.split(separator: "/").map(String.init)
        if let idx = parts.firstIndex(of: "deuces"), parts.index(after: idx) < parts.endIndex {
            let id = parts[parts.index(after: idx)]
            guard id != "server", !id.isEmpty else { throw InviteURLError.invalid }
            return GameInvite(gameID: id, numPlayers: 2)
        }

        throw InviteURLError.invalid
    }

    public enum InviteURLError: Error {
        case invalid
    }
}

public enum GameBubbleCopy {
    public static func title(for invite: GameInvite) -> String {
        let players = invite.numPlayers == 1
            ? "1 player"
            : "\(invite.numPlayers) players"
        return "Deuces (\(players) - \(invite.gameID))"
    }

    public static func subtitle(for invite: GameInvite) -> String {
        "Tap to join"
    }
}
