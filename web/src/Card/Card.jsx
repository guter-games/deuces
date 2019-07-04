import React from "react";
import classNames from 'classnames/bind';
import styles from './Card.module.css';

const c = classNames.bind(styles);

const Card = props => {
	const isBlankCard = !(props.rank && props.suit);
	
	// Compute styles
	const classes = c({ card: true, selected: props.selected, static: isBlankCard });

	const style = {
		left: props.left || 0,
	};

	// Get image asset URL
	const fileName =
		isBlankCard
			? 'BLUE_BACK'
			: `${ props.rank }${ props.suit }`;

	const src = `/cards/${ fileName }.svg`;

	return (
		<div onClick={ props.onClick && props.onClick } className={classes} style={style}>
			<img src={src} className={styles.img} />
		</div>
	);
};

export default Card;