class Client {
	constructor(id) {
		this.id = id;
		this.name = 'anon';
		this.ready = false;
		this.start = false;
		this.status = 'lobby';
		
		this.cards = [];
	}
}

module.exports = Client;
