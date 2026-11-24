extends TestCase
## The options and the helps already seen are kept in a file between two launches (Settings).

const TEST_PATH := "user://test_settings.cfg"


func before_each() -> void:
	Settings.reset()
	Settings._path = ""
	DirAccess.remove_absolute(TEST_PATH)


func test_without_a_file_nothing_is_written() -> void:
	Settings.volume = 0.3
	Settings.save()
	assert_false(FileAccess.file_exists(TEST_PATH))


func test_the_options_come_back_at_the_next_launch() -> void:
	Settings.use_file(TEST_PATH)
	Settings.volume = 0.3
	Settings.ui_size = Settings.UI_SIZES[2]
	Settings.fullscreen = true
	Settings.help_bubbles = false
	Settings.how_to_play_seen = true
	Settings.helps_seen["HELP_ACCEPT"] = true
	Settings.save()
	# Next launch: the values are read again from the file.
	Settings.reset()
	Settings._path = ""
	Settings.use_file(TEST_PATH)
	assert_eq(Settings.volume, 0.3)
	assert_eq(Settings.ui_size, Settings.UI_SIZES[2])
	assert_true(Settings.fullscreen)
	assert_false(Settings.help_bubbles)
	assert_true(Settings.how_to_play_seen)
	assert_eq(Settings.helps_seen.keys(), ["HELP_ACCEPT"])
	_forget()


func test_odd_values_are_ignored() -> void:
	var file := ConfigFile.new()
	file.set_value("sound", "volume", 7.0)
	file.set_value("display", "ui_size", 9.0)
	file.save(TEST_PATH)
	Settings.use_file(TEST_PATH)
	assert_eq(Settings.volume, 1.0, "at most 1")
	assert_eq(Settings.ui_size, 1.0, "a size the options do not offer")
	_forget()


## Back to memory only, as in the other tests.
func _forget() -> void:
	Settings.reset()
	Settings._path = ""
	DirAccess.remove_absolute(TEST_PATH)
