const { Model, INTEGER } = require('sequelize');
const { init } = require('./model_util');
const { without } = require('./array_util');

const Player = require("./player");
const Card = require("./card");
const Hand = require("./hand");
const Run = require("./run");

const GameState = {
	WAITING: 0,
	PLAYING: 1,
	FINISHED: 2, // Generally this is when someone won
};

// Number of cards players are dealt at the start
function numCardsToDeal(numPlayers) {
	return (numPlayers === 4) ? 13 : 17;
}

class Deuces extends Model {
	async start(numPlayers) {
		await this.setRuns([]);

		const players = Array(numPlayers).fill().map(async () => await Player.create());
		await this.setPlayers(players);

		// Put all 52 cards into the pool
		const pool = [];

		Card.Suits.forEach(async suit => {
			Card.Ranks.forEach(async rank => {
				// const card = await Card.create({ suit, rank });
				// pool.push(card);
			});
		});

		await this.setPool(pool);

		// Deal cards to each player
		players.forEach(async c => {
			for(let i = 0; i < numCardsToDeal(players.length); i++) {
				await this.dealCardTo(c);
			}
		});

		// Pick the starting player
		this.turn = await this.getPlayerWithMinCard();

		// For 3 player games, the player who goes first draws the last card
		if(players.length === 3) {
			await this.dealCardTo(this.turn);
		}
	}

	async dealCardTo(client) {
		const pool = await this.getPool();
		
		if(pool.length > 0) {
			client.cards.push(this.popRandomFromPool());
			client.save();
		}
	}

	// Returns the player with the minimum value card
	async getPlayerWithMinCard() {
		const players = await this.getPlayers();

		let minPlayer = null;
		let minCardValue = null;

		for(let i = 0; i < players.length; i++) {
			const c = players[i];
			const value = new Hand(c.cards).getMinCardValue();

			if(minPlayer === null || value < minCardValue) {
				minPlayer = i;
				minCardValue = value;
			}
		}

		return minPlayer;
	}

	// Pop a random card from the pool of remaining cards
	popRandomFromPool() {
		// const pool = await this.getPool();
		const numCards = this.pool.length;
		const randIdx = Math.floor(Math.random() * numCards);
		return this.pool.splice(randIdx, 1)[0];
	}

	onPass(playerIdx) {
		const client = this.players[playerIdx];

		// Can't pass if the run is empty (this also covers passing on the first turn)
		if(this.run.length === 0) {
			return false;
		}

		this.passes++;

		if(this.hasEveryonePassed()) {
			this.run = [];
			this.passes = 0;
		}

		// Do the pass
		this.nextTurn();
		this.dealCardTo(client);
		this.onUpdate();

		return true;
	}

	hasEveryonePassed() {
		return this.passes >= this.players.length - 1;
	}

	onPlayCards(playerIdx, clientCards) {
		const client = this.players[playerIdx];

		// Do nothing if they played no cards
		if(clientCards.length === 0) {
			return;
		}

		const cards = clientCards.map(c => new Card(c.suit, c.rank));

		// Check valid play
		const error = this.playIsValid(client.cards, cards, this.run);

		if (error) {
			return error;
		}

		// Record the play
		this.run.push(cards);
		this.ply++;
		this.passes = 0;

		// Take away the played cards
		this.playCards(client, cards);

		// Check if the player won
		if(client.cards.length === 0) {
			this.state = GameState.FINISHED;
			this.winner = client.name;
		}

		// Go to the next player
		this.nextTurn();

		// Update the game state
		this.onUpdate();

		return null;
	}

	// Returns an error if there is one
	playIsValid(playersCards, cards, run) {
		// Check that the player has all the cards
		const fullPlayerHand = new Hand(playersCards);

		for(let i = 0; i < cards.length; i++) {
			if(!fullPlayerHand.contains(cards[i])) {
				return 'Tried to play cards not in hand';
			}
		}

		// Check that the cards themselves can be played together
		const hand = new Hand(cards);

		if(!hand.isValid()) {
			return 'That is not a valid hand';
		}

		// First move must include that player's lowest card
		if(this.ply === 0) {
			const minValuePlayed = hand.getMinCardValue();
			const minValueInHand = new Hand(playersCards).getMinCardValue();

			if(minValuePlayed !== minValueInHand) {
				return 'You must play your lowest card on the first turn';
			}
		}

		// Check that the # of cards played was right
		if(run.length > 0) {
			const oldCards = this.run[this.run.length - 1];
			const lastNumCardsPlayed = oldCards.length;

			if(cards.length !== lastNumCardsPlayed) {
				return 'Wrong number of cards';
			}

			// Check that the cards are higher than those last played
			const oldHand = new Hand(oldCards);

			if(!hand.isBetterThan(oldHand)) {
				return 'This is not higher than the last-played hand';
			}
		}

		return null;
	}

	nextTurn() {
		this.turn = (this.turn + 1) % this.players.length;
	}

	// Takes away the cards from the client's hand
	playCards(client, cards) {
		const newCards = [];

		for(let i = 0; i < client.cards.length; i++) {
			const cardInHand = client.cards[i];
			let played = false;

			for(let j = 0; j < cards.length; j++) {
				const cardPlayed = cards[j];

				if(cardInHand.equals(cardPlayed)) {
					played = true;
				}
			}

			if(!played) {
				newCards.push(client.cards[i]);
			}
		}

		client.cards = newCards;
	}

	onUpdate() {
		this.game.onUpdate();
	}

	getGameStateForPlayer(playerIdx) {
		const game = {
			poolSize: this.pool.length,
			playerTurnName: this.players[this.turn].name,
			run: this.run,
			state: this.state,
		};

		// Information about this player
		game.me = {
			...this.players[playerIdx],
			isMyTurn: (this.turn === playerIdx),
		};

		// Information about other players
		game.others = without(this.players, playerIdx)
			.map(player => {
				return {
					name: player.name,
					numCards: player.cards.length,
				};
			});

		return game;
	}

	getUnusedPlayerIdx() {
		const names = this.players.map(player => player.name);
		return names.indexOf(Player.NO_NAME);
	}

	setPlayerName(playerIdx, name) {
		this.players[playerIdx].name = name;
	}

	static async make(game) {
		const deuces = await Deuces.create({
			state: GameState.WAITING,
			turn: 0,
			ply: 0,
			winner: null,
			passes: 0,
		});

		await deuces.start(game.numPlayers);
		await deuces.save();
		return deuces;
	}
}

init(Deuces, {
	state: {
		type: INTEGER,
		defaultValue: GameState.WAITING,
	},
	turn: INTEGER,
	ply: INTEGER,
	winner: {
		type: INTEGER,
		defaultValue: null,
	},
	passes: INTEGER,
});

Deuces.hasMany(Player);
Deuces.hasMany(Run);
Deuces.hasMany(Card, { as: 'Pool' });

module.exports = Deuces;