class_name Sfx
extends RefCounted
## The sounds of the game. Sfx.play(Sfx.Sound.DELIVER) plays one, from anywhere.
##
## Each sound is assets/sounds/<name>.wav (provisional sounds made by scripts/make_sounds.gd: replace
## a file to change a sound). The players are created on the first sound, in a node added to the
## root of the scene tree, so that a sound goes on when the screen changes.
##
## Godot plays a sound with an AudioStreamPlayer node; several of them let sounds overlap.

enum Sound { CLICK, CARD, PEDAL, TAKE, DROP, DELIVER, BAD, SHAKE, REFUSE, BUY, NIGHT_END, WIN, LOSE }

const FOLDER := "res://assets/sounds/"
## How many sounds can play at once.
const VOICES := 8

## Off: nothing plays (an option will set it, iteration 6).
static var enabled: bool = true

static var _voices: Array[AudioStreamPlayer] = []
static var _next_voice: int = 0
static var _streams: Dictionary[Sound, AudioStream] = {}


static func path_of(sound: Sound) -> String:
	return FOLDER + String(Sound.keys()[sound]).to_lower() + ".wav"


## Plays a sound. pitch_spread: random change of pitch (0.1 = up to 10 % higher or lower), so that
## a sound repeated quickly (the pedals) does not sound mechanical.
static func play(sound: Sound, pitch_spread: float = 0.0) -> void:
	# No sound in the tests (they run without a window) nor when it is turned off.
	if not enabled or DisplayServer.get_name() == "headless":
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if _voices.is_empty():
		_make_voices(tree)
	var stream := _stream(sound)
	if stream == null:
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
	# The voices join the tree at the end of the frame (a scene may be busy adding its children).
	voice.play.call_deferred()


static func _make_voices(tree: SceneTree) -> void:
	var holder := Node.new()
	holder.name = "Sfx"
	# Sounds keep playing while the game is paused.
	holder.process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		holder.add_child(voice)
		_voices.append(voice)
	tree.root.add_child.call_deferred(holder)


static func _stream(sound: Sound) -> AudioStream:
	if not _streams.has(sound):
		var path := path_of(sound)
		_streams[sound] = load(path) as AudioStream if ResourceLoader.exists(path) else null
	return _streams[sound]
