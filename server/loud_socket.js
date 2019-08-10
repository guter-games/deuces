module.exports = client => {
	client.use((packet, next) => {
		console.log('client wants to', packet[0], ':', packet[1]);
		next();
	});
};