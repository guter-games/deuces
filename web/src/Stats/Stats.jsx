import React from 'react';

const Stats = props => {
	return (
		<div>
			<div>
				player { props.turn }'s turn
			</div>

			<div>
				# cards in pile: { props.poolSize }
			</div>
		</div>
	);
};

export default Stats;