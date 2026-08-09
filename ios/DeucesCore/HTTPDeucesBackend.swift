import Foundation
import SocketIO

/// Live backend talking to the existing Express + Socket.IO server.
@MainActor
public final class HTTPDeucesBackend: DeucesBackend {
    public let config: ServerConfig
    private let session: URLSession

    public init(config: ServerConfig = .current, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    public func createGame(numPlayers: Int) async throws -> String {
        var request = URLRequest(url: config.createGameURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["numPlayers": numPlayers])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw DeucesBackendError.createFailed
        }
        let id = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !id.isEmpty else { throw DeucesBackendError.invalidResponse }
        return id
    }

    public func openSocket(gameID: String) -> any GameSocket {
        SocketIOGameSocket(config: config, gameID: gameID)
    }
}

@MainActor
final class SocketIOGameSocket: GameSocket {
    var onConnected: (() -> Void)?
    var onDisconnected: (() -> Void)?
    var onGameUpdate: ((ServerGameUpdate) -> Void)?
    var onBadPlay: ((String) -> Void)?

    private let config: ServerConfig
    private let gameID: String
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var identityContinuations: [CheckedContinuation<Int, Error>] = []

    init(config: ServerConfig, gameID: String) {
        self.config = config
        self.gameID = gameID
    }

    private var connectContinuations: [CheckedContinuation<Void, Error>] = []

    func connect() {
        let manager = SocketManager(
            socketURL: config.socketURL,
            config: [
                .log(false),
                .compress,
                .forceWebsockets(true),
                .version(.two), // server is socket.io@2.x
                .path(config.socketPath),
                .connectParams(["gameID": gameID]),
                .reconnects(true),
            ]
        )
        self.manager = manager
        let socket = manager.defaultSocket
        self.socket = socket

        socket.on(clientEvent: .connect) { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                let conts = self.connectContinuations
                self.connectContinuations.removeAll()
                conts.forEach { $0.resume() }
                self.onConnected?()
            }
        }
        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            Task { @MainActor in self?.onDisconnected?() }
        }
        socket.on("game_update") { [weak self] data, _ in
            guard let self, let first = data.first else { return }
            do {
                let update = try ServerWire.decodeUpdate(from: first)
                Task { @MainActor in self.onGameUpdate?(update) }
            } catch {
                // Ignore malformed payloads.
            }
        }
        socket.on("bad_play") { [weak self] data, _ in
            let message = (data.first as? String) ?? "Invalid play"
            Task { @MainActor in self?.onBadPlay?(message) }
        }
        socket.on("new_identity") { [weak self] data, _ in
            let idx = (data.first as? Int)
                ?? (data.first as? NSNumber)?.intValue
                ?? -1
            Task { @MainActor in
                guard let self else { return }
                let conts = self.identityContinuations
                self.identityContinuations.removeAll()
                conts.forEach { $0.resume(returning: idx) }
            }
        }

        socket.connect()
    }

    func disconnect() {
        socket?.disconnect()
        socket = nil
        manager = nil
        let identity = identityContinuations
        identityContinuations.removeAll()
        identity.forEach { $0.resume(throwing: DeucesBackendError.notConnected) }
        let connects = connectContinuations
        connectContinuations.removeAll()
        connects.forEach { $0.resume(throwing: DeucesBackendError.notConnected) }
    }

    func waitUntilConnected(timeout: TimeInterval = 5) async throws {
        if socket?.status == .connected { return }
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    self.connectContinuations.append(cont)
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw DeucesBackendError.timeout
            }
            try await group.next()!
            group.cancelAll()
        }
    }

    func requestNewIdentity(name: String) async throws -> Int {
        try await waitUntilConnected()
        guard let socket else { throw DeucesBackendError.notConnected }
        return try await withThrowingTaskGroup(of: Int.self) { group in
            group.addTask { @MainActor in
                try await withCheckedThrowingContinuation { cont in
                    self.identityContinuations.append(cont)
                    socket.emit("new_identity", ["gameID": self.gameID, "name": name])
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                throw DeucesBackendError.timeout
            }
            let value = try await group.next()!
            group.cancelAll()
            return value
        }
    }

    func identifyAs(player: Int) {
        socket?.emit("identify_as", ["gameID": gameID, "player": player])
    }

    func playCards(_ cards: [Card]) {
        socket?.emit("play_cards", [
            "gameID": gameID,
            "cards": ServerWire.encodeCards(cards),
        ])
    }

    func pass() {
        socket?.emit("pass", ["gameID": gameID])
    }
}
