import Foundation

/// Mirrors `web/.env.production` / `.env.development`, plus LAN device testing.
public struct ServerConfig: Sendable, Equatable {
    public var createGameURL: URL
    public var socketURL: URL
    public var socketPath: String

    public init(createGameURL: URL, socketURL: URL, socketPath: String) {
        self.createGameURL = createGameURL
        self.socketURL = socketURL
        self.socketPath = socketPath
    }

    /// Production on Render (`deuces` web service).
    public static let production = ServerConfig(
        createGameURL: URL(string: "https://deuces.onrender.com/create_game")!,
        socketURL: URL(string: "https://deuces.onrender.com")!,
        socketPath: "/socket.io"
    )

    /// Legacy production host (web behind gregoryguterman.com reverse proxy).
    public static let legacyProduction = ServerConfig(
        createGameURL: URL(string: "https://gregoryguterman.com/deuces/server/create_game")!,
        socketURL: URL(string: "https://gregoryguterman.com")!,
        socketPath: "/deuces/socket.io"
    )

    /// Loopback (simulator on the same Mac as `make up-server`).
    public static let local = ServerConfig(
        createGameURL: URL(string: "http://localhost:3012/create_game")!,
        socketURL: URL(string: "http://localhost:3012")!,
        socketPath: "/socket.io"
    )

    /// Reachable from physical devices on the same Wi‑Fi as this Mac.
    public static var lan: ServerConfig {
        let host = LanHost.address
        let port = LanHost.port
        return ServerConfig(
            createGameURL: URL(string: "http://\(host):\(port)/create_game")!,
            socketURL: URL(string: "http://\(host):\(port)")!,
            socketPath: "/socket.io"
        )
    }

    /// Active config for App Store / TestFlight / device builds.
    /// Switch to `.lan` locally when testing against `make up-server`.
    public static var current: ServerConfig { .production }
}
