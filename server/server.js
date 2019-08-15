const socketIO = require('socket.io');
const http = require('http');
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');

const db = require('./sequelize');
const { findByPk } = require('./model_util');
const Game = require('./game');
const loudSocket = require('./loud_socket');

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

async function onCreateGame(req, res) {
	const numPlayers = parseInt(req.body.numPlayers, 10);
	const game = await Game.make({ numPlayers });
	console.log(await game.getDeuces());
	res.send(`${game.id}`);
}

function onClientConnect(socket) {
	loudSocket(socket);
	routeToGame(socket);
}

function routeToGame(socket) {
	const gameID = socket.handshake.query.gameID;
	console.log('finding by ', gameID);
	// findByPk.bind(Game)(Game, gameID)
	Game.findByPk(gameID)
		.then(game => {
			console.log('game', game);
			// console.log('game.id = ', game.id);
			game.onClientConnect(socket);
		})
		.catch(() => socket.disconnect());
}
