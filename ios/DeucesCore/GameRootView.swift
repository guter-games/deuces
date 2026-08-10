import SwiftUI

/// Shared SwiftUI board used by the host app Local 2P simulator.
public struct GameRootView: View {
    @ObservedObject var controller: GameSessionController
    var openCreatedGamesLocally: Bool = false
    var defaultPlayerCount: Int = 2
    @State private var selected: Set<Card> = []
    @State private var playerCount: Int

    public init(
        controller: GameSessionController,
        openCreatedGamesLocally: Bool = false,
        defaultPlayerCount: Int = 2
    ) {
        self.controller = controller
        self.openCreatedGamesLocally = openCreatedGamesLocally
        self.defaultPlayerCount = defaultPlayerCount
        let clamped = min(
            max(defaultPlayerCount, DeucesEngine.allowedPlayerCounts.lowerBound),
            DeucesEngine.allowedPlayerCounts.upperBound
        )
        _playerCount = State(initialValue: clamped)
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
            playerCountStepper
            Button(playerCount == 1 ? "Create 1 player game" : "Create \(playerCount) player game") {
                controller.createGame(numPlayers: playerCount, openLocally: openCreatedGamesLocally)
            }
            .buttonStyle(PrimaryButtonStyle())
            if let status = controller.statusMessage {
                Text(status).foregroundColor(.orange)
            }
            if let error = controller.errorMessage {
                Text(error).foregroundColor(.orange)
            }
        }
        .padding()
    }

    private var playerCountStepper: some View {
        HStack(spacing: 18) {
            Button {
                playerCount = max(DeucesEngine.allowedPlayerCounts.lowerBound, playerCount - 1)
            } label: {
                Image(systemName: "minus")
                    .font(.title2.weight(.bold))
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
            .disabled(playerCount <= DeucesEngine.allowedPlayerCounts.lowerBound)
            .opacity(playerCount <= DeucesEngine.allowedPlayerCounts.lowerBound ? 0.35 : 1)

            Text("\(playerCount)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(minWidth: 48)

            Button {
                playerCount = min(DeucesEngine.allowedPlayerCounts.upperBound, playerCount + 1)
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.bold))
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.2))
                    .foregroundColor(.white)
                    .clipShape(Circle())
            }
            .disabled(playerCount >= DeucesEngine.allowedPlayerCounts.upperBound)
            .opacity(playerCount >= DeucesEngine.allowedPlayerCounts.upperBound ? 0.35 : 1)
        }
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
