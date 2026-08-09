import SwiftUI

public struct CardView: View {
    public let card: Card?
    public var selected: Bool = false
    public var faceDown: Bool = false
    public var width: CGFloat = 54

    public init(card: Card?, selected: Bool = false, faceDown: Bool = false, width: CGFloat = 54) {
        self.card = card
        self.selected = selected
        self.faceDown = faceDown
        self.width = width
    }

    private var height: CGFloat { width * 1.4 }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
                .fill(faceDown ? Color(red: 0.12, green: 0.28, blue: 0.55) : Color.white)
                .shadow(color: .black.opacity(0.18), radius: selected ? 4 : 2, y: selected ? 2 : 1)

            if faceDown || card == nil {
                RoundedRectangle(cornerRadius: width * 0.08, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    .padding(width * 0.12)
                Text("DEUCES")
                    .font(.system(size: width * 0.16, weight: .bold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.85))
                    .rotationEffect(.degrees(-18))
            } else if let card {
                VStack(spacing: 0) {
                    Text(card.rank.display)
                        .font(.system(size: width * 0.32, weight: .bold, design: .rounded))
                    Text(card.suit.symbol)
                        .font(.system(size: width * 0.34))
                }
                .foregroundColor(card.suit.isRed ? Color.red : Color.black)
            }
        }
        .frame(width: width, height: height)
        .overlay(
            RoundedRectangle(cornerRadius: width * 0.12, style: .continuous)
                .stroke(selected ? Color.orange : Color.black.opacity(0.12), lineWidth: selected ? 3 : 1)
        )
        .offset(y: selected ? -10 : 0)
    }
}

public struct HandView: View {
    public let cards: [Card]
    public var selected: Set<Card> = []
    public var faceDown: Bool = false
    public var cardWidth: CGFloat = 54
    public var overlap: CGFloat = 0.55
    public var onTap: ((Card) -> Void)?

    public init(
        cards: [Card],
        selected: Set<Card> = [],
        faceDown: Bool = false,
        cardWidth: CGFloat = 54,
        overlap: CGFloat = 0.55,
        onTap: ((Card) -> Void)? = nil
    ) {
        self.cards = cards
        self.selected = selected
        self.faceDown = faceDown
        self.cardWidth = cardWidth
        self.overlap = overlap
        self.onTap = onTap
    }

    public var body: some View {
        let sorted = faceDown ? cards : cards.sorted()
        let step = cardWidth * (1 - overlap)
        let width = cardWidth + CGFloat(max(sorted.count - 1, 0)) * step

        ZStack(alignment: .leading) {
            ForEach(Array(sorted.enumerated()), id: \.offset) { index, card in
                CardView(
                    card: faceDown ? nil : card,
                    selected: selected.contains(card),
                    faceDown: faceDown,
                    width: cardWidth
                )
                .offset(x: CGFloat(index) * step)
                .zIndex(Double(index))
                .onTapGesture {
                    onTap?(card)
                }
            }
        }
        .frame(width: width, height: cardWidth * 1.4 + 12, alignment: .leading)
    }
}
