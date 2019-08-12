class AudioPlayer {
	play(src) {
		const audio = new Audio(src);
		audio.play().catch(console.error); // Can throw errors if permissions are denied (i.e. on mobile)
	}
}

export default new AudioPlayer();