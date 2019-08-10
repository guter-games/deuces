const EventEmitter = require('events');
const NetClient = require('./net_client');
const Deuces = require('./deuces');
const { remove } = require('./array_util');

class Game {
	constructor(id, numPlayers) {
		this.id = id;

		this.emitter = new EventEmitter();
		this.emitter.on('update', () => this.updateAllClients());
		
		this.netClients = [];
		this.deuces = new Deuces(numPlayers, this.emitter);
		this.deuces.start();
	}

	onClientConnect(socket) {
		const client = new NetClient(socket);
		this.netClients.push(client);
		this.attachNetClientEvents(client);
	}

	attachNetClientEvents(client) {
		client.on('disconnect', () => this.onDisconnect(client));
		client.on('identify_as', data => this.onIdentifyAs(client, data));
		client.on('play_cards', cards => this.onPlayCards(client, s, cards));
		client.on('pass', () => this.onPass(client, s));
	}

	onDisconnect(netClient) {
		remove(this.netClients, netClient);
	}

	onIdentifyAs(netClient, { player }) {
		netClient.player = player;
		this.updateAllClients();
	}

	updateAllClients() {
		this.netClients.forEach(client => {
			client.emit('game_update', this.deuces.getGameStateForPlayer(client.player));
		});
	}
}

module.exports = Game;
