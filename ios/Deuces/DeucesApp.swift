import SwiftUI
import DeucesCore

@main
struct DeucesApp: App {
    var body: some Scene {
        WindowGroup {
            HostRootView()
        }
    }
}

/// Host app: install help + Local 2P against an in-memory server stand-in.
struct HostRootView: View {
    @StateObject private var left: GameSessionController
    @StateObject private var right: GameSessionController
    @State private var mode: Mode = .info
    @State private var lanProbe: LanProbeState = .idle
    private let backend: InMemoryDeucesBackend

    enum Mode: String, CaseIterable {
        case info = "Install"
        case local = "Local 2P"
    }

    enum LanProbeState: Equatable {
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
            .task {
                // Foreground probe triggers the Local Network permission alert.
                // Messages extensions are treated as background on older iOS, so they
                // never show the prompt and fail with "internet appears offline".
                await probeLanServer()
            }
        }
    }

    private var installHelp: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("iMessage multiplayer")
                    .font(.title2.bold())
                Text("This app installs a Messages extension. Open Messages → Apps → Deuces.")
                Text("On iPad (and older iOS), open this host app once and tap Allow on the Local Network prompt before using Messages. The extension cannot show that prompt itself.")
                    .foregroundStyle(.primary)
                Text("Server: \(ServerConfig.current.createGameURL.host ?? "?")")
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)

                lanStatusRow

                Button("Test LAN connection") {
                    Task { await probeLanServer() }
                }
                .buttonStyle(.borderedProminent)

                Text("The bubble is only a join link (game id). Live play goes through the game server.")
                    .foregroundStyle(.secondary)
                Text("Use Local 2P to exercise the flow against an in-memory server without Messages.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var lanStatusRow: some View {
        switch lanProbe {
        case .idle:
            EmptyView()
        case .checking:
            Text("Checking Local Network access…")
                .foregroundStyle(.secondary)
        case .ok(let gameID):
            Text("LAN OK — created game \(gameID). Messages can use the server now.")
                .foregroundStyle(.green)
        case .failed(let message):
            Text(message)
                .foregroundStyle(.orange)
        }
    }

    @MainActor
    private func probeLanServer() async {
        lanProbe = .checking
        do {
            let id = try await HTTPDeucesBackend(config: .current).createGame(numPlayers: 2)
            lanProbe = .ok(id)
        } catch {
            let ns = error as NSError
            if ns.domain == NSURLErrorDomain, ns.code == NSURLErrorNotConnectedToInternet {
                lanProbe = .failed(
                    "Local Network blocked. Tap Allow if prompted, or enable Deuces in Settings → Privacy & Security → Local Network."
                )
            } else {
                lanProbe = .failed("Could not reach \(ServerConfig.current.createGameURL.absoluteString): \(error.localizedDescription)")
            }
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
