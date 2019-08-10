class Card {
	constructor(suit, rank) {
		this.suit = suit;
		this.rank = rank;
	}

	// Returns the numeric value of this card, [0, 51]
	getValue() {
		// Add 1 so that 3 of diamonds doesn't have value 0
		// Reserve 0 for error states
		return 1 + this.getRankValue() + this.getSuitValue();
	}

	getRankValue() {
		const rankIdx = Card.Ranks.indexOf(this.rank);
		return rankIdx * Card.Suits.length;
	}

	getSuitValue() {
		const suitIdx = Card.Suits.indexOf(this.suit);
		return suitIdx;
	}

	equals(other) {
		return this.suit === other.suit && this.rank === other.rank;
	}
}

Card.Suits = ['D', 'C', 'H', 'S'];
Card.Ranks = ['3', '4', '5', '6', '7', '8', '9', 'T', 'J', 'Q', 'K', 'A', '2'];

module.exports = Card;