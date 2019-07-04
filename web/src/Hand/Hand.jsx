import React from 'react';
import Card from '../Card';
import styles from './Hand.module.css';
import classNames from 'classnames/bind';

const c = classNames.bind(styles);

const stackedOffset = 2
const bunchedOffset = 20;

// layout is one of ["flat", "bunched", "stacked"]
const Hand = ({ cards, layout }) => {
	switch(layout) {
		case "bunched": {
			return renderBunched(cards);
		}

		case "stacked": {
			return renderStacked(cards);
		}

		default: {
			return renderFlat(cards);
		}
	}
};

function renderFlat(cards) {
	const handClasses = c({ hand: true, flat: true });

	const cardElems = cards.map((c, i) => {
		return <Card key={i} suit={c.suit} rank={c.rank} selected={c.selected} onClick={c.onClick} />;
	});

	return (
		<div className={ handClasses }>
			{cardElems}
		</div>
	);
}

function renderBunched(cards) {
	const handClasses = c({ hand: true, bunched: true });

	const cardElems = cards.map((c, i) => {
		const style = {
			left: `${i * bunchedOffset}px`,
		};

		return (
			<div className={ styles.card } style={ style }>
				<Card key={i} suit={c.suit} rank={c.rank} selected={c.selected} onClick={c.onClick} />
			</div>
		);
	});

	return (
		<div className={ handClasses }>
			{ cardElems }
		</div>
	);
}

function renderStacked(cards) {
	const handClasses = c({ hand: true, stacked: true });

	const cardElems = cards.map((c, i) => {
		const style = {
			left: `${i * stackedOffset}px`,
		};

		return (
			<div className={ styles.card } style={ style }>
				<Card key={i} suit={c.suit} rank={c.rank} selected={c.selected} onClick={c.onClick} />
			</div>
		);
	});

	return (
		<div className={handClasses}>
			{ cardElems }
		</div>
	);
}

export default Hand;