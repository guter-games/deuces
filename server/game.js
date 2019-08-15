const EventEmitter = require('events');
const NetClient = require('./net_client');
const Deuces = require('./deuces');
const { remove } = require('./array_util');

class Game {
	constructor(id, numPlayers) {
		this.id = id;
		this.numPlayers = numPlayers;

		this.emitter = new EventEmitter();
		this.emitter.on('update', () => this.onUpdate());
		
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
		this.saveToDB();
		this.updateAllClients();
	}

	updateAllClients() {
		this.netClients.forEach(client => {
			client.emit('game_update', this.deuces.getGameStateForPlayer(client.player));
		});
	}

	loadFromDBRecord(record) {
		this.deuces = Deuces.fromDBRecord(record.deuces);
	}

	async createDBRecord() {
		await db.games.insert({
			id: this.id,
			numplayers: this.numPlayers,
		});

		this.saveToDB();
	}

	saveToDB() {
		return db.games.update({
			id: this.id,
		}, {
			active: !this.deuces.hasWinner(),
			deuces: this.deuces,
		});
	}

	static fromDBRecord(record) {
		const { id, numplayers } = record;

		const game = new Game(id, numplayers);
		game.deuces.load(record.deuces);
		return game;
	}
}

module.exports = Game;
