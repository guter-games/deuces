import React from 'react';
import Lobby from '../Lobby';
import Game from '../Game';
import client from '../ws';

const Screen = {
	LOADING: 0,
	LOBBY: 1,
	GAME: 2,
};

const testGame = `{"state":0,"turn":0,"pool":[{"suit":"dime","rank":"3"},{"suit":"dime","rank":"5"},{"suit":"dime","rank":"6"},{"suit":"dime","rank":"7"},{"suit":"dime","rank":"8"},{"suit":"dime","rank":"J"},{"suit":"club","rank":"3"},{"suit":"club","rank":"4"},{"suit":"club","rank":"5"},{"suit":"club","rank":"7"},{"suit":"club","rank":"8"},{"suit":"club","rank":"9"},{"suit":"club","rank":"10"},{"suit":"club","rank":"Q"},{"suit":"club","rank":"A"},{"suit":"club","rank":"2"},{"suit":"heart","rank":"3"},{"suit":"heart","rank":"6"},{"suit":"heart","rank":"7"},{"suit":"heart","rank":"9"},{"suit":"heart","rank":"10"},{"suit":"heart","rank":"J"},{"suit":"heart","rank":"Q"},{"suit":"heart","rank":"K"},{"suit":"heart","rank":"A"},{"suit":"spade","rank":"3"},{"suit":"spade","rank":"4"},{"suit":"spade","rank":"5"},{"suit":"spade","rank":"7"},{"suit":"spade","rank":"9"},{"suit":"spade","rank":"10"},{"suit":"spade","rank":"J"},{"suit":"spade","rank":"K"},{"suit":"spade","rank":"A"},{"suit":"spade","rank":"2"}],"me":{"name":true,"ready":"we","cards":[{"suit":"dime","rank":"2"},{"suit":"heart","rank":"8"},{"suit":"dime","rank":"9"},{"suit":"dime","rank":"Q"},{"suit":"club","rank":"K"},{"suit":"heart","rank":"5"},{"suit":"club","rank":"J"},{"suit":"spade","rank":"6"},{"suit":"heart","rank":"2"},{"suit":"club","rank":"6"},{"suit":"dime","rank":"10"},{"suit":"spade","rank":"8"},{"suit":"dime","rank":"K"},{"suit":"heart","rank":"4"},{"suit":"spade","rank":"Q"},{"suit":"dime","rank":"A"},{"suit":"dime","rank":"4"}]}}`;

export default class Deuces extends React.Component {
	state = { screen: Screen.LOADING, game: null };

	constructor() {
		super();
		
		client.connect().then(() => {
			this.setState({ screen: Screen.LOBBY });
		});

		client.on('update', game => {
			console.log('update', game);
			this.setState({ game, screen: Screen.GAME });
		});

		client.on('bad_play', error => {
			console.log('bad_play', error);
			// alert(`Bad Play: ${error}`);
		});
	}

	// for testing:
	componentDidMount() {
		const testData = JSON.parse(testGame);
		console.log('testData = ', testData);

		setTimeout(() => {
			// this.setState({ game: testData, screen: Screen.GAME });
		}, 1000);
	}

	render() {
		switch(this.state.screen) {
			case Screen.LOADING: {
				return <div>Loading...</div>;
			}

			case Screen.LOBBY: {
				return <Lobby />;
			}

			case Screen.GAME: {
				return <Game game={ this.state.game } />;
			}

			default: {
				return null;
			}
		}
	}
}
