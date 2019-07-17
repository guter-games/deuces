const server = require('http').createServer();
const socketIO = require('socket.io');
const handleConnections = require('./controllers/core');
const RulesAI = require('./rules_ai');

const port = 3012;

const io = socketIO(server, {});
server.listen(port);

console.log(`Server started on port ${port}`);

handleConnections(io);

// Start the AI
const ai = new RulesAI('http://localhost:3012');
ai.ready();
