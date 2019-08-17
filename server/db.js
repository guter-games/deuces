const massive = require('massive');

const connect = massive({
	host: 'localhost',
	port: 5432,
	database: process.env.POSTGRES_DB,
	user: process.env.POSTGRES_USER,
	password: process.env.POSTGRES_PASSWORD,
});

module.exports = connect.then(db => {
	return new Promise(async resolve => {
		await db.query(`CREATE TABLE IF NOT EXISTS games(
			id VARCHAR(100) PRIMARY KEY,
			numPlayers INTEGER,
			active BOOLEAN,
			deuces jsonb
		)`);

		resolve(db);
	});
});