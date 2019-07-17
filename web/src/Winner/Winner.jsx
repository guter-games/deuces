import React from 'react';
import styles from './Winner.module.css';

const Winner = ({ game }) => {
	return (
		<div className={styles.winner}>
			<div className={styles.inner}>
				<div>{ game.winner } has won the game!</div>

				<div>
					<a href='.'>
						<button>New Game</button>
					</a>
				</div>
			</div>
		</div>
	);
};

export default Winner;