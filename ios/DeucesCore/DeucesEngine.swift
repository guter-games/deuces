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
        numPlayers == 4 ? 13 : 17
    }

    /// Create a new game with all seats open. Everyone (including the sender) claims a
    /// seat the same way — by opening the bubble and joining with a name.
    public static func createGame(
        numPlayers: Int,
        now: Date = Date(),
        rng: inout some RandomNumberGenerator
    ) -> GameState {
        precondition(allowedPlayerCounts.contains(numPlayers))

        var players = (0..<numPlayers).map { _ in PlayerState() }
        var pool = fullDeck()
        pool.shuffle(using: &rng)

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

        // Before anyone has played, recompute who starts among claimed seats.
        if next.ply == 0, next.allSeatsClaimed {
            next.turn = playerIndexWithMinCard(next.players, claimedOnly: true) ?? seat
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
        guard state.allSeatsClaimed else { throw DeucesError.waitingForPlayers }
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
            next.turn = advanceTurn(after: playerIndex, playerCount: next.players.count)
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
        guard state.allSeatsClaimed else { throw DeucesError.waitingForPlayers }
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

        next.turn = advanceTurn(after: playerIndex, playerCount: next.players.count)

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

    /// Accept a remote snapshot if it is strictly newer.
    public static func mergeRemote(local: GameState, remote: GameState) -> GameState {
        guard remote.gameID == local.gameID else { return local }
        return remote.revision > local.revision ? remote : local
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

    /// Always advance to the next seat index (do not skip). Skipping claimed-only
    /// seats made solo-joined hosts keep the turn forever.
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
                isTheirTurn: index == state.turn
            )
        }

        return PlayerGameView(
            state: state,
            me: me,
            others: others,
            isMyTurn: myIndex == state.turn && state.phase == .playing && state.allSeatsClaimed,
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
