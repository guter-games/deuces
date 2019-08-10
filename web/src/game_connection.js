import io from 'socket.io-client';

const socketURL = process.env.REACT_APP_SERVER_URI || 'http://localhost:3012';
const socketPath = process.env.REACT_APP_SERVER_PATH || '/';

class GameConnection {
	constructor(gameID) {
		this.gameID = gameID;
	}

	connect() {
		this.socket = io(socketURL, { path: socketPath, query: `gameID=${this.gameID}` });
	}

	disconnect() {
		this.socket.disconnect();
	}

	on(evt, action) {
		this.socket.on(evt, action);
	}

	emit(uri, params) {
		this.socket.emit(uri, { gameID: this.gameID, ...params });
	}

	identifyAs(player) {
		this.emit('identify_as', { player });
	}
}

export default GameConnection;