extends TestCase
## The sounds: every sound of the game has its file, and playing one never fails (in the
## tests nothing is heard).


func test_every_sound_has_a_file() -> void:
	for sound: int in Sfx.Sound.values():
		var path := Sfx.path_of(sound)
		assert_true(ResourceLoader.exists(path), "missing %s (run scripts/make_sounds.sh)" % path)
		assert_true(load(path) is AudioStream, "%s is a sound" % path)


func test_playing_a_sound_without_a_window_does_nothing() -> void:
	Sfx.play(Sfx.Sound.DELIVER, 0.1)
	assert_true(Sfx._voices.is_empty(), "no player created in the tests")
