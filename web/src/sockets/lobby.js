import CoreConnection from "./core";

const socketPath = '/';

class LobbyConnection extends CoreConnection {
	constructor() {
		super(socketPath);
	}

	createGame(numPlayers) {
		this.socket.emit('create_game', numPlayers);
	}
}

export default LobbyConnection;