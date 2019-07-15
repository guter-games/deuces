const poker = require('poker-hands');
const Card = require('./card');

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

	getMinCardValue() {
		const values = this.cards.map(c => c.getValue());
		return Math.min(...values);
	}

	contains(card) {
		return this.cards.some(c => c.equals(card));
	}

	isValid() {
		return this.getValue() !== 0;
	}

	getValue() {
		const s = this.toString();
		let score = 0;

		// Calculate single card cost
		if(this.cards.length === 1) {
			return this.cards[0].getValue();
		}

		// Compute the min card
		let minCard = null;

		this.cards.forEach(c => {
			if(minCard === null || c.getValue() < minCard.getValue()) {
				minCard = c;
			}
		});

		// Compute the score based on the type of hand
		if(poker.hasRoyalFlush(s)) {
			score += HandValues.RoyalFlush;
			score += this.cards[0].getSuitValue();
		} else if(poker.hasStraightFlush(s)) {
			score += HandValues.StraightFlush;
			score += minCard.getRankValue();
		} else if(poker.hasFourOfAKind(s)) {
			score += HandValues.FourKind;
			score += this.getMajorityRankValue();
		} else if(poker.hasFullHouse(s)) {
			score += HandValues.FullHouse;
			score += this.getMajorityRankValue();
		} else if(poker.hasFlush(s)) {
			score += HandValues.Flush;
			score += this.cards[0].getSuitValue();
		} else if(poker.hasStraight(s)) {
			score += HandValues.Straight;
			score += minCard.getRankValue();
		} else if(poker.hasThreeOfAKind(s)) {
			score += HandValues.ThreeKind;
			score += this.cards[0].getRankValue();
		} else if(poker.hasPair(s)) {
			score += HandValues.Pair;
			score += this.cards[0].getRankValue();
		}

		return score;
	}

	// Gets the value of the majority rank in the hand
	// If there is a tie, a random one is chosen (but don't use this with a tie, be purposeful)
	getMajorityRankValue() {
		// Compute the # occurrences of each rank
		const rankCounts = {}; // Keep track of the # of cards with the given rank

		this.cards.forEach(c => {
			if(typeof rankCounts[c.rank] === 'undefined') {
				rankCounts[c.rank] = 0;
			}

			rankCounts[c.rank]++;
		});

		// Choose the majority rank and return its value
		let majRank = "3";

		for(const rank in rankCounts) {
			if(rankCounts[rank] > rankCounts[majRank]) {
				majRank = rank;
			}
		}

		// Return the majority rank's value
		// The suit shouldn't affect the rank's value, so we specify a random one
		return new Card("D", majRank).getRankValue();
	}

	// Converts our representation of the hand to the following string representation:
	//		2H 3D AC 9S
	// Additionally, our 2s will be converted to As and every other rank will be 'moved 1 down'
	toString() {
		const pokerForm = this.cards.map(c => {
			let rank;

			if(c.rank === '2') {
				rank = 'A';
			} else if(c.rank === '3') {
				rank = '2';
			} else {
				rank = Card.Ranks[Card.Ranks.indexOf(c.rank) - 1];
			}
			
			return `${rank}${c.suit}`;
		});

		return pokerForm.join(' ');
	}
}

module.exports = Hand;