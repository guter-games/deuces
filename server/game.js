const EventEmitter = require('events');
const NetClient = require('./net_client');
const Deuces = require('./deuces');
const { remove } = require('./array_util');

class Game {
	constructor(id, numPlayers, createSimilarGame) {
		this.id = id;
		this.numPlayers = numPlayers;

		this.emitter = new EventEmitter();
		this.emitter.on('update', () => this.onUpdate());

		this.netClients = [];
		this.deuces = new Deuces(numPlayers, this.emitter, createSimilarGame);
		this.deuces.start();
	}

	onClientConnect(socket) {
		const client = new NetClient(socket);
		this.netClients.push(client);
		this.attachNetClientEvents(client);
	}

	attachNetClientEvents(client) {
		this.attachEvent(client, 'disconnect', this.onDisconnect);
		this.attachEvent(client, 'new_identity', this.onNewIdentity);
		this.attachEvent(client, 'identify_as', this.onIdentifyAs);
		this.attachEvent(client, 'play_cards', this.onPlayCards);
		this.attachEvent(client, 'pass', this.onPass);
	}

	attachEvent(client, event, handler) {
		client.on(event, data => handler.bind(this)(client, data));
	}

	onDisconnect(netClient) {
		remove(this.netClients, netClient);
	}

	onNewIdentity(netClient, { name }) {
		const playerIdx = this.deuces.getUnusedPlayerIdx();

		if(playerIdx !== -1) {
			this.deuces.setPlayerName(playerIdx, name);
		}

		netClient.emit('new_identity', playerIdx);
	}

	onIdentifyAs(netClient, { player }) {
		netClient.player = player;
		this.onUpdate();
	}

	onPlayCards(netClient, { cards }) {
		const error = this.deuces.onPlayCards(netClient.player, cards);

		if(error) {
			this.badPlay(netClient, error);
		}
	}

	onPass(netClient) {
		const success = this.deuces.onPass(netClient.player);

		if(!success) {
			this.badPlay(netClient, 'You cannot pass on a free turn');
		}
	}

	badPlay(netClient, error) {
		netClient.emit('bad_play', error);
	}

	onUpdate() {
		this.updateAllClients();
	}

	updateAllClients() {
		this.netClients.forEach(client => {
			client.emit('game_update', this.deuces.getGameStateForPlayer(client.player));
		});
	}
}

module.exports = Game;
