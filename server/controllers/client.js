const Client = require('../client');
const Game = require('../game');

const clientsToStartGame = 2;

// Parallel arrays
const clients = [];
const sockets = [];

function handleClient(client) {
	console.log('client connected');

	// Update the clients list
	const c = new Client(client.id);

	clients.push(c);
	sockets.push(client);

	// On disconnect
	client.on('disconnect', () => {
      	      const i = clients.indexOf(c);
      	      clients.splice(i, 1);
      	      sockets.splice(i, 1);
      	      syncLobby();
    	})

	client.emit('lobby_players', clients)

	client.on('change_name', ({ name }) => {
		console.log('changed name ', c.name, ' to ', name);
		c.name = name;
		syncLobby();
	});

	client.on('ready', ({ ready }) => {
		console.log('client ready', c.name, ready);

		c.ready = ready;

		syncLobby();
	})

	// Start handler
	client.on('start', ({ start }) => {
		console.log('client start', c.name, start);

		c.start = start;

		// Start the game if there are enough ready players
		const readyPlayers = clients.filter(c => c.ready);
		const startPlayers = clients.filter(c => c.start);

		// XXX if someone idles in ready, this screws the whole server
		if(startPlayers.length >= clientsToStartGame &&
		   startPlayers.length >= Math.min(readyPlayers.length, 4)) {
			// Initialize the game
			const game = new Game(clients, sockets);

			// Start the new game
			game.start();

			for (const client of startPlayers) {
				client.status = 'ingame';
			}
		}

		syncLobby();
	});

}

function syncLobby() {
	for (const sock of sockets) {
		sock.emit('lobby_players', clients);
	}
}

// Updates an existing client's ready state
// Returns whether or not an existing client was found
function clientExists(client) {
	for(let i = 0; i < clients.length; i++) {
		if(clients[i].name === client.name) {
			clients[i].ready = client.ready;
			return true;
		}
	}

	return false;
}

module.exports = handleClient;
