import React from 'react';
import Hand from '../Hand';

const foldAmount = 0;

const Pool = ({ poolSize }) => {
	const cards = [];

	for(let i = 0; i < poolSize; i++) {
		cards.push({});
	}
	
	return (
		<div>
			<div>
				<Hand cards={ cards } layout="bunched" />
			</div>
			
			<div>Deck: { poolSize }cards</div>
		</div>
	);
};

export default Pool;