require('dotenv').config();
const massive = require('massive');

const connect = massive({
	host: process.env.POSTGRES_HOST,
	port: process.env.POSTGRES_PORT || 5432,
	database: process.env.POSTGRES_DB,
	user: process.env.POSTGRES_USER,
	password: process.env.POSTGRES_PASSWORD,
});

module.exports = connect;
