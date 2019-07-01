import React from 'react';
import Card from '../Card';
import styles from './Player.module.css';

const foldAmount = -40; // Amount to stack cards on top of each other

const Player = ({ player }) => {
	const cards = [];

	for(let i = 0; i < player.numCards; i++) {
		const left = foldAmount * i;

		cards.push((
			<Card key={i} left={left} />
		));
	}

	return (
		<div>
			<div className={styles.name}>
				{ player.name } ({ player.numCards } cards)
			</div>

			<div className={styles.cards}>
				{ cards }
			</div>
		</div>
	);
};

export default Player;