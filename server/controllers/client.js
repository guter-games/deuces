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
      	      syncLobbyClients();
    	})

	client.emit('lobby_players', clients)

	client.on('change_name', ({ name }) => {
		console.log('changed name ', c.name, ' to ', name);
		c.name = name;
		syncLobbyClients();
	});

	client.on('change_want_n_players', ({ wantNPlayers }) => {
		console.log('changed wantNPlayers ', c.wantNPlayers, ' to ', wantNPlayers);

		c.wantNPlayers = parseInt(wantNPlayers);

		tryToMatch(c);
	});

	client.on('ready', ({ ready }) => {
		console.log('client ready', c.name, ready);

		c.ready = ready;

		tryToMatch(c);
	})

	client.on('start_with_ai', ({ start }) => {
		console.log('client start with ai', c.name, start);

		// Initialize the game
		const game = new Game(clients, sockets);

		// Start the new game
		game.start();

		for (const client of clients) {
			client.status = 'ingame';
		}

		syncLobbyClients();
	})
}

function tryToMatch(newClient) {
        const match = matchClients(newClient);
        if (match) {
                console.log('found match')
                // Initialize the game
                const game = new Game(match.clients, match.sockets);

                // Start the new game
                game.start();

                for (const client of match.clients) {
                        client.status = 'ingame';
                }
        }

	syncLobbyClients();
}

function syncLobbyClients() {
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

// Returns a list of clients to match or null if no match possible
function matchClients(newReady) {
	const readyClients = clients.filter(c => c.ready);
	const wantThis = readyClients.filter(c => c.wantNPlayers === newReady.wantNPlayers);

	console.log(`want ${newReady.wantNPlayers} got ${wantThis.length}`);
	if (wantThis.length >= newReady.wantNPlayers) {
	debugger;
		let match = { clients: [], sockets: [] };
		for (let i = 0; i < clients.length; i++) {
			if(clients[i].ready && clients[i].wantNPlayers === newReady.wantNPlayers) {
				match.clients.push(clients[i])
				match.sockets.push(sockets[i])
			}
		}

		return match;
	}

	return null;
}

module.exports = handleClient;
