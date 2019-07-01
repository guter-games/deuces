import React from "react";
import classNames from 'classnames/bind';
import styles from './Card.module.css';

const c = classNames.bind(styles);

const Card = props => {
	const isBlankCard = !(props.rank && props.suit);
	
	// Compute styles
	const classes = c({ card: true, selected: props.selected, static: isBlankCard });

	const style = {
		marginLeft: props.left || 0,
	};

	// Get image asset URL
	const fileName =
		(props.rank && props.suit)
			? `${ props.rank }${ props.suit }`
			: 'BLUE_BACK';

	const src = `/cards/${ fileName }.svg`;

	return (
		<div onClick={ props.onClick && props.onClick } className={classes} style={style}>
			<img src={src} className={styles.img} />
		</div>
	);
};

export default Card;