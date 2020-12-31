import React from 'react';
import store from 'store';
import styles from './Winner.module.css';

const Winner = ({ winner, playAgainGameID, playerIdx }) => {
	function playAgain() {
		store.set(`game/${playAgainGameID}`, { playerIdx });
		window.location.href = './' + playAgainGameID;
	}

	return (
		<div className={styles.winner}>
			<div className={styles.inner}>
				<div>{ winner } has won the game!</div>

				<div>
					<a href='.'>
						<button>New Game</button>
					</a>
					<button onClick={playAgain}>Play Again</button>
				</div>
			</div>
		</div>
	);
};

export default Winner;
