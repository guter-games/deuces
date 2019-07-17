import React from 'react';
import Card from '../Card';
import styles from './Hand.module.css';
import classNames from 'classnames/bind';

const c = classNames.bind(styles);

const stackedOffset = 2
const bunchedOffset = 20;
const cardWidth = 70;

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
			{ cardElems }
		</div>
	);
}

function renderBunched(cards) {
	const handWidth = (cards.length - 1) * bunchedOffset + cardWidth;

	const handClasses = c({ hand: true, bunched: true });
	const handStyle = {
		width: `${handWidth}px`,
	};

	const cardElems = cards.map((c, i) => {
		const style = {
			left: `${i * bunchedOffset}px`,
		};

		return (
			<div key={i} className={ styles.card } style={ style }>
				<Card suit={c.suit} rank={c.rank} selected={c.selected} onClick={c.onClick} />
			</div>
		);
	});

	return (
		<div className={ handClasses } style={ handStyle }>
			{ cardElems }
		</div>
	);
}

function renderStacked(cards) {
	const handWidth = (cards.length - 1) * stackedOffset + cardWidth;
	
	const handClasses = c({ hand: true, stacked: true });
	const handStyle = {
		width: `${handWidth}px`,
	};

	const cardElems = cards.map((c, i) => {
		const style = {
			left: `${i * stackedOffset}px`,
		};

		return (
			<div key={i} className={ styles.card } style={ style }>
				<Card suit={c.suit} rank={c.rank} selected={c.selected} onClick={c.onClick} />
			</div>
		);
	});

	return (
		<div className={ handClasses } style={ handStyle }>
			{ cardElems }
		</div>
	);
}

export default Hand;