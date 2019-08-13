import React from 'react';
import Lobby from '../Lobby';
import Game from '../Game';
import { BrowserRouter, Route, Switch } from 'react-router-dom';

export default function Deuces() {
	return (
		<BrowserRouter basename="/deuces">
			<Switch>
				<Route path="/:id" component={Game} />
				<Route component={Lobby} />
			</Switch>
		</BrowserRouter>
	);
};
