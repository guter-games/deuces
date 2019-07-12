const Card = require("./card");
const Hand = require("./hand");
const aiTurn = require("./ai/play");

const GameState = {
	WAITING: 0,
	PLAYING: 1,
	FINISHED: 2, // Generally this is when someone won
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
			s.on('pass', () => this.onPass(client, s));
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
				this.dealCardTo(c);
			}
		});

		// Pick the starting player
		this.turn = this.getPlayerWithMinCard();

		// Reset the game state
		this.run = [];
		this.winner = null;
		this.state = GameState.PLAYING;

		// Update all players
		this.updateAllClients();

		// If it's ai's turn, then go.
		this.aiMove();
	}

	dealCardTo(client) {
		client.cards.push(this.popRandomFromPool());
	}

	// Returns the player with the minimum value card
	getPlayerWithMinCard() {
		let minPlayer = null;
		let minCardValue = null;

		for(let i = 0; i < this.clients.length; i++) {
			const c = this.clients[i];

			c.cards.forEach(card => {
				const value = card.getValue();

				if(minPlayer === null || value < minCardValue) {
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

	onPass(client, socket) {
		this.run = [];
		this.nextTurn();
		this.dealCardTo(client);
		this.updateAllClients();
	}

	onPlayCards(client, socket, clientCards) {
		const cards = clientCards.map(c => new Card(c.suit, c.rank));
		// TODO: verify that the client actually has these cards

		const oldCards = this.run[this.run.length - 1];

		// Check valid play
		const error = this.playIsValid(cards, oldCards, this.run);
		if (error) {
			socket.emit('bad_play', error);
			return;
		}

		// Allow the play
		// 		Record the play
		this.run.push(cards);

		// 		Take away the played cards
		this.playCards(client, cards);

		// 		Check if the player won
		if(client.cards.length === 0) {
			this.state = GameState.FINISHED;
			this.winner = client.name;
		}

		//		Go to the next player
		this.nextTurn();

		// 		Update the game state
		this.updateAllClients();
	}

	// Returns an error if there is one
	playIsValid(cards, oldCards, run) {
		// Check that the cards themselves can be played together
		const hand = new Hand(cards);

		if(!hand.isValid()) {
			return 'That is not a valid hand';
		}

		// Check that the # of cards played was right
		if(run.length > 0) {
			const lastNumCardsPlayed = oldCards.length;

			if(cards.length !== lastNumCardsPlayed) {
				return 'Wrong number of cards';
			}

			// Check that the cards are higher than those last played
			const oldHand = new Hand(oldCards);

			if(oldHand.getValue() > hand.getValue()) {
				return 'This is not higher than the last-played hand';
			}
		}

		return null;
	}

	nextTurn() {
		this.turn = (this.turn + 1) % this.clients.length;
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

	// Update the game state to all clients over the socket
	updateAllClients() {
		this.sockets.forEach((s, i) => {
			const game = Object.assign({}, this);
			delete game.sockets; // Can't send socket references over a socket

			// Information about other players
			game.others = [];

			for(let j = 0; j < game.clients.length; j++) {
				if(i !== j) {
					const name = game.clients[j].name;
					const numCards = game.clients[j].cards.length;
					game.others.push({ name, numCards });
				}
			}

			// Only send this person's cards
			game.me = game.clients[i];
			delete game.clients;

			// Additional 'me' properties
			game.me.isMyTurn = (game.turn === i);

			// Additional properties
			game.playerTurnName = this.clients[game.turn].name;

			// Send the data
			s.emit('update', game);
		});
	}

	aiMove() {
		if (this.clients[this.turn].isAI) {
			const aiPlay = aiMove(this.clients[this.turn].cards, this.run, this.pool); 
		}
	}
}

module.exports = Game;
