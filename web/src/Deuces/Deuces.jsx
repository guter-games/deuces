import React from 'react';
import Lobby from '../Lobby';
import Game from '../Game';
import { BrowserRouter as Router, Route, Switch } from 'react-router-dom';

export default function Deuces() {
	return (
		<Router>
			<Switch>
				<Route path="/:id" component={Game} />
				<Route component={Lobby} />
			</Switch>
		</Router>
	);
};
