const sequelize = require('./sequelize');

const fns = {};

fns.init = (klass, schema) => {
	klass.init(schema, { sequelize });
};

// Model.findByPk except it throws an error when the record isn't found
fns.findByPk = (klass, pk) => {
	return klass
		.findByPk(pk)
		.then(result => {
			if(result === null) {
				throw {
					klass,
					pk,
					error: new Error('Record not found'),
				};
			}

			return result;
		});
};

module.exports = fns;