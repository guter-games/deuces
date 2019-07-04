import React from 'react';
import Hand from '../Hand';
import styles from './Player.module.css';

const Player = ({ player }) => {
	const cards = [];

	for(let i = 0; i < player.numCards; i++) {
		cards.push({});
	}

	return (
		<div>
			<div className={ styles.name }>
				{ player.name } ({ player.numCards } cards)
			</div>

			<div className={ styles.cards }>
				<Hand cards={ cards } layout="bunched" />
			</div>
		</div>
	);
};

export default Player;