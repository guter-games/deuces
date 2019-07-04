import React from 'react';
import autoBind from 'react-autobind';
import styles from '../Player/Player.module.css';
import Hand from '../Hand';
import client from '../ws';

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
	
		return (
			<div>
				<div className={ styles.name }>
					{ this.props.me.name } (you, { cards.length } cards)
				</div>
				
				<div className={ styles.cards }>
					<Hand cards={ cards } layout="flat" />
				</div>

				{ play }
			</div>
		);
	}
};
