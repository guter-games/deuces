const HandValues = {
	Pair: 100000000,
	TwoPair: 200000000,
	ThreeKind: 300000000,
	Straight: 400000000,
	Flush: 500000000,
	FullHouse: 600000000,
	FourKind: 700000000,
	StraightFlush: 800000000,
	RoyalFlush: 900000000,
};


// A Hand is a set of cards
class Hand {
	constructor(cards) {
		this.cards = cards;
	}

	isValid() {
		return false;
	}

	getValue() {
		const s = this.toString();
		let score = 0;

		if(poker.hasRoyalFlush(s)) {
			score += HandValues.RoyalFlush;
			score += this.cards[0].getSuitValue();
		} else if(poker.hasStraightFlush(s)) {
			score += HandValues.StraightFlush;
		} else if(poker.hasFourOfAKind(s)) {
			score += HandValues.FourKind;
		} else if(poker.hasFullHouse(s)) {
			score += HandValues.FullHouse;
		} else if(poker.hasFlush(s)) {
			score += HandValues.Flush;
		} else if(poker.hasStraight(s)) {
			score += HandValues.Straight;
		} else if(poker.hasThreeOfAKind(s)) {
			score += HandValues.ThreeKind;
		} else if(poker.hasPair(s)) {
			score += HandValues.Pair;
		}

		return 0;
	}

	// Converts our representation of the hand to the following string representation:
	//		2H 3D AC 9S
	// Additionally, our 2s will be converted to As and every other rank will be 'moved 1 down'
	toString() {

	}
}

module.exports = Hand;