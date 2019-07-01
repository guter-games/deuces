import io from 'socket.io-client';

const socketURL = 'http://localhost:3012';

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

	ready(name, ready) {
		this.socket.emit('ready', { name, ready });
	}

	playCards(cards) {
		console.log('emit');
		this.socket.emit('play_cards', cards);
	}
}

export default new Client();