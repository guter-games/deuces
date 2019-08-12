const Hand = require("../hand");
const Card = require("../card");

const mine = new Hand([
	new Card("D", "T"),
	new Card("C", "T"),
]);

const hers = new Hand([
	new Card("H", "T"),
	new Card("S", "T"),
]);

console.log('mine', mine.getValue());
console.log('hers', hers.getValue());

console.log('mine > hers', mine.isBetterThan(hers));
console.log('hers > mine', hers.isBetterThan(mine));
