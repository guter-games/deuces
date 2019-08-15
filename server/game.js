const { Model, INTEGER, STRING } = require('sequelize');
const { init } = require('./model_util');

const NetClient = require('./net_client');
const Deuces = require('./deuces');
const { remove } = require('./array_util');

class Game extends Model {
	constructor() {
		super();	
		this.netClients = [];
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

	async onNewIdentity(netClient, { name }) {
		const deuces = await this.getDeuces();
		const playerIdx = deuces.getUnusedPlayerIdx();

		if(playerIdx !== -1) {
			deuces.setPlayerName(playerIdx, name);
		}

		netClient.emit('new_identity', playerIdx);
	}

	onIdentifyAs(netClient, { player }) {
		netClient.player = player;

		setTimeout(() => {
			this.updateAllClients();
		}, 3000);
	}

	async onPlayCards(netClient, { cards }) {
		const error = (await this.getDeuces()).onPlayCards(netClient.player, cards);

		if(error) {
			this.badPlay(netClient, error);
		}
	}

	async onPass(netClient) {
		const success = (await this.getDeuces()).onPass(netClient.player);

		if(!success) {
			this.badPlay(netClient, 'You cannot pass on a free turn');
		}
	}

	badPlay(netClient, error) {
		netClient.emit('bad_play', error);
	}

	onUpdate() {
		console.log('onUpdate');
		this.updateAllClients();
	}

	async updateAllClients() {
		const deuces = await this.getDeuces();
		console.log('deuces', deuces);
		console.log('fnkton', deuces.getGameStateForPlayer);
		this.netClients.forEach(client => {
			client.emit('game_update', deuces.getGameStateForPlayer(client.player));
		});
	}

	async getDeuces() {
		await this.reload();
		console.log('this.deuces_id', this.deuces_id);
		return await Deuces.findByPk(this.deuces_id);
	}

	static async make(values) {
		const game = await Game.create(values);
		const deuces = await Deuces.make(game);
		// await game.setDeuces(deuces);
		game.deuces_id = deuces.id;
		await game.save();
		return game;
	}
}

init(Game, {
	numPlayers: INTEGER,
	deuces_id: INTEGER,
});

// Game.hasOne(Deuces, { as: 'Deuces' });
// Deuces.hasOne(Game, { constraints: false });

// Game.belongsTo(Deuces);
// Deuces.belongsTo(Game, { constraints: false });

// Game.hasOne(Deuces, { as: 'Deuces' });
// Deuces.hasOne(Game);

module.exports = Game;
