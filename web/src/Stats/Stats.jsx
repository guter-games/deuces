import React from 'react';

const Stats = props => {
	return (
		<div>
			<div>
				{ props.turn }'s turn
			</div>

			<div>
				# cards in pool: { props.poolSize }
			</div>
		</div>
	);
};

export default Stats;