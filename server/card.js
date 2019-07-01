class Card {
	constructor(suit, rank) {
		this.suit = suit;
		this.rank = rank;
	}

	// Returns the numeric value of this card, [0, 51]
	getValue() {
		return this.getRankValue() + this.getSuitValue();
	}

	getRankValue() {
		const rankIdx = Card.Ranks.indexOf(this.rank);
		return (rankIdx * Card.Suits.length)
	}

	getSuitValue() {
		const suitIdx = Card.Suits.indexOf(this.suit);
		return suitIdx;
	}
}

Card.Suits = ["dime", "club", "heart", "spade"];
Card.Ranks = ["3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A", "2"];

module.exports = Card;