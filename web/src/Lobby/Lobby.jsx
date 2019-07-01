import React from "react";
import autoBind from 'react-autobind';
import classNames from 'classnames/bind';
import styles from './Lobby.module.css';
import client from '../ws';

const c = classNames.bind(styles);

export default class Lobby extends React.Component {
	state = { ready: false, name: '' };

	constructor() {
		super();
		autoBind(this);
	}

	componentDidUpdate(_, prevState) {
		if(this.state.ready !== prevState.ready) {
			client.ready(this.state.ready, this.state.name);
		}
	}

	onReady() {
		this.setState({ ready: !this.state.ready });
	}

	changeName(evt) {
		const newName = evt.target.value;
		this.setState({ name: newName });
	}

	render() {
		const classes = c({ ready: this.state.ready });

		return (
			<div className={styles.lobby}>
				<div>
					Do not refresh the page without un-hitting ready
				</div>

				<div>
					<input type='text' placeholder='Enter your name' value={this.state.name} onChange={this.changeName} />
				</div>

				<div>
					<button onClick={this.onReady} className={classes}>Ready</button>
				</div>
			</div>
		);
	}
}