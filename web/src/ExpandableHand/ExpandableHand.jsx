import React from 'react';
import classNames from 'classnames/bind';
import autoBind from 'react-autobind';
import onClickOutside from 'react-onclickoutside';
import styles from './ExpandableHand.module.css';
import Hand from '../Hand';

const c = classNames.bind(styles);

class ExpandableHand extends React.Component {
	state = {
		expanded: false,
	};

	constructor(props) {
		super(props);
		autoBind(this);
	}

	handleClickOutside(event) {
		this.setState({ expanded: false });
	}

	expandHand(event) {
		if(!this.state.expanded) {
			// Don't select the card when expanding the hand
			event.stopPropagation();
		}

		this.setState({ expanded: true });
	}

	render() {
		const handLayout = this.state.expanded ? 'flat' : 'stacked';
		const classes = c({ expanded: this.state.expanded });

		return (
			<div onClickCapture={ this.expandHand } className={ classes }>
				{ this.state.expanded && <button onClick={ this.handleClickOutside }>Close</button> }

				<Hand cards={ this.props.cards } layout={ handLayout } />
			</div>
		);
	}
};

export default ExpandableHand;
// export default onClickOutside(ExpandableHand);
