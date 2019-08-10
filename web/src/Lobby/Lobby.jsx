import React from "react";
import autoBind from 'react-autobind';
import classNames from 'classnames/bind';
import styles from './Lobby.module.css';

const c = classNames.bind(styles);

function isDevelopment() {
	return !process.env.NODE_ENV || process.env.NODE_ENV === 'development';
}

export default class Lobby extends React.Component {
	state = {
		numPlayers: 4,
	};

	constructor() {
		super();
		autoBind(this);
	}

	onCreateGame() {
		const opts = {
			method: 'POST',
			body: JSON.stringify({ numPlayers: this.state.numPlayers }),
			headers: { 'Content-Type': 'application/json' },
		};

		fetch('//localhost:3012/create_game', opts)
			.then(res => res.text())
			.then(gameID => this.props.enterGame(parseInt(gameID, 10)));
	}

	changeNumPlayers({ target: { value: numPlayers } }) {
		this.setState({ numPlayers: parseInt(numPlayers, 10) });
	}

	render() {
		const readyButtonClasses = c({
			btn: true,
			ready: this.state.ready,
		});

		const numPlayers = [4, 3, 2];

		if(isDevelopment()) {
			numPlayers.push(1);
		}

		const numPlayersRadios = numPlayers.map(n => (
			<label key={ n }>
				<input
					type='radio'
					value={ n }
					checked={ this.state.numPlayers === n }
					onChange={ this.changeNumPlayers }
				/>

				{ n }
			</label>
		));

		return (
			<div className={ styles.lobby }>
				<div>
					<h1>How many players do you want?</h1>

					{ numPlayersRadios }
				</div>

				<div>
					<button onClick={ this.onCreateGame } className={ readyButtonClasses }>Create Game</button>
				</div>
			</div>
		);
	}
}
