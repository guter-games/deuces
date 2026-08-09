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

/// Host app doubles as a local two-device simulator so game flow can be tested
/// without Messages.
struct HostRootView: View {
    @StateObject private var left: GameSessionController
    @StateObject private var right: GameSessionController
    @State private var mode: Mode = .info

    enum Mode: String, CaseIterable {
        case info = "Install"
        case local = "Local 2P"
    }

    init() {
        let (a, b) = LocalGameTransport.paired()
        _left = StateObject(wrappedValue: GameSessionController(
            transport: a,
            identityStore: UserDefaultsIdentityStore(key: "deuces.host.left")
        ))
        _right = StateObject(wrappedValue: GameSessionController(
            transport: b,
            identityStore: UserDefaultsIdentityStore(key: "deuces.host.right")
        ))
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
                                GameRootView(controller: right, openCreatedGamesLocally: true)
                            }
                        } else {
                            VStack(spacing: 1) {
                                GameRootView(controller: left, openCreatedGamesLocally: true)
                                GameRootView(controller: right, openCreatedGamesLocally: true)
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
                Text("This app installs a Messages extension. Open Messages, tap the App Store icon next to the compose field, then choose Deuces.")
                Text("Pick 1–4 players in the extension composer, then a game bubble is sent into the chat — no server required.")
                Text("Use the Local 2P tab here to exercise rules and UI with two simulated players.")
                    .foregroundStyle(.secondary)

                Divider().padding(.vertical, 8)

                Text("Quick local test")
                    .font(.headline)
                Text("1. Open Local 2P\n2. Set two names\n3. Tap “2 Players” on the left\n4. Join on the right\n5. Play / pass turns")
                    .font(.body)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
