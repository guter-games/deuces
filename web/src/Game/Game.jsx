import React from "react";
import Stats from '../Stats';
import Me from '../Me';
import Pile from '../Pile';
import Pool from '../Pool';
import Player from '../Player';

import classNames from 'classnames/bind';
import styles from './Game.module.css';
import audio from "../audio";

const c = classNames.bind(styles);
const myTurnSound = './boop.mp3';

export default class Game extends React.Component {
	componentDidUpdate(prevProps, prevState) {
		if(this.props.game.me.isMyTurn && !prevProps.game.me.isMyTurn) {
			audio.play(myTurnSound);
		}
	}

	render() {
		const game = this.props.game;

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
						<Pool poolSize={ game.pool.length } />
					</div>

					<div className={ styles.pile }>
						<Pile run={ game.run } />
					</div>

					<div className={ styles.stats }>
						<Stats poolSize={ game.pool.length } turn={ game.playerTurnName } />
					</div>
				</div>
			</div>
		);
	}
}
