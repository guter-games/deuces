import React from 'react';
import Lobby from '../Lobby';
import Game from '../Game';
import Winner from '../Winner';
import autoBind from 'react-autobind';

const Screen = {
	LOADING: 0,
	LOBBY: 1,
	GAME: 2,
	WINNER: 3,
};

export default class Deuces extends React.Component {
	state = {
		screen: Screen.LOBBY,
		gameID: null,
	};

	constructor() {
		super();
		autoBind(this);

		// client.on('update', game => {
		// 	console.log('update', game);

		// 	const stateUpdate = { game };

		// 	if(game.state === GameState.PLAYING) {
		// 		stateUpdate.screen = Screen.GAME;
		// 	} else if(game.state === GameState.FINISHED) {
		// 		stateUpdate.screen = Screen.WINNER;
		// 	}

		// 	this.setState(stateUpdate);
		// });

		// client.on('bad_play', error => {
		// 	console.log('bad_play', error);
		// 	alert(`Bad Play: ${error}`);
		// });
	}

	// for testing:
	componentDidMount() {
		// const testData = JSON.parse(testGame);
		// console.log('testData = ', testData);

		setTimeout(() => {
			// ENABLE THE FOLLOWING LINE FOR TESTING:
			// this.setState({ game: testData, screen: Screen.GAME });
		}, 1000);
	}

	enterGame(gameID) {
		this.setState({ screen: Screen.GAME, gameID });
	}

	render() {
		switch(this.state.screen) {
			case Screen.LOADING: {
				return <div>Loading...</div>;
			}

			case Screen.LOBBY: {
				return <Lobby enterGame={ this.enterGame } />;
			}

			case Screen.GAME: {
				return <Game id={ this.state.gameID } />;
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
