const fns = {};

// Returns a copy of the array without the element at the given index
fns.without = (arr, idx) => {
	return arr.filter((_, i) => i !== idx);
};

// Performs the action "numTimes" times
fns.times = (numTimes, action) => {
	for(let i = 0; i < numTimes; i++) {
		action();
	}
};

// Mutates the array, removing the element with the given value
fns.remove = (arr, element) => {
	const idx = arr.indexOf(element);
	arr.splice(idx, 1);
};

// Returns whether or not the elements in the array are consecutive, ie 1,2,3,4,5
fns.isConsecutive = (arr) => {
	if(arr.length === 0) {
		return true;
	}

	let prev = arr[0];
	for(let i = 1; i < arr.length; i++) {
		if(arr[i] !== prev + 1) {
			return false;
		}
		prev = arr[i];
	}
	return true;
};

module.exports = fns;
