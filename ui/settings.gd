class_name Settings
extends RefCounted
## The player's options and what the game remembers between two launches (helps already seen).
##
## Kept in user://settings.cfg, a ConfigFile (an INI file: [section] then key=value). Static
## values rather than an autoload (a node Godot adds by itself at start), because autoloads do not
## exist when the tests run with --script.
##
## The values live in memory until use_file() is called: the main menu and the game screen call it
## when they enter the scene tree, so the tests (which never add them to the tree) never read nor
## write the player's file.

const DEFAULT_PATH := "user://settings.cfg"
## Sizes of the interface offered in the options (1 = the size chosen for the screen).
const UI_SIZES: Array[float] = [0.85, 1.0, 1.15, 1.3]
const DEFAULT_VOLUME := 0.8

## Volume of the sounds, 0 (off) to 1.
static var volume: float = DEFAULT_VOLUME
## Multiplies the size of the interface chosen for the screen (see Device.apply_scale()).
static var ui_size: float = 1.0
## Computers only: the game fills the screen.
static var fullscreen: bool = false
## Help bubbles pointing at what to use next.
static var help_bubbles: bool = true
## The pages of "how to play" were shown once (they open by themselves before the first run).
static var how_to_play_seen: bool = false
## Help bubbles already shown once (each shows by itself only the first time).
static var helps_seen: Dictionary[String, bool] = {}

## File the values are read from and written to ("" = memory only).
static var _path: String = ""


## Reads the options from this file (once) and writes them there from now on.
static func use_file(path: String = DEFAULT_PATH) -> void:
	if _path == path:
		return
	_path = path
	var file := ConfigFile.new()
	if file.load(path) != OK:
		return
	volume = clampf(file.get_value("sound", "volume", DEFAULT_VOLUME), 0.0, 1.0)
	ui_size = file.get_value("display", "ui_size", 1.0)
	if not UI_SIZES.has(ui_size):
		ui_size = 1.0
	fullscreen = file.get_value("display", "fullscreen", false)
	help_bubbles = file.get_value("help", "bubbles", true)
	how_to_play_seen = file.get_value("help", "how_to_play_seen", false)
	helps_seen.clear()
	for key: String in file.get_value("help", "seen", PackedStringArray()):
		helps_seen[key] = true


## Writes the options to the file given to use_file(), if any.
static func save() -> void:
	if _path == "":
		return
	var file := ConfigFile.new()
	file.set_value("sound", "volume", volume)
	file.set_value("display", "ui_size", ui_size)
	file.set_value("display", "fullscreen", fullscreen)
	file.set_value("help", "bubbles", help_bubbles)
	file.set_value("help", "how_to_play_seen", how_to_play_seen)
	file.set_value("help", "seen", PackedStringArray(helps_seen.keys()))
	file.save(_path)


## Back to the values of a first launch, in memory (the tests start from there).
static func reset() -> void:
	volume = DEFAULT_VOLUME
	ui_size = 1.0
	fullscreen = false
	help_bubbles = true
	how_to_play_seen = false
	helps_seen.clear()


## Applies the options to the window and the sound.
static func apply(window: Window) -> void:
	Device.apply_scale(window, ui_size)
	# Bus 0 is "Master": every sound goes through it. Its volume is in decibels.
	AudioServer.set_bus_mute(0, volume <= 0.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.001)))
	if can_go_fullscreen() and window == window.get_tree().root:
		var mode := Window.MODE_FULLSCREEN if fullscreen else Window.MODE_WINDOWED
		if window.mode != mode and not (mode == Window.MODE_WINDOWED and window.mode == Window.MODE_MAXIMIZED):
			window.mode = mode


## Only on a computer: a phone is always full screen.
static func can_go_fullscreen() -> bool:
	return not OS.has_feature("mobile") and DisplayServer.get_name() != "headless"
