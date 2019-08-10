const fns = {};

// Returns a copy of the array without the element at the given index
fns.without = (arr, idx) => {
	return arr.filter((_, i) => i !== idx);
};

// Mutates the array, removing the element with the given value
fns.remove = (arr, element) => {
	const idx = arr.indexOf(element);
	arr.splice(idx, 1);
};

module.exports = fns;