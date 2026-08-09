import Foundation

/// Wire shape of Socket.IO `game_update` (see `server/deuces.js` `getGameStateForPlayer`).
public struct ServerGameUpdate: Equatable, Sendable {
    public var poolSize: Int
    public var playerTurnName: String?
    public var run: [[Card]]
    public var phase: ServerGamePhase
    public var winner: String?
    public var playAgainGameID: String?
    public var me: ServerMe?
    public var others: [ServerOther]

    public init(
        poolSize: Int,
        playerTurnName: String? = nil,
        run: [[Card]] = [],
        phase: ServerGamePhase,
        winner: String? = nil,
        playAgainGameID: String? = nil,
        me: ServerMe? = nil,
        others: [ServerOther] = []
    ) {
        self.poolSize = poolSize
        self.playerTurnName = playerTurnName
        self.run = run
        self.phase = phase
        self.winner = winner
        self.playAgainGameID = playAgainGameID
        self.me = me
        self.others = others
    }
}

public enum ServerGamePhase: Int, Equatable, Sendable {
    case waiting = 0
    case playing = 1
    case finished = 2
}

public struct ServerMe: Equatable, Sendable {
    public var name: String?
    public var cards: [Card]
    public var isMyTurn: Bool

    public init(name: String?, cards: [Card], isMyTurn: Bool) {
        self.name = name
        self.cards = cards
        self.isMyTurn = isMyTurn
    }
}

public struct ServerOther: Equatable, Sendable, Identifiable {
    public var id: String { name ?? UUID().uuidString }
    public var name: String?
    public var numCards: Int

    public init(name: String?, numCards: Int) {
        self.name = name
        self.numCards = numCards
    }
}

enum ServerWire {
    struct Update: Decodable {
        var poolSize: Int
        var playerTurnName: String?
        var run: [[WireCard]]
        var state: Int
        var winner: String?
        var playAgainGameID: String?
        var me: Me?
        var others: [Other]?

        struct Me: Decodable {
            var name: String?
            var cards: [WireCard]?
            var isMyTurn: Bool?
        }

        struct Other: Decodable {
            var name: String?
            var numCards: Int?
        }

        struct WireCard: Decodable {
            var suit: String
            var rank: String

            func materialize() -> Card? {
                guard let suit = Suit(rawValue: suit),
                      let rank = Rank(rawValue: rank) else { return nil }
                return Card(suit: suit, rank: rank)
            }
        }

        func materialize() -> ServerGameUpdate {
            ServerGameUpdate(
                poolSize: poolSize,
                playerTurnName: playerTurnName,
                run: run.map { $0.compactMap { $0.materialize() } },
                phase: ServerGamePhase(rawValue: state) ?? .playing,
                winner: winner,
                playAgainGameID: playAgainGameID,
                me: me.map {
                    ServerMe(
                        name: $0.name,
                        cards: ($0.cards ?? []).compactMap { $0.materialize() },
                        isMyTurn: $0.isMyTurn ?? false
                    )
                },
                others: (others ?? []).map {
                    ServerOther(name: $0.name, numCards: $0.numCards ?? 0)
                }
            )
        }
    }

    static func decodeUpdate(from value: Any) throws -> ServerGameUpdate {
        let data = try JSONSerialization.data(withJSONObject: value, options: [])
        let wire = try JSONDecoder().decode(Update.self, from: data)
        return wire.materialize()
    }

    static func encodeCards(_ cards: [Card]) -> [[String: String]] {
        cards.map { ["suit": $0.suit.rawValue, "rank": $0.rank.rawValue] }
    }
}

public enum GameStatusCopy {
    /// Matches web `Stats`: always `"{playerTurnName}'s turn"`.
    public static func turnLine(update: ServerGameUpdate) -> String {
        if update.phase == .finished {
            return "Game over"
        }
        if let name = update.playerTurnName, !name.isEmpty {
            return "\(name)'s turn"
        }
        return "Waiting…"
    }

    /// Matches web `Pool`: `Deck (N)`.
    public static func deckLine(poolSize: Int) -> String {
        "Deck (\(poolSize))"
    }

    public static func title(update: ServerGameUpdate?, needsJoin: Bool) -> String {
        if needsJoin { return "Join game" }
        guard let update else { return "Connecting…" }
        return turnLine(update: update)
    }
}
