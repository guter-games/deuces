const socketIO = require('socket.io');
const http = require('http');
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');

const theDbToConnect = require('./db');
const Game = require('./game');
const loudSocket = require('./loud_socket');
const shortid = require('shortid');

const games = new Map();
const port = 3012;

(async function main() {
	global.db = await theDbToConnect;
	recoverGames(db);

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

function onCreateGame(req, res) {
	const numPlayers = parseInt(req.body.numPlayers, 10);
	const id = getNextGameID();
	const game = new Game(id, numPlayers);
	game.createDBRecord();
	games.set(id, game);
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

async function recoverGames(db) {
	const activeGames = await db.games.find({ active: true });
	activeGames.forEach(recoverGame);
}

function recoverGame(gameRecord) {
	// console.log('recoverGame', gameRecord);
	const game = Game.fromDBRecord(gameRecord);
	games.set(game.id, game);
}
