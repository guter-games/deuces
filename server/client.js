class Client {
	constructor(id) {
		this.id = id;
		this.name = 'anon';
		this.ready = false;
		this.wantNPlayers = 4;
		this.status = 'lobby';
		this.isAI = false;
		
		this.cards = [];
	}
}

module.exports = Client;
