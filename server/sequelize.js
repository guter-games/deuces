const Sequelize = require('sequelize');

const sequelize = new Sequelize(process.env.POSTGRES_DB, process.env.POSTGRES_USER, process.env.POSTGRES_PASSWORD, {
	host: 'localhost',
	port: 5432,
	dialect: 'postgres',
	// logging: false,
});

sequelize
  .authenticate()
  .then(() => console.log('Connection has been established successfully.'))
  .catch(err => console.error('Unable to connect to the database:', err));

sequelize.sync({ alter: true, force: true }, err => console.log('Sequelize failed to sync', err));

module.exports = sequelize;