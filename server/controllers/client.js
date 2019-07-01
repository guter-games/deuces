const Client = require('../client');
const Game = require('../game');

const clientsToStartGame = 1;

// Parallel arrays
const clients = [];
const sockets = [];

function handleClient(client) {
	console.log('client connected');

	// Ready handler
	client.on('ready', ({ ready, name }) => {
		console.log('client ready', name, ready);

		// Update the clients list
		const c = new Client(name, ready);

		if(!updateExistingClient(c)) {
			clients.push(c);
			sockets.push(client);
		}

		sendLobbyUpdate();

		// Start the game if there are enough ready players
		const readyPlayers = clients.filter(c => c.ready).length;
		
		if(readyPlayers === clientsToStartGame) {
			// Initialize the game
			const game = new Game(clients, sockets);

			// Start the new game
			game.start();
		}
	});

	// Disconnect handler
	client.on('disconnect', () => {
		const idx = sockets.indexOf(client);
		clients.splice(idx, 1);
		sockets.splice(idx, 1);
		sendLobbyUpdate();
	});
}

// Update the lobby state to all clients
function sendLobbyUpdate() {
	emitToAll('update_lobby', clients);
}

function emitToAll(message, data) {
	sockets.forEach(s => s.emit(message, data));
}

// Updates an existing client's ready state
// Returns whether or not an existing client was found
function updateExistingClient(client) {
	for(let i = 0; i < clients.length; i++) {
		if(clients[i].name === client.name) {
			clients[i].ready = client.ready;
			return true;
		}
	}

	return false;
}

module.exports = handleClient;
