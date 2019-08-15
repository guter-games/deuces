const Card = require('./card');

class Player {
	constructor() {
		this.name = this.constructor.NO_NAME;
		this.cards = [];
	}

	serialize() {
		return {
			name: this.name,
			cards: this.cards.map(card => card.serialize()),
		}
	}

	static deserialize(data) {
		const player = new Player();
		player.name = data.name;
		player.cards = data.cards.map(Card.deserialize);
		return player;
	}
}

// Players without names are slots that haven't been taken yet
Player.NO_NAME = null;

module.exports = Player;
