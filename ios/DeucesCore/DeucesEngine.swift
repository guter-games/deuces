import Foundation

public enum DeucesError: Error, Equatable, LocalizedError {
    case notYourTurn
    case gameNotPlaying
    case gameFinished
    case seatUnavailable
    case alreadyJoined
    case invalidHand
    case cardsNotInHand
    case mustPlayLowestCard
    case wrongNumberOfCards
    case notHigherThanLast
    case cannotPassOnFreeTurn
    case emptyPlay
    case waitingForPlayers
    case staleRevision

    public var errorDescription: String? {
        switch self {
        case .notYourTurn: return "It's not your turn"
        case .gameNotPlaying: return "The game hasn't started yet"
        case .gameFinished: return "The game is already finished"
        case .seatUnavailable: return "No open seats left"
        case .alreadyJoined: return "You already joined this game"
        case .invalidHand: return "That is not a valid hand"
        case .cardsNotInHand: return "Tried to play cards not in hand"
        case .mustPlayLowestCard: return "You must play your lowest card on the first turn"
        case .wrongNumberOfCards: return "Wrong number of cards"
        case .notHigherThanLast: return "This is not higher than the last-played hand"
        case .cannotPassOnFreeTurn: return "You cannot pass on a free turn"
        case .emptyPlay: return "Select cards to play"
        case .waitingForPlayers: return "Waiting for all players to join"
        case .staleRevision: return "Game state is out of date"
        }
    }
}

/// Pure game rules + mutations. Port of `server/deuces.js`, transport-agnostic.
public enum DeucesEngine {
    public static let allowedPlayerCounts = 1...4

    public static func cardsToDeal(numPlayers: Int) -> Int {
        if numPlayers == 1 { return 4 }
        return numPlayers == 4 ? 13 : 17
    }

    /// Fixed 4-card deck for 1-player practice: 3♠, 2♦, J♥, J♣.
    public static let soloPracticeDeck: [Card] = [
        Card(suit: .spades, rank: .three),
        Card(suit: .diamonds, rank: .two),
        Card(suit: .hearts, rank: .jack),
        Card(suit: .clubs, rank: .jack),
    ]

    /// Create a new game with all seats open. Everyone (including the sender) claims a
    /// seat the same way — by opening the bubble and joining with a name.
    public static func createGame(
        numPlayers: Int,
        now: Date = Date(),
        rng: inout some RandomNumberGenerator
    ) -> GameState {
        precondition(allowedPlayerCounts.contains(numPlayers))

        var players = (0..<numPlayers).map { _ in PlayerState() }
        var pool: [Card]
        if numPlayers == 1 {
            pool = soloPracticeDeck
        } else {
            pool = fullDeck()
            pool.shuffle(using: &rng)
        }

        let dealCount = cardsToDeal(numPlayers: numPlayers)
        for playerIndex in 0..<numPlayers {
            for _ in 0..<dealCount {
                if let card = popRandom(from: &pool, rng: &rng) {
                    players[playerIndex].hand.append(card)
                }
            }
        }

        var turn = playerIndexWithMinCard(players) ?? 0
        if numPlayers == 3, let card = popRandom(from: &pool, rng: &rng) {
            players[turn].hand.append(card)
        }

        return GameState(
            gameID: UUID(),
            revision: 0,
            phase: .playing,
            players: players,
            pool: pool,
            run: [],
            turn: turn,
            ply: 0,
            passes: 0,
            winnerName: nil,
            createdAt: now
        )
    }

    public static func createGame(numPlayers: Int, now: Date = Date()) -> GameState {
        var rng = SystemRandomNumberGenerator()
        return createGame(numPlayers: numPlayers, now: now, rng: &rng)
    }

    public static func join(
        state: GameState,
        playerID: UUID,
        displayName: String,
        now: Date = Date()
    ) throws -> GameState {
        var next = normalized(state)

        if let existing = next.playerIndex(for: playerID) {
            next.players[existing].displayName = displayName
            next.players[existing].lastActiveAt = now
            next.revision += 1
            return next
        }

        guard let seat = next.players.firstIndex(where: { !$0.claimed }) else {
            throw DeucesError.seatUnavailable
        }

        next.players[seat].id = playerID
        next.players[seat].displayName = displayName
        next.players[seat].claimed = true
        next.players[seat].lastActiveAt = now

        // Before anyone has played, starter is the claimed seat with the lowest card.
        if next.ply == 0 {
            next.turn = playerIndexWithMinCard(next.players, claimedOnly: true) ?? seat
        } else if !next.players[next.turn].claimed {
            next.turn = advanceTurn(after: next.turn, players: next.players)
        }

        next.revision += 1
        return next
    }

    public static func playCards(
        state: GameState,
        playerID: UUID,
        cards: [Card],
        now: Date = Date()
    ) throws -> GameState {
        let state = normalized(state)
        guard state.phase != .finished else { throw DeucesError.gameFinished }
        guard state.phase == .playing else { throw DeucesError.gameNotPlaying }
        guard let playerIndex = state.playerIndex(for: playerID) else {
            throw DeucesError.seatUnavailable
        }
        guard playerIndex == state.turn else { throw DeucesError.notYourTurn }
        guard !cards.isEmpty else { throw DeucesError.emptyPlay }

        if let error = validatePlay(
            playerCards: state.players[playerIndex].hand,
            cards: cards,
            run: state.run,
            ply: state.ply
        ) {
            throw error
        }

        var next = state
        next.run.append(cards)
        next.ply += 1
        next.passes = 0
        next.players[playerIndex].hand = removeCards(cards, from: next.players[playerIndex].hand)
        next.players[playerIndex].lastActiveAt = now

        if next.players[playerIndex].hand.isEmpty {
            next.phase = .finished
            next.winnerName = next.players[playerIndex].displayName
        } else {
            next.turn = advanceTurn(after: playerIndex, players: next.players)
        }

        next.revision += 1
        return next
    }

    public static func pass(
        state: GameState,
        playerID: UUID,
        now: Date = Date(),
        rng: inout some RandomNumberGenerator
    ) throws -> GameState {
        let state = normalized(state)
        guard state.phase != .finished else { throw DeucesError.gameFinished }
        guard state.phase == .playing else { throw DeucesError.gameNotPlaying }
        guard let playerIndex = state.playerIndex(for: playerID) else {
            throw DeucesError.seatUnavailable
        }
        guard playerIndex == state.turn else { throw DeucesError.notYourTurn }
        guard !state.run.isEmpty else { throw DeucesError.cannotPassOnFreeTurn }

        var next = state
        next.passes += 1

        let claimedCount = next.players.filter(\.claimed).count
        if hasEveryonePassed(passes: next.passes, claimedCount: claimedCount) {
            next.run = []
            next.passes = 0
        }

        next.turn = advanceTurn(after: playerIndex, players: next.players)

        if let card = popRandom(from: &next.pool, rng: &rng) {
            next.players[playerIndex].hand.append(card)
        }

        next.players[playerIndex].lastActiveAt = now
        next.revision += 1
        return next
    }

    public static func pass(
        state: GameState,
        playerID: UUID,
        now: Date = Date()
    ) throws -> GameState {
        var rng = SystemRandomNumberGenerator()
        return try pass(state: state, playerID: playerID, now: now, rng: &rng)
    }

    /// Merge two snapshots of the same game.
    ///
    /// Higher revision wins when it already contains the other side's claimed seats.
    /// Concurrent joins (same revision, different claimants) are reconciled so both
    /// devices converge to every claimed player instead of staying stuck at 1/N.
    public static func mergeRemote(local: GameState, remote: GameState) -> GameState {
        guard remote.gameID == local.gameID else { return local }

        let localClaims = claimedIDs(local)
        let remoteClaims = claimedIDs(remote)

        if localClaims == remoteClaims {
            if remote.revision != local.revision {
                return remote.revision > local.revision ? remote : local
            }
            // Same claims + revision: prefer the side that has progressed further in play.
            if remote.ply != local.ply { return remote.ply > local.ply ? remote : local }
            return remote
        }

        if remote.revision > local.revision, remoteClaims.isSuperset(of: localClaims) {
            return remote
        }
        if local.revision > remote.revision, localClaims.isSuperset(of: remoteClaims) {
            return local
        }

        return reconcileClaims(local: local, remote: remote)
    }

    private static func claimedIDs(_ state: GameState) -> Set<UUID> {
        Set(state.players.filter(\.claimed).map(\.id))
    }

    /// Union claimed players from both sides onto a shared board snapshot.
    private static func reconcileClaims(local: GameState, remote: GameState) -> GameState {
        var next: GameState
        if remote.ply != local.ply {
            next = remote.ply > local.ply ? remote : local
        } else if remote.revision != local.revision {
            next = remote.revision > local.revision ? remote : local
        } else {
            next = remote
        }

        struct Claim {
            var id: UUID
            var displayName: String
            var lastActiveAt: Date?
        }

        var claims: [UUID: Claim] = [:]
        for source in [local, remote] {
            for player in source.players where player.claimed {
                if let existing = claims[player.id] {
                    let existingTime = existing.lastActiveAt ?? .distantPast
                    let newTime = player.lastActiveAt ?? .distantPast
                    if newTime >= existingTime {
                        claims[player.id] = Claim(
                            id: player.id,
                            displayName: player.displayName.isEmpty ? existing.displayName : player.displayName,
                            lastActiveAt: player.lastActiveAt ?? existing.lastActiveAt
                        )
                    }
                } else {
                    claims[player.id] = Claim(
                        id: player.id,
                        displayName: player.displayName,
                        lastActiveAt: player.lastActiveAt
                    )
                }
            }
        }

        // Keep dealt hands/pool from the gameplay base; reassign claims deterministically.
        for index in next.players.indices {
            next.players[index].claimed = false
            next.players[index].displayName = ""
            next.players[index].lastActiveAt = nil
            next.players[index].id = UUID()
        }

        let ordered = claims.values.sorted { $0.id.uuidString < $1.id.uuidString }
        for (seat, claim) in ordered.enumerated() where seat < next.players.count {
            next.players[seat].id = claim.id
            next.players[seat].displayName = claim.displayName
            next.players[seat].claimed = true
            next.players[seat].lastActiveAt = claim.lastActiveAt
        }

        next.revision = max(local.revision, remote.revision) + 1
        if next.ply == 0 {
            next.turn = playerIndexWithMinCard(next.players, claimedOnly: true) ?? next.turn
        } else if next.players.indices.contains(next.turn), !next.players[next.turn].claimed {
            next.turn = advanceTurn(after: next.turn, players: next.players)
        }
        return next
    }

    public static func validatePlay(
        playerCards: [Card],
        cards: [Card],
        run: [[Card]],
        ply: Int
    ) -> DeucesError? {
        let fullHand = Hand(cards: playerCards)
        for card in cards where !fullHand.contains(card) {
            return .cardsNotInHand
        }

        let hand = Hand(cards: cards)
        if hand.value == 0 {
            return .invalidHand
        }

        if ply == 0 {
            let minPlayed = hand.minCardValue()
            let minInHand = Hand(cards: playerCards).minCardValue()
            if minPlayed != minInHand {
                return .mustPlayLowestCard
            }
        }

        if let last = run.last {
            if cards.count != last.count {
                return .wrongNumberOfCards
            }
            if !hand.isBetterThan(Hand(cards: last)) {
                return .notHigherThanLast
            }
        }

        return nil
    }

    public static func fullDeck() -> [Card] {
        var deck: [Card] = []
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                deck.append(Card(suit: suit, rank: rank))
            }
        }
        return deck
    }

    public static func playerIndexWithMinCard(
        _ players: [PlayerState],
        claimedOnly: Bool = false
    ) -> Int? {
        var bestIndex: Int?
        var bestValue = Int.max
        for (index, player) in players.enumerated() {
            if claimedOnly && !player.claimed { continue }
            guard !player.hand.isEmpty else { continue }
            let value = Hand(cards: player.hand).minCardValue()
            if value < bestValue {
                bestValue = value
                bestIndex = index
            }
        }
        return bestIndex
    }

    public static func hasEveryonePassed(passes: Int, claimedCount: Int) -> Bool {
        if claimedCount <= 1 { return passes > 0 }
        return passes == claimedCount - 1
    }

    public static func removeCards(_ played: [Card], from hand: [Card]) -> [Card] {
        var remaining = hand
        for card in played {
            if let idx = remaining.firstIndex(of: card) {
                remaining.remove(at: idx)
            }
        }
        return remaining
    }

    public static func popRandom(
        from pool: inout [Card],
        rng: inout some RandomNumberGenerator
    ) -> Card? {
        guard !pool.isEmpty else { return nil }
        let index = Int.random(in: 0..<pool.count, using: &rng)
        return pool.remove(at: index)
    }

    /// Advance to the next claimed seat so play can continue before every seat is filled.
    public static func advanceTurn(after index: Int, players: [PlayerState]) -> Int {
        let count = players.count
        guard count > 0 else { return 0 }
        var next = index
        for _ in 0..<count {
            next = (next + 1) % count
            if players[next].claimed { return next }
        }
        return (index + 1) % count
    }

    public static func advanceTurn(after index: Int, playerCount: Int) -> Int {
        guard playerCount > 0 else { return 0 }
        return (index + 1) % playerCount
    }

    public static func normalized(_ state: GameState) -> GameState {
        var next = state
        if next.phase == .lobby {
            next.phase = .playing
        }
        return next
    }

    /// Player-facing view hiding opponents' hands (UI convenience; transport still has full state).
    public static func view(for state: GameState, localPlayerID: UUID?) -> PlayerGameView {
        let state = normalized(state)
        let myIndex = localPlayerID.flatMap { state.playerIndex(for: $0) }
        let me: PlayerState? = myIndex.map { state.players[$0] }
        let others: [OpponentView] = state.players.enumerated().compactMap { index, player in
            guard index != myIndex else { return nil }
            return OpponentView(
                id: player.id,
                displayName: player.claimed ? player.displayName : "Open seat",
                numCards: player.hand.count,
                lastActiveAt: player.lastActiveAt,
                claimed: player.claimed,
                isTheirTurn: index == state.turn && player.claimed
            )
        }

        return PlayerGameView(
            state: state,
            me: me,
            others: others,
            isMyTurn: myIndex == state.turn && state.phase == .playing,
            localPlayerIndex: myIndex
        )
    }
}

public struct OpponentView: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var displayName: String
    public var numCards: Int
    public var lastActiveAt: Date?
    public var claimed: Bool
    public var isTheirTurn: Bool
}

public struct PlayerGameView: Sendable, Equatable {
    public var state: GameState
    public var me: PlayerState?
    public var others: [OpponentView]
    public var isMyTurn: Bool
    public var localPlayerIndex: Int?
}
