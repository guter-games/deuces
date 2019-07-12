import React from 'react';
import Card from '../Card';

const Pile = ({ run }) => {
	if(!run || run.length === 0) {
		return null;
	}

	const lastPlay = run[run.length - 1];

	const cards = lastPlay.map((c, i) => {
		return <Card key={i} suit={c.suit} rank={c.rank} static />;
	});

	return (
		<div>
			<div>Last played:</div>

			<div>{ cards }</div>
		</div>
	);
};

export default Pile;