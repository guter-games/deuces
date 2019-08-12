class Player {
	constructor() {
		this.name = this.constructor.NO_NAME;
		this.cards = [];
	}
}

// Players without names are slots that haven't been taken yet
Player.NO_NAME = null;

module.exports = Player;
