import React from "react";
import autoBind from 'react-autobind';
import classNames from 'classnames/bind';
import styles from './Lobby.module.css';
import client from '../ws';

const c = classNames.bind(styles);

export default class Lobby extends React.Component {
	state = {
		ready: false,
		start: false,
		name: '',
		lobby_players: [],
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

	nPlayersReady() {
		return this.state.lobby_players.filter(player => player.ready).length;
	}

	render() {
		const inputClasses = c({ input: true });
		const readyButtonClasses = c({
			btn: true,
			ready: this.state.ready,
		});
		const startButtonClasses = c({
			btn: true,
			ready: this.state.start,
			hidden: !this.state.ready
		});

		const players = this.state.lobby_players.length > 0 ?
			this.state.lobby_players.map(player =>
			<div>
					{player.name}
					{player.id === client.id() && "(me)"} - {player.status}
					{player.ready && " - ready"}
					{player.start && " - start"} 
			</div>)
			: <div> No players online </div>

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
					<h1> Lobby test deploy </h1>
					{players}
				</div>

				<div>
					<button onClick={this.onReady} className={readyButtonClasses}>Ready</button>
					<button onClick={this.onStart} className={startButtonClasses}>Start with {this.nPlayersReady()} players.</button>
				</div>
			</div>
		);
	}
}
