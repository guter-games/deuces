const server = require('http').createServer();
const socketIO = require('socket.io');
const handleConnections = require('./controllers/core');

const port = 3012;

const io = socketIO(server, {
	path: '/',
});

server.listen(port);

console.log(`Server started on port ${port}`);

handleConnections(io);
