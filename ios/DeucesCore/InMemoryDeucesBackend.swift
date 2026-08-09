import Foundation

/// In-process stand-in for the Node server — used by unit tests and Local 2P.
@MainActor
public final class InMemoryDeucesBackend: DeucesBackend {
    private var games: [String: MemoryGame] = [:]
    private var nextID = 1

    public init() {}

    public func createGame(numPlayers: Int) async throws -> String {
        precondition(DeucesEngine.allowedPlayerCounts.contains(numPlayers))
        let id = "mem\(nextID)"
        nextID += 1
        games[id] = MemoryGame(id: id, numPlayers: numPlayers)
        return id
    }

    public func openSocket(gameID: String) -> any GameSocket {
        MemoryGameSocket(backend: self, gameID: gameID)
    }

    fileprivate func game(for id: String) -> MemoryGame? { games[id] }
}

@MainActor
private final class MemoryGame {
    let id: String
    let numPlayers: Int
    var state: GameState
    var sockets: [MemoryGameSocket] = []

    init(id: String, numPlayers: Int) {
        self.id = id
        self.numPlayers = numPlayers
        self.state = DeucesEngine.createGame(numPlayers: numPlayers)
    }

    func attach(_ socket: MemoryGameSocket) {
        sockets.append(socket)
    }

    func detach(_ socket: MemoryGameSocket) {
        sockets.removeAll { $0 === socket }
    }

    func broadcast() {
        for socket in sockets {
            guard let seat = socket.playerIndex else {
                // Connected but not identified yet — still push a spectator-less stub.
                continue
            }
            socket.onGameUpdate?(view(for: seat))
        }
    }

    func view(for playerIndex: Int) -> ServerGameUpdate {
        let mePlayer = state.players[playerIndex]
        let others = state.players.enumerated().compactMap { idx, player -> ServerOther? in
            guard idx != playerIndex else { return nil }
            return ServerOther(
                name: player.claimed ? player.displayName : nil,
                numCards: player.hand.count
            )
        }
        let phase: ServerGamePhase
        switch state.phase {
        case .lobby: phase = .waiting
        case .playing: phase = state.allSeatsClaimed ? .playing : .waiting
        case .finished: phase = .finished
        }
        return ServerGameUpdate(
            poolSize: state.poolSize,
            playerTurnName: state.currentPlayer?.claimed == true
                ? state.currentPlayer?.displayName
                : nil,
            run: state.run,
            phase: phase,
            winner: state.winnerName,
            playAgainGameID: nil,
            me: ServerMe(
                name: mePlayer.claimed ? mePlayer.displayName : nil,
                cards: mePlayer.hand,
                isMyTurn: state.turn == playerIndex && state.phase == .playing
            ),
            others: others
        )
    }
}

@MainActor
final class MemoryGameSocket: GameSocket {
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    var onGameUpdate: ((ServerGameUpdate) -> Void)?
    var onBadPlay: ((String) -> Void)?

    fileprivate var playerIndex: Int?
    private weak var backend: InMemoryDeucesBackend?
    private let gameID: String

    init(backend: InMemoryDeucesBackend, gameID: String) {
        self.backend = backend
        self.gameID = gameID
    }

    func connect() {
        guard let game = backend?.game(for: gameID) else {
            onDisconnected?()
            return
        }
        game.attach(self)
        onConnected?()
    }

    func disconnect() {
        backend?.game(for: gameID)?.detach(self)
        onDisconnected?()
    }

    func requestNewIdentity(name: String) async throws -> Int {
        guard let game = backend?.game(for: gameID) else {
            throw DeucesBackendError.notConnected
        }
        do {
            let id = UUID()
            game.state = try DeucesEngine.join(
                state: game.state,
                playerID: id,
                displayName: name
            )
            guard let idx = game.state.playerIndex(for: id) else {
                throw DeucesBackendError.seatUnavailable
            }
            return idx
        } catch {
            return -1
        }
    }

    func identifyAs(player: Int) {
        guard let game = backend?.game(for: gameID),
              game.state.players.indices.contains(player) else { return }
        playerIndex = player
        game.broadcast()
    }

    func playCards(_ cards: [Card]) {
        guard let game = backend?.game(for: gameID),
              let playerIndex else { return }
        do {
            game.state = try DeucesEngine.playCards(
                state: game.state,
                playerID: game.state.players[playerIndex].id,
                cards: cards
            )
            game.broadcast()
        } catch {
            onBadPlay?(error.localizedDescription)
        }
    }

    func pass() {
        guard let game = backend?.game(for: gameID),
              let playerIndex else { return }
        do {
            game.state = try DeucesEngine.pass(
                state: game.state,
                playerID: game.state.players[playerIndex].id
            )
            game.broadcast()
        } catch {
            onBadPlay?(error.localizedDescription)
        }
    }
}
