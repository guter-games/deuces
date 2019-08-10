const Game = require('./game');
const loudSocket = require('./loud_socket');

const games = new Map();
let nextGameID = 1;

function route(socket) {
	socket.use((packet, next) => {
		const [ uri, params ] = packet;
		const { gameID } = params;

		if(typeof gameID === 'undefined') {
			next();
			return;
		}

		const game = games.get(gameID);
		game.on(uri, params);
	});
}

module.exports = (socket, io) => {
	route(socket);

	// Attach a debugger
	loudSocket(socket);
	
	// Bind messages
	socket.on('create_game', numPlayers => {
		const id = nextGameID++;
		const game = new Game(id, numPlayers);
		games.set(id, game);
		socket.emit('create_game', id);
	});
};