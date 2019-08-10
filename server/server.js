const socketIO = require('socket.io');
const http = require('http');
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');

const Game = require('./game');
const loudSocket = require('./loud_socket');

const games = new Map();
let nextGameID = 1;
const port = 3012;

(function main() {
	// Listen for clients
	const app = express();
	app.use(bodyParser.urlencoded({ extended: true }));
	app.use(bodyParser.json());
	app.use(cors());

	const server = http.createServer(app);
	server.listen(port);
	
	// Setup the lobby route
	app.post('/create_game', onCreateGame);

	const io = socketIO(server, { path: '/socket.io' });
	io.on('connection', onClientConnect);

	// Send status message
	console.log(`Server started on port ${port}`);
})();

function onCreateGame(req, res) {
	const numPlayers = parseInt(req.body.numPlayers, 10);
	const id = nextGameID++;
	const game = new Game(id, numPlayers);
	games.set(id, game);
	res.send(`${id}`);
}

function onClientConnect(socket) {
	loudSocket(socket);
	routeToGame(socket);
}

function routeToGame(socket) {
	const gameID = parseInt(socket.handshake.query.gameID, 10);
	const game = games.get(gameID);

	if(!game) {
		socket.disconnect();
		return;
	}

	game.onClientConnect(socket);
}
