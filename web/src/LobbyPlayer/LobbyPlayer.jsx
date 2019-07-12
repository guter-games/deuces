import React from "react";
import client from '../ws';

const LobbyPlayer = ({ player }) => {
	return (
		<div>
			{player.name}
			{player.id === client.id() && "(me)"}
			- {player.status}
			- {player.wantNPlayers} player game
			{player.ready && " - ready"}
		</div>
	);
};

export default LobbyPlayer;
