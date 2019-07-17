const poker = require('pokersolver').Hand;
const Card = require('./card');

const HandValues = {
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

	getValue() {
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
		const arr = this.toPokerSolverArray();
		const handType = poker.solve(arr).name;

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
			case 'Full House':
				score += this.getMajorityRankValue();
				break;

			case 'Three of a Kind':
			case 'Pair':
				score += this.cards[0].getRankValue();
				break;

			case 'High Card':
				break;

			default:
				// 'Five of a Kind', 'Four of a Kind with Pair or Better', 'Four Wild Cards',
				// 'Three of a Kind with Two Pair', 'Two Three of a Kind', 'Three Pair',
				// 'Two Pair'
				score = 0;
				console.log('WARNING: strange hand', arr, handType);
				break;
		}

		console.log(arr, handType, score);
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
		let majRank = '3';

		for(const rank in rankCounts) {
			if(rankCounts[rank] > rankCounts[majRank]) {
				majRank = rank;
			}
		}

		// Return the majority rank's value
		// The suit shouldn't affect the rank's value, so we specify a random one
		return new Card('D', majRank).getRankValue();
	}

	// Converts our representation of the hand to the following array representation:
	//		['2h', '3d', 'Ac', '9s']
	// Additionally, our 2s will be converted to As and every other rank will be 'moved 1 down'
	toPokerSolverArray() {
		return this.cards.map(c => {
			let rank;

			if(c.rank === '3') {
				rank = '2';
			} else {
				rank = Card.Ranks[Card.Ranks.indexOf(c.rank) - 1];
			}
			
			return `${rank}${c.suit.toLowerCase()}`;
		});
	}
}

module.exports = Hand;