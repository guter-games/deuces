const socketIO = require('socket.io');
const http = require('http');
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');

const Game = require('./game');
const loudSocket = require('./loud_socket');
const shortid = require('shortid');

const games = new Map();
const port = 3012;

(async function main() {
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

function getNextGameID() {
	return shortid.generate();
}

function createGame(numPlayers) {
	const id = getNextGameID();

	// Returns a new game with the same players
	function createSimilarGame() {
		const newId = createGame(numPlayers);
		for(let i = 0; i < numPlayers; i++) {
			games.get(newId).deuces.players[i].name = games.get(id).deuces.players[i].name;
		}
		return newId;
	}

	const game = new Game(id, numPlayers, createSimilarGame);
	games.set(id, game);
	return id;
}

function onCreateGame(req, res) {
	const numPlayers = parseInt(req.body.numPlayers, 10);
	const id = createGame(numPlayers);
	res.send(`${id}`);
}

function onClientConnect(socket) {
	loudSocket(socket);
	routeToGame(socket);
}

function routeToGame(socket) {
	const gameID = socket.handshake.query.gameID;
	const game = games.get(gameID);

	if(!game) {
		socket.disconnect();
		return;
	}

	game.onClientConnect(socket);
}
