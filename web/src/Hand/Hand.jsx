import React from 'react';
import Card from '../Card';
import styles from './Hand.module.css';
import classNames from 'classnames/bind';

const c = classNames.bind(styles);

const stackedOffset = 2
const bunchedOffset = 20;

// layout is one of ["flat", "bunched", "stacked"]
const Hand = ({ cards, layout }) => {
	const sortedCards = [...cards]
	sort(sortedCards);

	switch(layout) {
		case "bunched": {
			return renderBunched(sortedCards);
		}

		case "stacked": {
			return renderStacked(sortedCards);
		}

		default: {
			return renderFlat(sortedCards);
		}
	}
};

function sort(cards) {
	const rankOrder = ["3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A", "2"];
	const suitOrder = ["D", "C", "H", "S"];
	const compare = (a, b) =>
		(suitOrder.indexOf(a.suit) - suitOrder.indexOf(b.suit)) * 100 +
		(rankOrder.indexOf(a.rank) - rankOrder.indexOf(b.rank))

	cards.sort(compare);
}

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