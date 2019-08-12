const Hand = require("../hand");
const Card = require("../card");

const mine = new Hand([
	new Card("H", "9"),
	new Card("C", "9"),
]);

const hers = new Hand([
	new Card("D", "9"),
	new Card("S", "9"),
]);

console.log('mine', mine.getValue());
console.log('hers', hers.getValue());

console.log('mine > hers', mine.isBetterThan(hers));
console.log('hers > mine', hers.isBetterThan(mine));
