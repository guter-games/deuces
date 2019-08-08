const httpServer = require('./http_server');
const socketIO = require('socket.io');

module.exports = path => socketIO(httpServer, { path });