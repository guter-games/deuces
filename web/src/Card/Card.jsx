import React from "react";
import classNames from 'classnames/bind';
import styles from './Card.module.css';

const Card = props => {
	const c = classNames.bind(styles);
	const classes = c({ card: true, selected: props.selected });

	return (
		<div onClick={ props.onClick } className={classes}>
			{props.rank} of {props.suit}
		</div>
	);
};

export default Card;