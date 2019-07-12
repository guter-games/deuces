class DummySocket {
	constructor() {
		this.connect = noop
	}

}

function noop() {}

module.exports = DummySocket
