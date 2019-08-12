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

	
	// Bind socket message handlers
	attachDebugger(client);

	client.on('disconnect', () => {
		const i = clients.indexOf(c);
		clients.splice(i, 1);
		sockets.splice(i, 1);
	});

	client.on('create_game', numPlayers => {
		
	});

	client.on('start_with_ai', ({ start }) => {
		console.log('client start with ai', c.name, start);

		// Initialize the game
		const game = new Game(clients, sockets);

		// Start the new game
		game.start();

		for (const client of clients) {
			client.status = 'ingame';
		}
	});
}

function attachDebugger(client) {
	client.use((packet, next) => {
		console.log('client wants to', packet[0], ':', packet.slice(1));
		next();
	});
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
}

// Returns a list of clients to match or null if no match possible
function matchClients(newReady) {
	const readyClients = clients.filter(c => c.ready);
	const wantThis = readyClients.filter(c => c.wantNPlayers === newReady.wantNPlayers);

	console.log(`want ${newReady.wantNPlayers} got ${wantThis.length}`);
	if (wantThis.length >= newReady.wantNPlayers) {
		let match = { clients: [], sockets: [] };
		for (let i = 0; i < clients.length; i++) {
			if(clients[i].ready && clients[i].wantNPlayers === newReady.wantNPlayers) {
				match.clients.push(clients[i])
				match.sockets.push(sockets[i])

				if (match.clients.length === newReady.wantNPlayers) {
					break;
				}
			}
		}

		return match;
	}

	return null;
}

module.exports = handleClient;
