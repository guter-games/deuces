import React from "react";
import autoBind from 'react-autobind';
import classNames from 'classnames/bind';
import styles from './Lobby.module.css';
import client from '../ws';
import LobbyPlayer from '../LobbyPlayer';

const c = classNames.bind(styles);

export default class Lobby extends React.Component {
	state = {
		ready: false,
		start: false,
		name: '',
		lobby_players: [],
		wantsNPlayers: '4',
	};

	constructor() {
		super();
		autoBind(this);

		client.on('lobby_players', lobby_players => {
			console.log('lobby players', lobby_players);
			this.setState({ lobby_players });
		})
	}

	onReady() {
		client.ready(!this.state.ready);
		this.setState({ ready: !this.state.ready });
	}

	onStart() {
		client.start(!this.state.start);
		this.setState({ start: !this.state.start });
	}

	changeName(evt) {
		const newName = evt.target.value;
		this.setState({ name: newName });
		client.changeName(newName);
	}

	changeNPlayers(evt) {
		const n = evt.target.value;
		client.changeNPlayers(n);
		this.setState({ wantsNPlayers: n });
	}

	nPlayersReady() {
		return this.state.lobby_players.filter(player => player.ready).length;
	}

	render() {
		const inputClasses = c({ input: true });
		const readyButtonClasses = c({
			btn: true,
			ready: this.state.ready,
		});

		const players = this.state.lobby_players.length > 0
			? this.state.lobby_players.map(player => <LobbyPlayer player={player} />)
			: <div> No players online </div>;

		const numPlayersRadios = [4, 3, 2, 1].map(n => `${n}`).map(n => (
			<label key={ n }>
				<input
					type='radio'
					name='nPlayers'
					value={ n }
					checked={ this.state.wantsNPlayers === n }
					onChange={ this.changeNPlayers }
				/>

				{ n }
			</label>
		));

		return (
			<div className={styles.lobby}>
				<div>
					<input
						type='text'
						placeholder='Enter your name'
						value={this.state.name}
						onChange={this.changeName}
						className={inputClasses}
						autoFocus
					/>
				</div>


				<div>
					<h1> Lobby </h1>
					{players}
				</div>

				<div>
					<h1> How many players do you want? </h1>

					{ numPlayersRadios }
				</div>

				<div>
					<button onClick={this.onReady} className={readyButtonClasses}>Ready</button>
				</div>
			</div>
		);
	}
}
