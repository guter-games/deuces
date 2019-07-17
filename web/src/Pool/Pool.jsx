import React from 'react';
import Hand from '../Hand';

const Pool = ({ poolSize }) => {
	const cards = [];

	for(let i = 0; i < poolSize; i++) {
		cards.push({});
	}
	
	return (
		<div>
			<div>
				<Hand cards={ cards } layout="stacked" />
			</div>
			
			<div>Deck: { poolSize }cards</div>
		</div>
	);
};

export default Pool;