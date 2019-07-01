import React from "react";
import Stats from '../Stats';
import Me from '../Me';
import Pile from '../Pile';
import Pool from '../Pool';

import styles from './Game.module.css';

export default class Game extends React.Component {
	render() {
		const game = this.props.game;

		return (
			<div className={styles.game}>
				<div className={styles.stats}>
					<Stats poolSize={ game.pool.length } turn={ game.playerTurnName } />
				</div>

				<div>
					<Pool poolSize={ game.pool.length } />
				</div>

				<div>
					<Pile run={ game.run } />
				</div>

				<div>
					<Me me={ game.me } />
				</div>
			</div>
		);
	}
}