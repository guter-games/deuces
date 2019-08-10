import React from "react";
import Stats from '../Stats';
import Me from '../Me';
import Pile from '../Pile';
import Pool from '../Pool';
import Player from '../Player';

import autoBind from 'react-autobind';
import classNames from 'classnames/bind';
import styles from './Game.module.css';
import audio from '../audio';
import GameConnection from '../game_connection';

const c = classNames.bind(styles);
const myTurnSound = './boop.mp3';

const GameState = {
	WAITING: 0,
	PLAYING: 1,
	FINISHED: 2, // Generally this is when someone won
};

const testGame = `{"others":[],"state":0,"turn":0,"pool":[{"suit":"D","rank":"3"},{"suit":"D","rank":"5"},{"suit":"D","rank":"6"},{"suit":"D","rank":"7"},{"suit":"D","rank":"8"},{"suit":"D","rank":"J"},{"suit":"C","rank":"3"},{"suit":"C","rank":"4"},{"suit":"C","rank":"5"},{"suit":"C","rank":"7"},{"suit":"C","rank":"8"},{"suit":"C","rank":"9"},{"suit":"C","rank":"10"},{"suit":"C","rank":"Q"},{"suit":"C","rank":"A"},{"suit":"C","rank":"2"},{"suit":"H","rank":"3"},{"suit":"H","rank":"6"},{"suit":"H","rank":"7"},{"suit":"H","rank":"9"},{"suit":"H","rank":"10"},{"suit":"H","rank":"J"},{"suit":"H","rank":"Q"},{"suit":"H","rank":"K"},{"suit":"H","rank":"A"},{"suit":"S","rank":"3"},{"suit":"S","rank":"4"},{"suit":"S","rank":"5"},{"suit":"S","rank":"7"},{"suit":"S","rank":"9"},{"suit":"S","rank":"10"},{"suit":"S","rank":"J"},{"suit":"S","rank":"K"},{"suit":"S","rank":"A"},{"suit":"S","rank":"2"}],"me":{"name":true,"ready":"we","cards":[{"suit":"D","rank":"2"},{"suit":"H","rank":"8"},{"suit":"D","rank":"9"},{"suit":"D","rank":"Q"},{"suit":"C","rank":"K"},{"suit":"H","rank":"5"},{"suit":"C","rank":"J"},{"suit":"S","rank":"6"},{"suit":"H","rank":"2"},{"suit":"C","rank":"6"},{"suit":"D","rank":"10"},{"suit":"S","rank":"8"},{"suit":"D","rank":"K"},{"suit":"H","rank":"4"},{"suit":"S","rank":"Q"},{"suit":"D","rank":"A"},{"suit":"D","rank":"4"}]}}`;

export default class Game extends React.Component {
	client = new GameConnection(this.props.id);

	state = {
		game: null,
	};

	constructor(props) {
		super(props);
		autoBind(this);
	}

	componentDidMount() {
		this.client.connect();
		this.client.on('connect', this.onConnect);
		this.client.on('game_update', this.onGameUpdate);
	}

	componentWillUnmount() {
		this.client.disconnect();
	}

	componentDidUpdate(prevProps, prevState) {
		if(this.state.game.me.isMyTurn && !prevState.game.me.isMyTurn) {
			audio.play(myTurnSound);
		}
	}

	onConnect() {
		this.client.identifyAs(0);
	}

	onGameUpdate(game) {
		console.log('onGameUpdate', game);
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
