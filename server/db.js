const massive = require('massive');

const connect = massive({
	host: 'localhost',
	port: 5432,
	database: process.env.POSTGRES_DB,
	user: process.env.POSTGRES_USER,
	password: process.env.POSTGRES_PASSWORD,
});

module.exports = connect;