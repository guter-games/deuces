const unknownPlayer = -1;

class NetClient {
	constructor(socket) {
		this.socket = socket;
		this.player = unknownPlayer;
	}

	on(evt, action) {
		this.socket.on(evt, action);
	}
}

module.exports = NetClient;