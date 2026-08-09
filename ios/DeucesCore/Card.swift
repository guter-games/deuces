import Foundation

public struct Card: Hashable, Codable, Sendable, Comparable {
    public var suit: Suit
    public var rank: Rank

    public init(suit: Suit, rank: Rank) {
        self.suit = suit
        self.rank = rank
    }

    /// Numeric value in `[1, 52]`. Matches the JS server (`1 + rankValue + suitValue`).
    public var value: Int {
        1 + rankValue + suitValue
    }

    public var rankValue: Int {
        rank.index * Suit.allCases.count
    }

    public var suitValue: Int {
        suit.index
    }

    public var code: String {
        "\(rank.rawValue)\(suit.rawValue)"
    }

    /// Compact 0...51 index for encoding.
    public var packed: UInt8 {
        UInt8(rank.index * Suit.allCases.count + suit.index)
    }

    public init?(packed: UInt8) {
        guard packed < 52 else { return nil }
        let suitCount = Suit.allCases.count
        guard let rank = Rank.allCases[safe: Int(packed) / suitCount],
              let suit = Suit.allCases[safe: Int(packed) % suitCount] else {
            return nil
        }
        self.init(suit: suit, rank: rank)
    }

    public static func < (lhs: Card, rhs: Card) -> Bool {
        if lhs.rank != rhs.rank {
            return lhs.rank.index < rhs.rank.index
        }
        return lhs.suit.index < rhs.suit.index
    }
}

public enum Suit: String, CaseIterable, Codable, Sendable, Hashable {
    case diamonds = "D"
    case clubs = "C"
    case hearts = "H"
    case spades = "S"

    public var index: Int {
        Self.allCases.firstIndex(of: self)!
    }

    public var symbol: String {
        switch self {
        case .diamonds: return "♦"
        case .clubs: return "♣"
        case .hearts: return "♥"
        case .spades: return "♠"
        }
    }

    public var isRed: Bool {
        self == .diamonds || self == .hearts
    }
}

public enum Rank: String, CaseIterable, Codable, Sendable, Hashable {
    case three = "3"
    case four = "4"
    case five = "5"
    case six = "6"
    case seven = "7"
    case eight = "8"
    case nine = "9"
    case ten = "T"
    case jack = "J"
    case queen = "Q"
    case king = "K"
    case ace = "A"
    case two = "2"

    public var index: Int {
        Self.allCases.firstIndex(of: self)!
    }

    public var display: String {
        switch self {
        case .ten: return "10"
        default: return rawValue
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
