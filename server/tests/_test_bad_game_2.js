const Hand = require("./hand");
const Card = require("./card");

const mine = new Hand([
	new Card("H", "4"),
	new Card("C", "4"),
	new Card("D", "4"),
]);

const hers = new Hand([
	new Card("D", "3"),
	new Card("S", "3"),
	new Card("H", "3"),
]);

console.log('mine', mine.getValue());
console.log('hers', hers.getValue());

// Additional info
const poker = require('poker-hands');
console.log('hers.toString', hers.toString());
console.log('hers.straight', poker.hasStraight(hers.toString()));

