const io = require('socket.io-client');
const Brain = require('./brain');

class AI {
	constructor(host) {
		// Setup the socket
		this.socket = io(host, { path: '/socket.io' });
		this.onConnected = new Promise((resolve, reject) => {
			this.socket.on('connect', resolve);
		});

		// Bind events
		this.socket.on('update', this.onUpdate.bind(this));

		// Setup the brain
		this.brain = new Brain();
	}

	// Prepares the AI to play the game
	ready() {
		this.onConnected.then(() => {
			this.socket.emit('change_name', { name: 'Flo' });
			this.socket.emit('change_want_n_players', { wantNPlayers: 2 });
			this.socket.emit('ready', { ready: true });
		});
	}

	onUpdate(game) {
		if(game.me.isMyTurn) {
			const play = this.brain.makeMove(game);
			this.socket.emit('play_cards', play);
		}
	}
}

module.exports = AI;
