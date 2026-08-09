import SwiftUI
import DeucesCore

@main
struct DeucesApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("-UITestingScreenshots") {
                ScreenshotRootView()
            } else {
                HostRootView()
            }
        }
    }
}

/// Host app: install help + Local 2P against an in-memory server stand-in.
struct HostRootView: View {
    @StateObject private var left: GameSessionController
    @StateObject private var right: GameSessionController
    @State private var mode: Mode = .info
    @State private var serverProbe: ProbeState = .idle
    private let backend: InMemoryDeucesBackend

    enum Mode: String, CaseIterable {
        case info = "Install"
        case local = "Local 2P"
    }

    enum ProbeState: Equatable {
        case idle
        case checking
        case ok(String)
        case failed(String)
    }

    init() {
        let backend = InMemoryDeucesBackend()
        let bus = LocalInviteBus()
        let left = GameSessionController(
            backend: backend,
            inviteTransport: bus,
            seatStore: InMemorySeatStore(),
            identityStore: InMemoryIdentityStore()
        )
        let right = GameSessionController(
            backend: backend,
            seatStore: InMemorySeatStore(),
            identityStore: InMemoryIdentityStore()
        )
        bus.onInvite = { invite in
            Task { @MainActor in
                await right.openInvite(invite)
            }
        }
        self.backend = backend
        _left = StateObject(wrappedValue: left)
        _right = StateObject(wrappedValue: right)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                switch mode {
                case .info:
                    installHelp
                case .local:
                    GeometryReader { geo in
                        if geo.size.width > geo.size.height {
                            HStack(spacing: 1) {
                                GameRootView(controller: left, openCreatedGamesLocally: true)
                                GameRootView(controller: right, openCreatedGamesLocally: false)
                            }
                        } else {
                            VStack(spacing: 1) {
                                GameRootView(controller: left, openCreatedGamesLocally: true)
                                GameRootView(controller: right, openCreatedGamesLocally: false)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Deuces")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var installHelp: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("iMessage multiplayer")
                    .font(.title2.bold())
                Text("This app installs a Messages extension. Open Messages → Apps → Deuces.")
                Text("Create a game from the composer, send the invite bubble, and play turns live over the Deuces server.")
                Text("Server: \(ServerConfig.current.createGameURL.host ?? "?")")
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)

                probeRow

                Button("Test server connection") {
                    Task { await probeServer() }
                }
                .buttonStyle(.borderedProminent)

                Text("Use Local 2P to try the board against an in-memory server without Messages.")
                    .foregroundStyle(.secondary)
                Text("Privacy: https://deuces.onrender.com/privacy")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var probeRow: some View {
        switch serverProbe {
        case .idle:
            EmptyView()
        case .checking:
            Text("Checking server…")
                .foregroundStyle(.secondary)
        case .ok(let gameID):
            Text("Server OK — created game \(gameID).")
                .foregroundStyle(.green)
        case .failed(let message):
            Text(message)
                .foregroundStyle(.orange)
        }
    }

    @MainActor
    private func probeServer() async {
        serverProbe = .checking
        do {
            let id = try await HTTPDeucesBackend(config: .current).createGame(numPlayers: 2)
            serverProbe = .ok(id)
        } catch {
            serverProbe = .failed(
                "Could not reach \(ServerConfig.current.createGameURL.absoluteString): \(error.localizedDescription)"
            )
        }
    }
}

@MainActor
final class LocalInviteBus: InviteTransport {
    var onInvite: ((GameInvite) -> Void)?
    func sendInvite(_ invite: GameInvite) {
        onInvite?(invite)
    }
}

final class InMemoryIdentityStore: PlayerIdentityStore {
    private var identity: PlayerIdentity?
    init(_ identity: PlayerIdentity? = nil) { self.identity = identity }
    func load() -> PlayerIdentity? { identity }
    func save(_ identity: PlayerIdentity) { self.identity = identity }
}
