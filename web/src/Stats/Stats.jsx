import React from 'react';
import Pool from '../Pool';
import styles from './Stats.module.css';

const Stats = props => {
	return (
		<div>
			<div className={ styles.turn }>
				{ props.turn }'s turn
			</div>

			<div>
				<Pool poolSize={ props.poolSize } />
			</div>
		</div>
	);
};

export default Stats;