class AudioPlayer {
	play(src) {
		const audio = new Audio(src);
		audio.play();
	}
}

export default new AudioPlayer();