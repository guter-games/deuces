import SwiftUI

public struct GameRootView: View {
    @ObservedObject public var controller: GameSessionController
    /// Host-app Local 2P opens the created game immediately; Messages does not.
    public var openCreatedGamesLocally: Bool
    @State private var nameDraft = ""
    @State private var selected: Set<Card> = []

    public init(controller: GameSessionController, openCreatedGamesLocally: Bool = false) {
        self.controller = controller
        self.openCreatedGamesLocally = openCreatedGamesLocally
    }

    public var body: some View {
        Group {
            if controller.state != nil {
                if controller.needsToJoin {
                    joinSetup
                } else if let view = controller.view {
                    gameBoard(view)
                } else {
                    Text(controller.statusMessage ?? "Loading game…")
                        .foregroundColor(.white)
                        .padding()
                }
            } else {
                composeGame
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(feltColor.ignoresSafeArea())
        .alert("Play error", isPresented: errorBinding) {
            Button("OK", role: .cancel) { controller.errorMessage = nil }
        } message: {
            Text(controller.errorMessage ?? "")
        }
        .onAppear {
            if nameDraft.isEmpty {
                nameDraft = controller.identity?.displayName ?? ""
            }
        }
    }

    private var feltColor: Color {
        Color(red: 0.07, green: 0.28, blue: 0.18)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { controller.errorMessage != nil },
            set: { if !$0 { controller.errorMessage = nil } }
        )
    }

    /// Same join/name flow for every player, including the person who created the game.
    private var joinSetup: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Deuces")
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                if let state = controller.state {
                    Text(state.numPlayers == 1 ? "1 player game" : "\(state.numPlayers) player game")
                        .foregroundColor(.white.opacity(0.85))
                }

                Text("Enter your name to join")
                    .foregroundColor(.white.opacity(0.9))

                TextField("Your name", text: $nameDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 280)

                Button("Join game") {
                    controller.setDisplayName(nameDraft)
                    controller.joinIfNeeded()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(nameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let status = controller.statusMessage {
                    Text(status)
                        .font(.footnote)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }

    /// Pre-send composer: pick player count only (no name yet).
    private var composeGame: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Deuces")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)

                Text("How many players?")
                    .font(.headline)
                    .foregroundColor(.white)

                VStack(spacing: 10) {
                    ForEach(Array(DeucesEngine.allowedPlayerCounts), id: \.self) { count in
                        Button {
                            controller.createGame(
                                numPlayers: count,
                                openLocally: openCreatedGamesLocally
                            )
                        } label: {
                            HStack {
                                Text(count == 1 ? "1 Player" : "\(count) Players")
                                    .font(.headline.weight(.bold))
                                Spacer()
                                Text("Send")
                                    .font(.subheadline)
                                    .opacity(0.85)
                            }
                            .foregroundColor(.black)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
                .frame(maxWidth: 340)

                Text("Sends a game bubble into this chat. Tap it to join.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let status = controller.statusMessage {
                    Text(status)
                        .font(.footnote)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
    }

    private func gameBoard(_ view: PlayerGameView) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                header(view)

                opponentsRow(view.others)

                centerPile(view)

                if let me = view.me {
                    myArea(me: me, isMyTurn: view.isMyTurn, phase: view.state.phase)
                }

                if !view.state.allSeatsClaimed {
                    Text("Waiting for players to join…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.orange)
                }

                if view.state.phase == .finished {
                    Text("\(view.state.winnerName ?? "Someone") wins!")
                        .font(.title2.bold())
                        .foregroundColor(.yellow)
                        .padding(.bottom, 8)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity)
        }
    }

    private func header(_ view: PlayerGameView) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(statusTitle(view))
                    .font(.headline)
                    .foregroundColor(.white)
                Text("\(view.state.numPlayers) players · Pool \(view.state.poolSize)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            if let identity = controller.identity {
                Text(identity.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }

    private func statusTitle(_ view: PlayerGameView) -> String {
        if view.state.phase == .finished {
            return "Game over"
        }
        if !view.state.allSeatsClaimed {
            let joined = view.state.players.filter(\.claimed).count
            return "Joined \(joined)/\(view.state.numPlayers)"
        }
        let name = view.state.currentPlayer?.displayName ?? "Someone"
        return view.isMyTurn ? "Your turn" : "\(name)'s turn"
    }

    private func opponentsRow(_ others: [OpponentView]) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ForEach(others) { opponent in
                VStack(spacing: 6) {
                    Text(opponent.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(opponent.isTheirTurn ? Color.orange : Color.white)
                        .lineLimit(1)
                    Text(ActivityLabel.format(lastActiveAt: opponent.lastActiveAt))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.65))
                    HandView(
                        cards: Array(repeating: Card(suit: .spades, rank: .two), count: opponent.numCards),
                        faceDown: true,
                        cardWidth: 28,
                        overlap: 0.72
                    )
                    Text("\(opponent.numCards)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func centerPile(_ view: PlayerGameView) -> some View {
        VStack(spacing: 8) {
            if let last = view.state.run.last {
                Text("Play")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.8))
                HandView(cards: last, cardWidth: 48, overlap: 0.2)
            } else if view.state.allSeatsClaimed && view.state.phase != .finished {
                Text("Free turn — play any valid hand")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.75))
                    .frame(minHeight: 48)
            }

            VStack(alignment: .leading, spacing: 2) {
                ForEach(view.state.players.filter(\.claimed)) { player in
                    HStack(spacing: 6) {
                        Text(player.displayName)
                            .foregroundColor(.white)
                        Text(ActivityLabel.format(lastActiveAt: player.lastActiveAt))
                            .foregroundColor(.white.opacity(0.65))
                    }
                    .font(.caption2)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func myArea(me: PlayerState, isMyTurn: Bool, phase: GamePhase) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("\(me.displayName) (you, \(me.hand.count) cards)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(isMyTurn ? Color.orange : Color.white)
                Spacer()
                if isMyTurn && phase == .playing {
                    Button("Pass") {
                        controller.pass()
                        selected.removeAll()
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Button("Play") {
                        controller.play(cards: Array(selected))
                        selected.removeAll()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selected.isEmpty)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HandView(
                    cards: me.hand,
                    selected: selected,
                    cardWidth: 56,
                    overlap: 0.42
                ) { card in
                    if selected.contains(card) {
                        selected.remove(card)
                    } else {
                        selected.insert(card)
                    }
                }
                .padding(.vertical, 8)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(isMyTurn ? 0.28 : 0.16))
        )
    }
}

public struct PrimaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.orange.opacity(configuration.isPressed ? 0.7 : 1))
            .foregroundColor(.black)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

public struct SecondaryButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.white.opacity(configuration.isPressed ? 0.2 : 0.15))
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
