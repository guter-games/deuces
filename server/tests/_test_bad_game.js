const Hand = require("./hand");
const Card = require("./card");

const mine = new Hand([
	new Card("H", "9"),
	new Card("D", "9"),
	new Card("S", "9"),
	new Card("C", "3"),
	new Card("D", "3"),
]);

const hers = new Hand([
	new Card("D", "A"),
	new Card("S", "A"),
	new Card("H", "A"),
	new Card("C", "K"),
	new Card("S", "K"),
]);

console.log('mine', mine.getValue());
console.log('hers', hers.getValue());


