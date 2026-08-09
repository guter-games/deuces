import SwiftUI

/// Felt board aligned with `web/src/Game` — opponents around the table, pile + turn/deck
/// in the center, me + hand + Play/Pass along the bottom.
public struct ServerGameBoardView: View {
    public let update: ServerGameUpdate
    public var selected: Set<Card>
    public var onToggleCard: (Card) -> Void
    public var onPlay: () -> Void
    public var onPass: () -> Void
    public var onRematch: (() -> Void)?
    public var errorMessage: String?

    public init(
        update: ServerGameUpdate,
        selected: Set<Card>,
        onToggleCard: @escaping (Card) -> Void,
        onPlay: @escaping () -> Void,
        onPass: @escaping () -> Void,
        onRematch: (() -> Void)? = nil,
        errorMessage: String? = nil
    ) {
        self.update = update
        self.selected = selected
        self.onToggleCard = onToggleCard
        self.onPlay = onPlay
        self.onPass = onPass
        self.onRematch = onRematch
        self.errorMessage = errorMessage
    }

    public var body: some View {
        GeometryReader { geo in
            let compact = geo.size.height < 360
            ZStack {
                Color(red: 0.07, green: 0.28, blue: 0.18)

                VStack(spacing: compact ? 6 : 10) {
                    opponentsRow(compact: compact)

                    centerPile(compact: compact)
                        .frame(maxHeight: .infinity)

                    meSection(compact: compact)

                    if update.phase == .finished {
                        finishedOverlay
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(compact ? 8 : 12)
            }
        }
    }

    // MARK: - Opponents (web: top / left / right)

    @ViewBuilder
    private func opponentsRow(compact: Bool) -> some View {
        let others = update.others
        if others.isEmpty {
            EmptyView()
        } else if others.count == 1 {
            opponentSeat(others[0], compact: compact)
        } else if others.count == 2 {
            HStack(alignment: .top, spacing: 8) {
                opponentSeat(others[0], compact: compact)
                Spacer(minLength: 0)
                opponentSeat(others[1], compact: compact)
            }
        } else {
            VStack(spacing: 6) {
                opponentSeat(others[0], compact: compact)
                HStack(alignment: .top, spacing: 8) {
                    opponentSeat(others[1], compact: compact)
                    Spacer(minLength: 0)
                    opponentSeat(others[2], compact: compact)
                }
            }
        }
    }

    private func opponentSeat(_ other: ServerOther, compact: Bool) -> some View {
        let isTurn = other.name != nil && other.name == update.playerTurnName
        let name = other.name ?? "Open seat"
        let cardWidth: CGFloat = compact ? 22 : 28
        return VStack(spacing: 4) {
            Text("\(name) (\(other.numCards) cards)")
                .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                .foregroundColor(isTurn ? .orange : .white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            FaceDownHandView(count: other.numCards, cardWidth: cardWidth)
        }
        .frame(maxWidth: .infinity)
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(isTurn ? 0.28 : 0.12))
        )
    }

    // MARK: - Center (web Stats + Pile)

    private func centerPile(compact: Bool) -> some View {
        VStack(spacing: compact ? 4 : 8) {
            Text(GameStatusCopy.turnLine(update: update))
                .font(compact ? .subheadline.weight(.bold) : .title3.weight(.bold))
                .foregroundColor(.white)

            Text(GameStatusCopy.deckLine(poolSize: update.poolSize))
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))

            if let last = update.run.last, !last.isEmpty {
                VStack(spacing: 4) {
                    Text("Play:")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    HandView(cards: last, cardWidth: compact ? 36 : 48, overlap: 0.25)
                }
            } else if update.phase != .finished {
                Text(" ")
                    .font(.caption)
                    .foregroundColor(.clear)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Me (web Me.jsx)

    private func meSection(compact: Bool) -> some View {
        Group {
            if let me = update.me {
                let cardWidth: CGFloat = compact
                    ? (me.cards.count > 10 ? 34 : 40)
                    : (me.cards.count > 13 ? 40 : 48)
                VStack(spacing: compact ? 6 : 8) {
                    Text("\(me.name ?? "You") (you, \(me.cards.count) cards)")
                        .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                        .foregroundColor(me.isMyTurn ? .orange : .white)

                    WrappingCardHand(
                        cards: me.cards,
                        selected: selected,
                        cardWidth: cardWidth,
                        onToggle: onToggleCard
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if me.isMyTurn && update.phase != .finished {
                        HStack(spacing: 10) {
                            Button("Pass", action: onPass)
                                .buttonStyle(SecondaryButtonStyle())
                            Button("Play", action: onPlay)
                                .buttonStyle(PrimaryButtonStyle())
                                .disabled(selected.isEmpty)
                        }
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(me.isMyTurn ? 0.32 : 0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(me.isMyTurn ? Color.orange : Color.clear, lineWidth: 2.5)
                )
                .animation(.easeInOut(duration: 0.2), value: me.isMyTurn)
            }
        }
    }

    private var finishedOverlay: some View {
        VStack(spacing: 8) {
            Text(GameStatusCopy.winnerLine(update.winner))
                .font(.title2.bold())
                .foregroundColor(.yellow)
            if let onRematch {
                Button("New game", action: onRematch)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.top, 4)
    }
}

/// Bunched face-down cards matching web `Player` / `Hand layout="bunched"`.
public struct FaceDownHandView: View {
    public var count: Int
    public var cardWidth: CGFloat = 28
    public var overlap: CGFloat = 0.72

    public init(count: Int, cardWidth: CGFloat = 28, overlap: CGFloat = 0.72) {
        self.count = count
        self.cardWidth = cardWidth
        self.overlap = overlap
    }

    public var body: some View {
        let placeholders = (0..<max(count, 0)).map { _ in
            Card(suit: .clubs, rank: .three)
        }
        HandView(cards: placeholders, faceDown: true, cardWidth: cardWidth, overlap: overlap)
            .frame(maxHeight: cardWidth * 1.4 + 4)
    }
}
