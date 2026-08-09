import SwiftUI

public enum CardChrome {
    /// Vertical lift for selected cards; parent layouts must reserve this space.
    public static let selectionLift: CGFloat = 12
}

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
        .offset(y: selected ? -CardChrome.selectionLift : 0)
    }
}

/// Wraps cards into as many rows as needed so the full hand stays on-screen.
public struct WrappingCardHand: View {
    public let cards: [Card]
    public var selected: Set<Card>
    public var cardWidth: CGFloat
    public var spacing: CGFloat = 6
    public var rowSpacing: CGFloat = 8
    public var onToggle: (Card) -> Void

    public init(
        cards: [Card],
        selected: Set<Card>,
        cardWidth: CGFloat,
        spacing: CGFloat = 6,
        rowSpacing: CGFloat = 8,
        onToggle: @escaping (Card) -> Void
    ) {
        self.cards = cards
        self.selected = selected
        self.cardWidth = cardWidth
        self.spacing = spacing
        self.rowSpacing = rowSpacing
        self.onToggle = onToggle
    }

    public var body: some View {
        let sorted = cards.sorted()
        FlowLayout(spacing: spacing, rowSpacing: rowSpacing) {
            ForEach(sorted, id: \.self) { card in
                Button {
                    onToggle(card)
                } label: {
                    CardView(
                        card: card,
                        selected: selected.contains(card),
                        width: cardWidth
                    )
                }
                .buttonStyle(.plain)
                // Reserve lift space so raised cards are not clipped by the row.
                .padding(.top, CardChrome.selectionLift)
            }
        }
    }
}

/// Simple left-to-right wrapping layout (iOS 16+).
struct FlowLayout: Layout {
    var spacing: CGFloat
    var rowSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widthUsed: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            widthUsed = max(widthUsed, x - spacing)
        }

        let height = subviews.isEmpty ? 0 : y + rowHeight
        let width = maxWidth.isFinite ? maxWidth : widthUsed
        return (CGSize(width: width, height: height), origins)
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
