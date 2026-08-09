import Foundation

/// Abstraction over the Node create_game + Socket.IO protocol used by `web/`.
@MainActor
public protocol DeucesBackend: AnyObject {
    func createGame(numPlayers: Int) async throws -> String
    func openSocket(gameID: String) -> any GameSocket
}

@MainActor
public protocol GameSocket: AnyObject {
    var onConnected: (() -> Void)? { get set }
    var onDisconnected: (() -> Void)? { get set }
    var onGameUpdate: ((ServerGameUpdate) -> Void)? { get set }
    var onBadPlay: ((String) -> Void)? { get set }

    func connect()
    func disconnect()
    func requestNewIdentity(name: String) async throws -> Int
    func identifyAs(player: Int)
    func playCards(_ cards: [Card])
    func pass()
}

public enum DeucesBackendError: Error, LocalizedError, Equatable {
    case createFailed
    case invalidResponse
    case notConnected
    case seatUnavailable
    case timeout

    public var errorDescription: String? {
        switch self {
        case .createFailed: return "Couldn't create a game on the server"
        case .invalidResponse: return "Unexpected server response"
        case .notConnected: return "Not connected to the game server"
        case .seatUnavailable: return "No open seats left"
        case .timeout: return "Timed out waiting for the server"
        }
    }
}
