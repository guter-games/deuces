import React from "react";
import autoBind from 'react-autobind';
import classNames from 'classnames/bind';
import styles from './Lobby.module.css';
import LobbyConnection from '../sockets/lobby';

const c = classNames.bind(styles);

function isDevelopment() {
	return !process.env.NODE_ENV || process.env.NODE_ENV === 'development';
}

export default class Lobby extends React.Component {
	state = {
		numPlayers: 4,
	};

	client = new LobbyConnection();

	constructor() {
		super();
		autoBind(this);
	}

	componentDidMount() {
		this.client.connect();
	}

	componentWillUnmount() {
		this.client.disconnect();
	}

	onCreateGame() {
		this.client.createGame(this.state.numPlayers)
	}

	changeNumPlayers({ target: { value: numPlayers } }) {
		this.setState({ numPlayers });
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
