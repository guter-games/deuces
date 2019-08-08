import io from 'socket.io-client';

const socketURL = process.env.REACT_APP_SERVER_URI || 'http://localhost:3012';

class CoreConnection {
	constructor(socketPath) {
		this.socketPath = process.env.REACT_APP_SERVER_PATH || socketPath;
	}

	connect() {
		this.socket = io(socketURL, { path: this.socketPath });
	}

	disconnect() {
		this.socket.disconnect();
	}

	on(evt, action) {
		this.socket.on(evt, action);
	}
}

export default CoreConnection;