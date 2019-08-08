import CoreConnection from "./core";

const socketPathPrefix = '/';

class GameConnection extends CoreConnection {
	constructor(gameID) {
		super(`${socketPathPrefix}${gameID}`);
	}

	createGame(numPlayers) {
		this.socket.emit('create_game', numPlayers);
	}
}

export default GameConnection;