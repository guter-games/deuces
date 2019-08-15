const { Model } = require('sequelize');
const { init } = require('./model_util');
const Card = require('./card');

class Run extends Model {
}

init(Run);
Run.hasMany(Card);

module.exports = Run;