import React from 'react';
import Lobby from '../Lobby';
import Game from '../Game';
import Winner from '../Winner';
import client from '../ws';

const Screen = {
	LOADING: 0,
	LOBBY: 1,
	GAME: 2,
	WINNER: 3,
};

const GameState = {
	WAITING: 0,
	PLAYING: 1,
	FINISHED: 2, // Generally this is when someone won
};

const testGame = `{"others":[],"state":0,"turn":0,"pool":[{"suit":"D","rank":"3"},{"suit":"D","rank":"5"},{"suit":"D","rank":"6"},{"suit":"D","rank":"7"},{"suit":"D","rank":"8"},{"suit":"D","rank":"J"},{"suit":"C","rank":"3"},{"suit":"C","rank":"4"},{"suit":"C","rank":"5"},{"suit":"C","rank":"7"},{"suit":"C","rank":"8"},{"suit":"C","rank":"9"},{"suit":"C","rank":"10"},{"suit":"C","rank":"Q"},{"suit":"C","rank":"A"},{"suit":"C","rank":"2"},{"suit":"H","rank":"3"},{"suit":"H","rank":"6"},{"suit":"H","rank":"7"},{"suit":"H","rank":"9"},{"suit":"H","rank":"10"},{"suit":"H","rank":"J"},{"suit":"H","rank":"Q"},{"suit":"H","rank":"K"},{"suit":"H","rank":"A"},{"suit":"S","rank":"3"},{"suit":"S","rank":"4"},{"suit":"S","rank":"5"},{"suit":"S","rank":"7"},{"suit":"S","rank":"9"},{"suit":"S","rank":"10"},{"suit":"S","rank":"J"},{"suit":"S","rank":"K"},{"suit":"S","rank":"A"},{"suit":"S","rank":"2"}],"me":{"name":true,"ready":"we","cards":[{"suit":"D","rank":"2"},{"suit":"H","rank":"8"},{"suit":"D","rank":"9"},{"suit":"D","rank":"Q"},{"suit":"C","rank":"K"},{"suit":"H","rank":"5"},{"suit":"C","rank":"J"},{"suit":"S","rank":"6"},{"suit":"H","rank":"2"},{"suit":"C","rank":"6"},{"suit":"D","rank":"10"},{"suit":"S","rank":"8"},{"suit":"D","rank":"K"},{"suit":"H","rank":"4"},{"suit":"S","rank":"Q"},{"suit":"D","rank":"A"},{"suit":"D","rank":"4"}]}}`;

export default class Deuces extends React.Component {
	state = {
		screen: Screen.LOADING,
		game: null,
	};

	constructor() {
		super();

		client.connect().then(() => {
			this.setState({ screen: Screen.LOBBY });
		});

		client.on('update', game => {
			console.log('update', game);

			const stateUpdate = { game };

			if(game.state === GameState.PLAYING) {
				stateUpdate.screen = Screen.GAME;
			} else if(game.state === GameState.FINISHED) {
				stateUpdate.screen = Screen.WINNER;
			}

			this.setState(stateUpdate);
		});

		client.on('bad_play', error => {
			console.log('bad_play', error);
			alert(`Bad Play: ${error}`);
		});
	}

	// for testing:
	componentDidMount() {
		const testData = JSON.parse(testGame);
		console.log('testData = ', testData);

		setTimeout(() => {
			// ENABLE THE FOLLOWING LINE FOR TESTING:
			//this.setState({ game: testData, screen: Screen.GAME });
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

			case Screen.WINNER: {
				return <Winner game={ this.state.game } />;
			}

			default: {
				return null;
			}
		}
	}
}
