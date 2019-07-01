import io from 'socket.io-client';

// const socketURL = 'http://tener.serveo.net/';
const socketURL = process.env.SERVER_URI || 'http://localhost:3012';

class Client {
	connect() {
		this.socket = io(socketURL);

		return new Promise((resolve, reject) => {
			this.socket.on('connect', resolve);
		});
	}

	on(evt, action) {
		this.socket.on(evt, action);
	}

	ready(ready) {
		console.log('rdy');
		this.socket.emit('ready', { ready });
	}

	start(start) {
		console.log('start');
		this.socket.emit('start', { start });
	}

	playCards(cards) {
		console.log('emit');
		this.socket.emit('play_cards', cards);
	}

	pass() {
		this.socket.emit('pass');
	}

	changeName(name) {
		console.log('change name ', name);
		this.socket.emit('change_name', { name });
	}

	id() {
		return this.socket.id;
	}
}

export default new Client();
