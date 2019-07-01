import React from 'react';
import Card from '../Card';

const foldAmount = -69;

const Pool = ({ poolSize }) => {
	const cards = [];

	for(let i = 0; i < poolSize; i++) {
		const left = foldAmount * i;

		cards.push((
			<Card key={i} left={left} />
		));
	}
	
	return (
		<div>
			<div>{ cards }</div>
			<div>Deck: { poolSize }cards</div>
		</div>
	);
};

export default Pool;