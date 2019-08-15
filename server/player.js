const { Model, STRING } = require('sequelize');
const { init } = require('./model_util');
const Card = require('./card');

class Player extends Model {
	constructor() {
		super();
		this.name = this.constructor.NO_NAME;
		this.cards = [];
	}
}

// Players without names are slots that haven't been taken yet
Player.NO_NAME = null;

init(Player, {
	name: STRING,
});

Player.hasMany(Card);

module.exports = Player;
