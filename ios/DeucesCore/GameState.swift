import Foundation

public enum GamePhase: String, Codable, Sendable, CaseIterable {
    case lobby
    case playing
    case finished
}

public struct PlayerState: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var displayName: String
    public var hand: [Card]
    public var lastActiveAt: Date?
    /// `true` once a real person has claimed this seat.
    public var claimed: Bool

    public init(
        id: UUID = UUID(),
        displayName: String = "",
        hand: [Card] = [],
        lastActiveAt: Date? = nil,
        claimed: Bool = false
    ) {
        self.id = id
        self.displayName = displayName
        self.hand = hand
        self.lastActiveAt = lastActiveAt
        self.claimed = claimed
    }

    public var isEmptySeat: Bool { !claimed }
}

/// Authoritative game snapshot transported via `MSMessage.url`.
public struct GameState: Codable, Sendable, Equatable {
    public var gameID: UUID
    public var revision: Int
    public var phase: GamePhase
    public var players: [PlayerState]
    public var pool: [Card]
    public var run: [[Card]]
    public var turn: Int
    public var ply: Int
    public var passes: Int
    public var winnerName: String?
    public var createdAt: Date

    public init(
        gameID: UUID = UUID(),
        revision: Int = 0,
        phase: GamePhase = .playing,
        players: [PlayerState],
        pool: [Card] = [],
        run: [[Card]] = [],
        turn: Int = 0,
        ply: Int = 0,
        passes: Int = 0,
        winnerName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.gameID = gameID
        self.revision = revision
        self.phase = phase
        self.players = players
        self.pool = pool
        self.run = run
        self.turn = turn
        self.ply = ply
        self.passes = passes
        self.winnerName = winnerName
        self.createdAt = createdAt
    }

    public var numPlayers: Int { players.count }

    public var currentPlayer: PlayerState? {
        players.indices.contains(turn) ? players[turn] : nil
    }

    public var allSeatsClaimed: Bool {
        players.allSatisfy(\.claimed)
    }

    public var poolSize: Int { pool.count }

    public func playerIndex(for id: UUID) -> Int? {
        players.firstIndex { $0.id == id }
    }

    public func isTurn(of id: UUID) -> Bool {
        playerIndex(for: id) == turn
    }
}
