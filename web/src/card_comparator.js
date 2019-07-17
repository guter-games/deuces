// A comparator to sort cards
export default function(a, b) {
	const rankOrder = ["3", "4", "5", "6", "7", "8", "9", "T", "J", "Q", "K", "A", "2"];
	const suitOrder = ["D", "C", "H", "S"];

	if(a.rank === b.rank) {
		return suitOrder.indexOf(a.suit) - suitOrder.indexOf(b.suit);
	}

	return rankOrder.indexOf(a.rank) - rankOrder.indexOf(b.rank);
}