const pathedSocket = require('./pathed_socket');
const NetClient = require("./net_client");
const Deuces = require("./deuces");

class Game {
	constructor(id, numPlayers) {
		this.io = pathedSocket(`/${id}`);
		this.io.on('connection', () => this.onClientConnect());

		this.netClients = [];
		this.deuces = new Deuces(numPlayers, () => this.onDeucesUpdate());

		this.players = [];
		this.state = GameState.WAITING;
		this.run = [];
		this.turn = 0; // Index of the player whose turn it is
		this.ply = 0; // Number of turns taken since the start of the game

		// Bind actions
		this.sockets.forEach((s, i) => {
			const client = this.clients[i];

			s.on('play_cards', cards => this.onPlayCards(client, s, cards));
			s.on('pass', () => this.onPass(client, s));
		});
	}

	onClientConnect(socket) {
		const client = new NetClient(socket);
		this.netClients.push(client);
		this.attachNetClientEvents(client);
	}

	attachNetClientEvents(client) {
		client.on('disconnect', () => this.onDisconnect());
		client.on('identify_as', player => this.onIdentifyAs(player));
		client.on('play_cards', cards => this.onPlayCards(client, s, cards));
		client.on('pass', () => this.onPass(client, s));
	}

	onIdentifyAs(netClient, player) {
		netClient.player = player;
	}

	onDeucesUpdate() {
		console.log('deuces updated');
		return;
		// Update the game state to all clients over the socket
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
}

module.exports = Game;
