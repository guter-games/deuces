import React from "react";
import Stats from '../Stats';
import Me from '../Me';
import Pile from '../Pile';
import Pool from '../Pool';
import Player from '../Player';

import autoBind from 'react-autobind';
import classNames from 'classnames/bind';
import store from 'store';
import styles from './Game.module.css';
import audio from '../audio';
import client from '../game_connection';

const c = classNames.bind(styles);
const myTurnSound = './boop.mp3';

const GameState = {
	WAITING: 0,
	PLAYING: 1,
	FINISHED: 2, // Generally this is when someone won
};

function isMyTurn(state) {
	return state && state.game && state.game.me && state.game.me.isMyTurn;
}

export default class Game extends React.Component {
	state = {
		game: null,
	};

	constructor(props) {
		super(props);
		autoBind(this);
	}

	getGameID() {
		return this.props.match.params.id;
	}

	componentDidMount() {
		client.setGameID(this.getGameID());
		client.connect();
		client.on('connect', this.onConnect);
		client.on('game_update', this.onGameUpdate);
		client.on('bad_play', error => alert(error));
	}

	componentWillUnmount() {
		client.disconnect();
	}

	componentDidUpdate(prevProps, prevState) {
		if(isMyTurn(this.state) && !isMyTurn(prevState)) {
			audio.play(myTurnSound);
		}
	}

	onConnect() {
		console.log('connected');
		this.identify();
	}

	storeKey() {
		return `game/${this.getGameID()}`;
	}

	storedData() {
		const key = this.storeKey();

		if(!store.get(key)) {
			store.set(key, {});
		}

		return store.get(this.storeKey());
	}

	store(key, value) {
		const data = this.storedData();
		data[key] = value;
		store.set(this.storeKey(), data);
	}

	identify() {
		const data = this.storedData();
		console.log('storedData', data);

		if('playerIdx' in data) {
			client.identifyAs(data.playerIdx);
		} else {
			const name = prompt('Player name:');

			client.requestNewIdentity(name).then(playerIdx => {
				this.store('playerIdx', playerIdx);
				this.identify();
			});
		}
	}

	onGameUpdate(game) {
		console.log('onGameUpdate', game);

		if(game.state === GameState.FINISHED) {
			console.log('game finished');
		}

		this.setState({ game });
	}

	render() {
		const game = this.state.game;

		if(!game) {
			return null;
		}

		const top =
			game.others.length >= 1
				?	(<div className={ c("player", "top") }>
						<Player player={ game.others[0] } />
					</div>)
				: null;

		const left =
			game.others.length >= 2
			?	(<div className={ c("player", "left") }>
					<Player player={ game.others[1] } />
				</div>)
			: null;

		const right =
			game.others.length >= 3
				?	(<div className={ c("player", "right") }>
						<Player player={ game.others[2] } />
					</div>)
				: null;

		return (
			<div className={ styles.game }>
				<div className={ c("player", "bottom") }>
					<Me me={ game.me } />
				</div>

				{ top }
				{ left }
				{ right }

				<div className={ styles.center }>
					<div className={ styles.pool }>
						<Pool poolSize={ game.poolSize } />
					</div>

					<div className={ styles.pile }>
						<Pile run={ game.run } />
					</div>

					<div className={ styles.stats }>
						<Stats poolSize={ game.poolSize } turn={ game.playerTurnName } />
					</div>
				</div>
			</div>
		);
	}
}
