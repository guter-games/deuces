import SwiftUI

/// Shared SwiftUI board used by the host app Local 2P simulator.
public struct GameRootView: View {
    @ObservedObject var controller: GameSessionController
    var openCreatedGamesLocally: Bool = false
    @State private var selected: Set<Card> = []

    public init(controller: GameSessionController, openCreatedGamesLocally: Bool = false) {
        self.controller = controller
        self.openCreatedGamesLocally = openCreatedGamesLocally
    }

    public var body: some View {
        ZStack {
            Color(red: 0.07, green: 0.28, blue: 0.18).ignoresSafeArea()
            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if controller.invite == nil {
            composer
        } else if controller.isConnecting {
            connecting
        } else if controller.needsToJoin {
            joinForm
        } else if let update = controller.update {
            ServerGameBoardView(
                update: update,
                selected: selected,
                onToggleCard: { card in
                    if selected.contains(card) { selected.remove(card) }
                    else { selected.insert(card) }
                },
                onPlay: {
                    controller.play(cards: Array(selected))
                    selected.removeAll()
                },
                onPass: {
                    controller.pass()
                    selected.removeAll()
                },
                onRematch: { controller.startRematch() },
                errorMessage: controller.errorMessage
            )
        } else {
            connecting
        }
    }

    private var connecting: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.2)
            Text("Connecting…")
                .font(.headline)
                .foregroundColor(.white)
            Text("This can take up to 1min if you haven't played for >15min")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    private var composer: some View {
        VStack(spacing: 14) {
            Text("Deuces").font(.largeTitle.bold()).foregroundColor(.white)
            Text("How many players?").foregroundColor(.white.opacity(0.9))
            ForEach(Array(DeucesEngine.allowedPlayerCounts), id: \.self) { count in
                Button(count == 1 ? "1 Player" : "\(count) Players") {
                    controller.createGame(numPlayers: count, openLocally: openCreatedGamesLocally)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            if let status = controller.statusMessage {
                Text(status).foregroundColor(.orange)
            }
            if let error = controller.errorMessage {
                Text(error).foregroundColor(.orange)
            }
        }
        .padding()
    }

    private var joinForm: some View {
        VStack(spacing: 12) {
            Text("Deuces").font(.largeTitle.bold()).foregroundColor(.white)
            if let invite = controller.invite {
                Text(invite.numPlayers == 1 ? "1 player game" : "\(invite.numPlayers) player game")
                    .foregroundColor(.white.opacity(0.9))
            }
            TextField("Your name", text: $controller.displayName)
                .textFieldStyle(.roundedBorder)
            Button("Join game") {
                controller.setDisplayName(controller.displayName)
                controller.joinIfNeeded()
            }
            .buttonStyle(PrimaryButtonStyle())
            if let error = controller.errorMessage {
                Text(error).foregroundColor(.orange)
            }
        }
        .padding()
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.orange.opacity(configuration.isPressed ? 0.7 : 1))
            .foregroundColor(.black)
            .cornerRadius(10)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(configuration.isPressed ? 0.12 : 0.2))
            .foregroundColor(.white)
            .cornerRadius(10)
    }
}
