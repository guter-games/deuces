const server = require('./http_server');
const pathedSocket = require('./pathed_socket');
const handleConnections = require('./controllers/core');

const port = 3012;
server.listen(port);

const io = pathedSocket('/');
handleConnections(io);


console.log(`Server started on port ${port}`);