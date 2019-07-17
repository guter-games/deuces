import React from 'react';
import Hand from '../Hand';
import card_comparator from '../card_comparator';

const Pile = ({ run }) => {
	if(!run || run.length === 0) {
		return null;
	}

	const lastPlay = run[run.length - 1];
	lastPlay.sort(card_comparator);

	return (
		<div>
			<div>Last played:</div>

			<Hand cards={ lastPlay } layout='flat' />
		</div>
	);
};

export default Pile;