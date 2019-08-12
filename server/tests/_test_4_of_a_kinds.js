const Hand = require("../hand");
const Card = require("../card");

const mine = new Hand([
	new Card("H", "5"),
	new Card("C", "7"),
	new Card("H", "7"),
	new Card("D", "7"),
	new Card("S", "7"),
]);

const hers = new Hand([
	new Card("D", "3"),
	new Card("S", "4"),
	new Card("C", "4"),
	new Card("D", "4"),
	new Card("H", "4"),
]);

console.log('mine', mine.getValue());
console.log('hers', hers.getValue());
