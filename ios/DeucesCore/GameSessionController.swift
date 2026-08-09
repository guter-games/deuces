import Foundation
import Combine

/// Coordinates local identity, rules, and a pluggable transport (Messages or in-memory).
@MainActor
public final class GameSessionController: ObservableObject {
    @Published public private(set) var state: GameState?
    @Published public var errorMessage: String?
    @Published public var identity: PlayerIdentity?
    /// Decode/open failures shown in the extension UI (not silent).
    @Published public var statusMessage: String?

    public let identityStore: PlayerIdentityStore
    public let membershipStore: GameMembershipStore
    private let transport: GameTransport

    public init(
        transport: GameTransport,
        identityStore: PlayerIdentityStore = UserDefaultsIdentityStore(),
        membershipStore: GameMembershipStore = GameMembershipStore()
    ) {
        self.transport = transport
        self.identityStore = identityStore
        self.membershipStore = membershipStore
        self.identity = identityStore.load()

        transport.onReceive = { [weak self] remote in
            self?.applyRemote(remote)
        }
    }

    public var view: PlayerGameView? {
        guard let state else { return nil }
        return DeucesEngine.view(for: state, localPlayerID: identity?.id)
    }

    public var needsToJoin: Bool {
        guard let state else { return false }
        if let identity, state.playerIndex(for: identity.id) != nil {
            return false
        }
        return state.players.contains(where: \.isEmptySeat)
    }

    public func setDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let id = identity?.id ?? UUID()
        let next = PlayerIdentity(id: id, displayName: trimmed)
        identity = next
        identityStore.save(next)
    }

    /// Insert a new game bubble. Does not open the game locally — everyone joins
    /// by tapping the bubble (including the sender).
    public func createGame(numPlayers: Int, openLocally: Bool = false) {
        errorMessage = nil
        statusMessage = nil
        let state = DeucesEngine.createGame(numPlayers: numPlayers)
        if openLocally {
            self.state = state
        } else {
            // Keep composer until Messages dismisses; don't auto-open the board.
            self.state = nil
        }
        transport.send(state, isNewGame: true)
    }

    public func open(state: GameState) {
        errorMessage = nil
        statusMessage = nil
        self.state = DeucesEngine.normalized(state)

        // Restore this device's membership if we have one for this game.
        if let remembered = membershipStore.playerID(for: state.gameID),
           state.playerIndex(for: remembered) != nil {
            if var identity {
                identity.id = remembered
                self.identity = identity
                identityStore.save(identity)
            } else if let player = state.players.first(where: { $0.id == remembered }) {
                let restored = PlayerIdentity(id: remembered, displayName: player.displayName)
                self.identity = restored
                identityStore.save(restored)
            }
        }
    }

    public func open(url: URL) -> Bool {
        do {
            let state = try GameStateCodec.parseURL(url)
            open(state: state)
            return true
        } catch {
            statusMessage = "Couldn't read this game bubble."
            return false
        }
    }

    public func clearGame() {
        errorMessage = nil
        statusMessage = nil
        state = nil
    }

    public func joinIfNeeded() {
        errorMessage = nil
        statusMessage = nil
        guard var state else { return }
        guard let identity else {
            errorMessage = "Enter a display name first"
            return
        }

        if state.playerIndex(for: identity.id) != nil {
            membershipStore.remember(gameID: state.gameID, playerID: identity.id)
            return
        }

        guard state.players.contains(where: { !$0.claimed }) else {
            errorMessage = "No open seats left"
            return
        }

        do {
            state = try DeucesEngine.join(
                state: state,
                playerID: identity.id,
                displayName: identity.displayName
            )
            membershipStore.remember(gameID: state.gameID, playerID: identity.id)
            self.state = state
            transport.send(state, isNewGame: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func play(cards: [Card]) {
        mutate { state, identity in
            try DeucesEngine.playCards(state: state, playerID: identity.id, cards: cards)
        }
    }

    public func pass() {
        mutate { state, identity in
            try DeucesEngine.pass(state: state, playerID: identity.id)
        }
    }

    public func applyRemote(_ remote: GameState) {
        guard let local = state else {
            state = DeucesEngine.normalized(remote)
            return
        }
        state = DeucesEngine.mergeRemote(local: local, remote: remote)
    }

    private func mutate(_ body: (GameState, PlayerIdentity) throws -> GameState) {
        errorMessage = nil
        guard let state, let identity else { return }
        do {
            let next = try body(state, identity)
            self.state = next
            transport.send(next, isNewGame: false)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
public protocol GameTransport: AnyObject {
    var onReceive: ((GameState) -> Void)? { get set }
    var onNewGameInserted: (() -> Void)? { get set }
    func send(_ state: GameState, isNewGame: Bool)
}

/// In-memory bus for host-app / unit testing without Messages.
public final class LocalGameTransport: GameTransport {
    public var onReceive: ((GameState) -> Void)?
    public var onNewGameInserted: (() -> Void)?
    private weak var peer: LocalGameTransport?
    public private(set) var sent: [GameState] = []

    public init() {}

    public static func paired() -> (LocalGameTransport, LocalGameTransport) {
        let a = LocalGameTransport()
        let b = LocalGameTransport()
        a.peer = b
        b.peer = a
        return (a, b)
    }

    public func send(_ state: GameState, isNewGame: Bool) {
        sent.append(state)
        peer?.onReceive?(state)
        if isNewGame {
            onNewGameInserted?()
        }
    }
}

/// Shared chat thread for `MessagesLikeTransport` pairs.
public final class SimulatedMessageThread: @unchecked Sendable {
    public struct Bubble {
        public let url: URL
        public let state: GameState
    }

    private let lock = NSLock()
    private var _bubbles: [Bubble] = []

    public init() {}

    public var bubbles: [Bubble] {
        lock.lock(); defer { lock.unlock() }
        return _bubbles
    }

    public var latestBubbleURL: URL? {
        lock.lock(); defer { lock.unlock() }
        return _bubbles.last?.url
    }

    public func insert(_ state: GameState) throws -> URL {
        let url = try GameStateCodec.makeURL(state: state)
        lock.lock()
        _bubbles.append(Bubble(url: url, state: state))
        lock.unlock()
        return url
    }
}

/// Transport that mirrors Messages behavior for automated e2e tests:
/// - new games become a tap-able bubble URL (no auto-open on either side)
/// - updates only fan out to peers that already have that game open
public final class MessagesLikeTransport: GameTransport {
    public var onReceive: ((GameState) -> Void)?
    public var onNewGameInserted: (() -> Void)?
    public let thread: SimulatedMessageThread

    private weak var peer: MessagesLikeTransport?
    /// Controller using this transport (set by the test harness after construction).
    public weak var controller: GameSessionController?

    public init(thread: SimulatedMessageThread) {
        self.thread = thread
    }

    public static func paired() -> (MessagesLikeTransport, MessagesLikeTransport) {
        let thread = SimulatedMessageThread()
        let a = MessagesLikeTransport(thread: thread)
        let b = MessagesLikeTransport(thread: thread)
        a.peer = b
        b.peer = a
        return (a, b)
    }

    public var latestBubbleURL: URL? { thread.latestBubbleURL }

    public func send(_ state: GameState, isNewGame: Bool) {
        do {
            _ = try thread.insert(state)
        } catch {
            assertionFailure("Failed to encode bubble: \(error)")
        }

        if isNewGame {
            onNewGameInserted?()
        }

        // Live updates only when the peer already has this game open
        // (matches MessagesViewController.didReceive guard).
        guard let peer,
              let peerState = peer.controller?.state,
              peerState.gameID == state.gameID else { return }
        peer.onReceive?(state)
    }
}
