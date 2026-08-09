import Foundation

public enum HandType: String, Sendable {
    case highCard = "High Card"
    case pair = "Pair"
    case threeOfAKind = "Three of a Kind"
    case straight = "Straight"
    case flush = "Flush"
    case fullHouse = "Full House"
    case fourOfAKind = "Four of a Kind"
    case straightFlush = "Straight Flush"
    case royalFlush = "Royal Flush"
    case invalid = ""
}

/// A set of cards being evaluated or played. Port of `server/hand.js`.
public struct Hand: Sendable {
    public let cards: [Card]

    private static let handValues: [HandType: Int] = [
        .highCard: 0,
        .pair: 100_000_000,
        .threeOfAKind: 200_000_000,
        .straight: 300_000_000,
        .flush: 400_000_000,
        .fullHouse: 500_000_000,
        .fourOfAKind: 600_000_000,
        .straightFlush: 700_000_000,
        .royalFlush: 800_000_000,
    ]

    public init(cards: [Card]) {
        self.cards = cards
    }

    public func minCardValue() -> Int {
        cards.map(\.value).min() ?? Int.max
    }

    public func contains(_ card: Card) -> Bool {
        cards.contains(card)
    }

    public func containsSpade() -> Bool {
        cards.contains { $0.suit == .spades }
    }

    public var isValid: Bool {
        // Match JS: `getValue() !== 0`
        value != 0
    }

    public func isBetterThan(_ other: Hand) -> Bool {
        if other.value > value {
            return false
        }
        // Equal values only for same-rank pairs; spade wins the tie.
        if other.value == value && !containsSpade() {
            return false
        }
        return true
    }

    public var value: Int {
        let type = handType
        guard let base = Self.handValues[type] else { return 0 }

        var score = base
        let minCard = cards.min(by: { $0.value < $1.value })

        switch type {
        case .royalFlush, .flush:
            score += cards[0].suitValue
        case .straightFlush, .straight:
            score += minCard?.rankValue ?? 0
        case .fourOfAKind:
            if cards.count != 5 {
                return 0
            }
            fallthrough
        case .fullHouse:
            score += majorityRankValue
        case .threeOfAKind, .pair:
            score += cards[0].rankValue
        case .highCard:
            score += cards[0].value
        case .invalid:
            return 0
        }
        return score
    }

    public var handType: HandType {
        if cards.count == 1 {
            return .highCard
        }

        if cards.count == 2 {
            return cards[0].rank == cards[1].rank ? .pair : .invalid
        }

        if cards.count == 3 {
            let same = cards[0].rank == cards[1].rank && cards[1].rank == cards[2].rank
            return same ? .threeOfAKind : .invalid
        }

        guard cards.count == 5 else { return .invalid }

        let flush = cards.allSatisfy { $0.suit == cards[0].suit }
        let rankIndexes = cards.map(\.rank.index).sorted()
        let straight = isConsecutive(rankIndexes)

        if straight && flush {
            let ranks = Set(cards.map(\.rank))
            if ranks.isSuperset(of: [.ten, .jack, .queen, .king, .ace]) {
                return .royalFlush
            }
            return .straightFlush
        }

        if straight { return .straight }
        if flush { return .flush }

        let majority = majorityRank
        let minority = minorityRank
        let majCount = cards.filter { $0.rank == majority }.count
        let minCount = cards.filter { $0.rank == minority }.count

        if majCount == 3 && minCount == 2 {
            return .fullHouse
        }
        if majCount == 4 {
            return .fourOfAKind
        }

        return .invalid
    }

    public var majorityRank: Rank {
        rankCounts.max(by: { $0.value < $1.value })?.key ?? .three
    }

    public var minorityRank: Rank {
        rankCounts.min(by: { $0.value < $1.value })?.key ?? .three
    }

    public var majorityRankValue: Int {
        Card(suit: .diamonds, rank: majorityRank).rankValue
    }

    private var rankCounts: [Rank: Int] {
        Dictionary(grouping: cards, by: \.rank).mapValues(\.count)
    }
}

func isConsecutive(_ values: [Int]) -> Bool {
    guard let first = values.first else { return true }
    var prev = first
    for value in values.dropFirst() {
        if value != prev + 1 { return false }
        prev = value
    }
    return true
}
