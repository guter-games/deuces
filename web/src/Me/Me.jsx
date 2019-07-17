import React from 'react';
import autoBind from 'react-autobind';
import classNames from 'classnames/bind';
import styles from '../Player/Player.module.css';
import Hand from '../Hand';
import client from '../ws';
import card_comparator from '../card_comparator';

const c = classNames.bind(styles);

export default class Me extends React.Component {
	state = { selected: {} };

	constructor(props) {
		super(props);
		autoBind(this);
	}

	isCardSelected(i) {
		return this.state.selected[i];
	}

	onClickCard(i) {
		this.setState(prevState => {
			prevState.selected[i] = !this.isCardSelected(i);
			return prevState;
		});
	}

	// Attempts to play the selected cards
	playCards() {
		const cards = this.props.me.cards.filter((c, i) => this.isCardSelected(i));
		client.playCards(cards);

		// Deselect cards
		this.setState({ selected: {} });
	}

	pass() {
		client.pass();
	}

	render() {
		// Render individual cards
		const cards = this.props.me.cards.map((c, i) => {
			return {
				key: i,
				suit: c.suit,
				rank: c.rank,
				selected: this.isCardSelected(i),
				onClick: () => this.onClickCard(i),
			};
		});

		cards.sort(card_comparator);

		// Render the play button if it's your turn
		let play = null;
		
		if(this.props.me.isMyTurn) {
			play = (
				<div>
					<button onClick={ this.playCards }>Play</button>
					<button onClick={ this.pass }>Pass</button>
				</div>
			);
		}

		// Highlight the card area if it's your turn
		let meClasses = c({ player: true, highlighted: this.props.me.isMyTurn });
	
		return (
			<div className={ meClasses }>
				<div className={ styles.name }>
					{ this.props.me.name } (you, { cards.length } cards)

					{ play }
				</div>
				
				<div className={ styles.cards }>
					<Hand cards={ cards } layout='flat' />
				</div>
			</div>
		);
	}
};
