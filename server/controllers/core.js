const handleClient = require('./client');
const Game = require('../game');

function handleConnections(io) {
	io.on('connection', client => {
		handleClient(client);
	});
}

module.exports = handleConnections;