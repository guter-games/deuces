import Foundation
import Combine

/// Coordinates the web-equivalent flow: create on HTTP, play over a socket,
/// and (optionally) announce a one-shot invite bubble via Messages.
@MainActor
public final class GameSessionController: ObservableObject {
    @Published public private(set) var invite: GameInvite?
    @Published public private(set) var update: ServerGameUpdate?
    @Published public var displayName: String
    @Published public var errorMessage: String?
    @Published public var statusMessage: String?
    @Published public private(set) var isConnecting = false
    @Published public private(set) var needsToJoin = false

    public let backend: DeucesBackend
    public let seatStore: SeatStore
    public let identityStore: PlayerIdentityStore
    private let inviteTransport: InviteTransport?

    private var socket: (any GameSocket)?
    private var playerIndex: Int?

    public init(
        backend: DeucesBackend,
        inviteTransport: InviteTransport? = nil,
        seatStore: SeatStore = UserDefaultsSeatStore(),
        identityStore: PlayerIdentityStore = UserDefaultsIdentityStore()
    ) {
        self.backend = backend
        self.inviteTransport = inviteTransport
        self.seatStore = seatStore
        self.identityStore = identityStore
        self.displayName = identityStore.load()?.displayName ?? ""
    }

    public var isInGame: Bool { invite != nil }

    /// Create a server game and optionally announce it.
    /// - Parameters:
    ///   - numPlayers: 1...4
    ///   - openLocally: when true, connect this device immediately (Local 2P / tests).
    ///     When false (Messages composer), only the invite bubble is sent.
    public func createGame(numPlayers: Int, openLocally: Bool = false) {
        errorMessage = nil
        statusMessage = nil
        Task {
            do {
                let gameID = try await backend.createGame(numPlayers: numPlayers)
                let invite = GameInvite(gameID: gameID, numPlayers: numPlayers)
                inviteTransport?.sendInvite(invite)
                if openLocally {
                    await openInvite(invite)
                } else {
                    clearGame(keepName: true)
                }
            } catch {
                errorMessage = Self.friendlyNetworkError(error)
            }
        }
    }

    /// Open an invite (from a bubble URL) and connect to the server.
    public func openInvite(_ invite: GameInvite) async {
        errorMessage = nil
        statusMessage = nil
        disconnectSocket()
        self.invite = invite
        self.update = nil
        self.playerIndex = seatStore.playerIndex(for: invite.gameID)
        self.needsToJoin = (playerIndex == nil)
        isConnecting = true

        let socket = backend.openSocket(gameID: invite.gameID)
        self.socket = socket
        socket.onGameUpdate = { [weak self] update in
            self?.update = update
            self?.isConnecting = false
            if update.me?.name != nil {
                self?.needsToJoin = false
            }
        }
        socket.onBadPlay = { [weak self] message in
            self?.errorMessage = message
        }
        socket.onConnected = { [weak self] in
            Task { @MainActor in
                await self?.identifyAfterConnect()
            }
        }
        socket.onDisconnected = { [weak self] in
            self?.isConnecting = false
            self?.statusMessage = "Disconnected from server"
        }
        socket.connect()
    }

    public func open(url: URL) async -> Bool {
        do {
            let invite = try GameInviteURL.parse(url)
            await openInvite(invite)
            return true
        } catch {
            statusMessage = "Couldn't read this game bubble."
            return false
        }
    }

    public func setDisplayName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        displayName = trimmed
        let id = identityStore.load()?.id ?? UUID()
        identityStore.save(PlayerIdentity(id: id, displayName: trimmed))
    }

    public func joinIfNeeded() {
        errorMessage = nil
        guard let invite, needsToJoin else { return }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "Enter a display name first"
            return
        }
        isConnecting = true
        Task {
            do {
                guard let socket else { throw DeucesBackendError.notConnected }
                let idx = try await socket.requestNewIdentity(name: name)
                if idx < 0 {
                    isConnecting = false
                    errorMessage = DeucesBackendError.seatUnavailable.errorDescription
                    return
                }
                seatStore.remember(gameID: invite.gameID, playerIndex: idx)
                playerIndex = idx
                needsToJoin = false
                socket.identifyAs(player: idx)
            } catch {
                isConnecting = false
                errorMessage = Self.friendlyNetworkError(error)
            }
        }
    }

    public func play(cards: [Card]) {
        errorMessage = nil
        socket?.playCards(cards)
    }

    public func pass() {
        errorMessage = nil
        socket?.pass()
    }

    /// Rematch = brand-new server game + new invite bubble (never reuse playAgainGameID).
    public func startRematch() {
        let players = invite?.numPlayers ?? 2
        createGame(numPlayers: players)
    }

    public func clearGame(keepName: Bool = true) {
        disconnectSocket()
        invite = nil
        update = nil
        playerIndex = nil
        needsToJoin = false
        isConnecting = false
        errorMessage = nil
        statusMessage = nil
        if !keepName { displayName = "" }
    }

    private func identifyAfterConnect() async {
        guard let invite, let socket else { return }
        if let idx = playerIndex {
            needsToJoin = false
            socket.identifyAs(player: idx)
            return
        }
        needsToJoin = true
        isConnecting = false
        // Stay on join UI until the user submits a name.
        _ = invite
    }

    private func disconnectSocket() {
        socket?.disconnect()
        socket = nil
    }

    private static func friendlyNetworkError(_ error: Error) -> String {
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorNotConnectedToInternet {
            return "Can't reach the Deuces server. Check your connection and try again."
        }
        return error.localizedDescription
    }
}

/// One-shot Messages invite delivery. Never used for state sync.
@MainActor
public protocol InviteTransport: AnyObject {
    func sendInvite(_ invite: GameInvite)
}
