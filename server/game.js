const Card = require("./card");
const Hand = require("./hand");

const GameState = {
	WAITING: 0,
};

// Number of cards players are dealt at the start
const numCardsToDeal = 17;

class Game {
	constructor(clients, sockets) {
		this.clients = clients;
		this.sockets = sockets;
		this.state = GameState.WAITING;
		this.run = [];
		this.turn = 0; // Index of the player whose turn it is

		// Bind actions
		this.sockets.forEach((s, i) => {
			const client = this.clients[i];

			s.on('play_cards', cards => this.onPlayCards(client, s, cards));
		});
	}

	start() {
		// Put all 52 cards into the pool
		this.pool = [];

		Card.Suits.forEach(suit => {
			Card.Ranks.forEach(rank => {
				this.pool.push(new Card(suit, rank));
			});
		});

		// Deal cards to each player
		this.clients.forEach(c => {
			for(let i = 0; i < numCardsToDeal; i++) {
				c.cards.push(this.popRandomFromPool());
			}
		});

		// Pick the starting player
		this.turn = this.getPlayerWithMinCard();

		// Reset the current run
		this.run = [];

		// Update all players
		this.updateAllClients();
	}

	// Returns the player with the minimum value card
	getPlayerWithMinCard() {
		let minPlayer = 0;
		let minCardValue = 0;

		for(let i = 0; i < this.clients.length; i++) {
			const c = this.clients[i];

			c.cards.forEach(card => {
				const value = card.getValue();

				if(value < minCardValue) {
					minPlayer = i;
					minCardValue = value;
				}
			});
		}

		return minPlayer;
	}

	// Pop a random card from the pool of remaining cards
	popRandomFromPool() {
		const numCards = this.pool.length;
		const randIdx = Math.floor(Math.random() * numCards);
		return this.pool.splice(randIdx, 1)[0];
	}

	onPlayCards(client, socket, cards) {
		// TODO: verify that the client actually has these cards

		const oldCards = this.run[this.run.length - 1];

		// Check that the # of cards played was right
		if(this.run.length > 0) {
			const lastNumCardsPlayed = oldCards.length;

			if(cards.length !== lastNumCardsPlayed) {
				// WRONG NUMBER OF CARDS
				socket.emit('bad_play', 'Wrong number of cards');
				return;
			}
		}

		// Check that the cards themselves can be played together
		const hand = new Hand(cards);

		if(!hand.isValid()) {
			// INVALID HAND
			socket.emit('bad_play', 'That is not a valid hand');
			return;
		}

		// Check that the cards are higher than those last played
		if(this.run.length > 0) {
			const oldHand = new Hand(oldCards);

			if(oldHand.getValue() > hand.getValue()) {
				// THE HAND PLAYED IS WORSE THAN THE LAST HAND
				socket.emit('bad_play', 'This is not higher than the last-played hand');
				return;
			}
		}

		// Allow the play
		// 		Record the play
		this.run.push(cards);

		//		Go to the next player
		this.turn = (this.turn + 1) % this.clients.length;

		// 		Update the game state
		this.updateAllClients();
	}

	// Update the game state to all clients over the socket
	updateAllClients() {
		this.sockets.forEach((s, i) => {
			const game = Object.assign({}, this);
			delete game.sockets; // Can't send socket references over a socket

			// Only send this person's cards
			game.me = game.clients[i];
			delete game.clients;

			// Additional 'me' properties
			game.me.isMyTurn = (game.turn === i);

			// Send the data
			s.emit('update', game);
		});
	}
}

module.exports = Game;