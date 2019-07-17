/*

	STRATEGY

	leading
	following - 

	1. When following, 

*/

class Brain {
	// INPUT: current state of the game
	// OUTPUT: an array of cards to play
	makeMove(game) {
		return [game.me.cards[0]];
	}
}

module.exports = Brain;