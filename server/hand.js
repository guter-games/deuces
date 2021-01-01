const Card = require('./card');
const {isConsecutive} = require('./array_util');

const HandValues = {
	['High Card']: 0,
	['Pair']: 100000000,
	['Three of a Kind']: 200000000,
	['Straight']: 300000000,
	['Flush']: 400000000,
	['Full House']: 500000000,
	['Four of a Kind']: 600000000,
	['Straight Flush']: 700000000,
	['Royal Flush']: 800000000,
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

	isBetterThan(other) {
		if(other.getValue() > this.getValue()) {
			return false;
		}

		// The hand values should only be equal when each hand is a pair of the same rank
		// In this case, the better hand is the one with a spade
		if(other.getValue() === this.getValue() && !this.containsSpade()) {
			return false;
		}

		return true;
	}

	containsSpade() {
		const suits = this.cards.map(c => c.suit);
		return suits.includes('S');
	}

	getValue() {
		let score = 0;

		// Compute the min card
		let minCard = null;

		this.cards.forEach(c => {
			if(minCard === null || c.getValue() < minCard.getValue()) {
				minCard = c;
			}
		});

		// Compute the score based on the type of hand
		const handType = this.getHandType();

		// Add the fixed hand value
		if(typeof HandValues[handType] !== 'undefined') {
			score += HandValues[handType];
		}

		// Additional value metrics
		switch(handType) {
			case 'Royal Flush':
			case 'Flush':
				score += this.cards[0].getSuitValue();
				break;

			case 'Straight Flush':
			case 'Straight':
				score += minCard.getRankValue();
				break;

			case 'Four of a Kind':
				if(this.cards.length !== 5) {
					score = 0;
					break;
				}
			case 'Full House':
				score += this.getMajorityRankValue();
				break;

			case 'Three of a Kind':
			case 'Pair':
				score += this.cards[0].getRankValue();
				break;

			case 'High Card':
				score += this.cards[0].getValue();
				break;

			default:
				// 'Five of a Kind', 'Four of a Kind with Pair or Better', 'Four Wild Cards',
				// 'Three of a Kind with Two Pair', 'Two Three of a Kind', 'Three Pair',
				// 'Two Pair'
				score = 0;
				console.log('WARNING: strange hand', this.cards, handType);
				break;
		}

		return score;
	}

	// Gets the majority rank in the hand
	// If there is a tie, a random one is chosen (but don't use this with a tie, be purposeful)
	getMajorityRank() {
		// Compute the # occurrences of each rank
		const rankCounts = {}; // Keep track of the # of cards with the given rank

		this.cards.forEach(c => {
			if(typeof rankCounts[c.rank] === 'undefined') {
				rankCounts[c.rank] = 0;
			}

			rankCounts[c.rank]++;
		});

		// Choose the majority rank and return its value
		let majRank = '3';

		for(const rank in rankCounts) {
			if(!rankCounts[majRank] || rankCounts[rank] > rankCounts[majRank]) {
				majRank = rank;
			}
		}

		return majRank;
	}

	// Gets the minority rank in the hand
	// If there is a tie, a random one is chosen (but don't use this with a tie, be purposeful)
	getMinorityRank() {
		// Compute the # occurrences of each rank
		const rankCounts = {}; // Keep track of the # of cards with the given rank

		this.cards.forEach(c => {
			if(typeof rankCounts[c.rank] === 'undefined') {
				rankCounts[c.rank] = 0;
			}

			rankCounts[c.rank]++;
		});

		// Choose the minority rank and return its value
		let minRank = '3';

		for(const rank in rankCounts) {
			if(!rankCounts[minRank] || rankCounts[rank] < rankCounts[minRank]) {
				minRank = rank;
			}
		}

		return minRank;
	}

	// Gets the value of the majority rank in the hand
	// If there is a tie, a random one is chosen (but don't use this with a tie, be purposeful)
	getMajorityRankValue() {
		// The suit shouldn't affect the rank's value, so we specify a random one
		return new Card('D', this.getMajorityRank()).getRankValue();
	}

	getHandType() {
		// Single card
		if(this.cards.length === 1) {
			return 'High Card';
		}

		// 2 of a kind
		if(this.cards.length === 2) {
			if(this.cards[0].rank === this.cards[1].rank) {
				return 'Pair';
			}
		}

		// 3 of a kind
		if(this.cards.length === 3) {
			if(this.cards[0].rank === this.cards[1].rank && this.cards[1].rank === this.cards[2].rank) {
				return 'Three of a Kind';
			}
		}

		// 5 card hands
		if(this.cards.length === 5) {
			const flush = this.cards.every(card => card.suit === this.cards[0].suit);

			// Check if the hand has a straight
			const rankIndexes = this.cards.map(card => Card.Ranks.indexOf(card.rank));
			rankIndexes.sort((a, b) => a - b);
			const straight = isConsecutive(rankIndexes);

			// Royal Flush
			if(straight && flush) {
				if(
					this.cards.some(card => card.rank === 'T') &&
					this.cards.some(card => card.rank === 'J') &&
					this.cards.some(card => card.rank === 'Q') &&
					this.cards.some(card => card.rank === 'K') &&
					this.cards.some(card => card.rank === 'A')
				) {
					return 'Royal Flush';
				}
			}

			// Straight Flush
			if(straight && flush) {
				return 'Straight Flush';
			}

			// Straight
			if(straight) {
				return 'Straight';
			}

			// Flush
			if(flush) {
				return 'Flush';
			}

			// Full House
			const majorityRank = this.getMajorityRank();
			const minorityRank = this.getMinorityRank();
			if(
				this.cards.filter(card => card.rank === majorityRank).length === 3 &&
				this.cards.filter(card => card.rank === minorityRank).length === 2
			) {
				return 'Full House';
			}

			// Four of a Kind
			if(this.cards.filter(card => card.rank === majorityRank).length === 4) {
				return 'Four of a Kind';
			}
		}

		// There are no other valid hands
		return '';
	}
}

module.exports = Hand;
