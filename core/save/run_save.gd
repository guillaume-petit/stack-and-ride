class_name RunSave
extends RefCounted
## Saves a run in progress, and loads it back.
##
## A save holds only the seed of the run and the list of the player's actions (state.actions):
## the rules use a single seeded GameRng, so playing the same actions again on the same seed
## gives back exactly the same run. (In Java terms: event sourcing, the state is rebuilt from the
## events.) This keeps the file small and means nothing has to be written for each class of the
## state; the cost is that loading replays the whole run, a few milliseconds.
##
## When the rules or the data change between two versions of the game, the same actions may no
## longer give the same run: an action is then refused, or the counters at the end do not match
## the ones saved with it (check). Such a save is rejected (load_game() returns null) rather than
## giving a different run.

## Version of the file layout; a file with another version is rejected.
const FORMAT := 1
## Where the game keeps the run in progress. user:// is the data folder of the game
## (on Windows %APPDATA%\Godot\app_userdata\Stack & Ride, on Android the private storage of the app).
const DEFAULT_PATH := "user://run.json"

## Where the game keeps the runs that are over, for the reports of the runs played by people
## (scripts/run_playtests.sh).
const ARCHIVE_FOLDER := "user://runs"

## The argument each action takes, to reject a damaged file before playing it.
const ARGUMENTS: Dictionary[String, int] = {
	"choose_profile": TYPE_STRING,
	"accept_offer": TYPE_INT,
	"play_card": TYPE_INT,
	"move_to": TYPE_ARRAY,
	"take_dish": TYPE_INT,
	"drop_held": TYPE_INT,
	"rotate_held": TYPE_NIL,
	"lift": TYPE_INT,
	"set_held_aside": TYPE_NIL,
	"take_from_aside": TYPE_INT,
	"cancel_held": TYPE_NIL,
	"end_turn": TYPE_NIL,
	"choose_reward": TYPE_INT,
	"buy": TYPE_INT,
	"start_next_night": TYPE_NIL,
}


## What is saved: the seed, the actions, and counters to check the run once played again.
static func to_data(game: Game) -> Dictionary:
	return {
		"format": FORMAT,
		"seed": game.state.rng.seed_value,
		"actions": game.state.actions.duplicate(true),
		"check": _check(game.state),
	}


## Plays the saved run again. Returns null if the data is damaged or no longer gives the same run.
static func from_data(content: GameContent, data: Dictionary) -> Game:
	data = whole_numbers(data)
	if not data.get("format") is int or data["format"] != FORMAT or not data.get("seed") is int or not data.get("actions") is Array \
			or not data.get("check") is Dictionary:
		return null
	var game := Game.new_run(content, data["seed"])
	if game == null:
		return null
	for entry: Variant in data["actions"]:
		if not _valid(entry):
			return null
		var expected: String = entry[2] if entry.size() > 2 else "NONE"
		if Game.Problem.keys()[_play(game, entry[0], entry[1])] != expected:
			return null
	if _check(game.state) != data["check"]:
		return null
	return game


## Writes the run to a file. Returns false if it could not be written.
static func save_game(game: Game, path: String = DEFAULT_PATH) -> bool:
	# Written next to it first, then renamed: a game killed while writing keeps the previous save.
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_data(game)))
	file.close()
	return DirAccess.rename_absolute(temporary, path) == OK


## The run saved in this file, or null if there is none or it cannot be played again.
static func load_game(content: GameContent, path: String = DEFAULT_PATH) -> Game:
	var data := read_json(path)
	return from_data(content, data) if not data.is_empty() else null


## Keeps a run that is over (or given up) in this folder, in a new file named after the date and
## the seed: its actions (to play it again with the same rules), the numbers of the reports
## (RunSummary: still readable when the rules change) and the version of the game. Returns the path
## of the file, or "" if it could not be written.
static func archive(game: Game, folder: String = ARCHIVE_FOLDER) -> String:
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		return ""
	var data := to_data(game)
	data["summary"] = RunSummary.of(game.state)
	data["version"] = ProjectSettings.get_setting("application/config/version", "?")
	data["date"] = Time.get_datetime_string_from_system()
	var name := "%s_%d.json" % [String(data["date"]).replace(":", "-").replace("T", "_"), data["seed"]]
	var path := folder.path_join(name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return path


## Reads a JSON file: its Dictionary, or {} if it is missing or damaged.
static func read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	# JSON.parse_string() would report a damaged file as an engine error; parse() only returns it.
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not json.data is Dictionary:
		return {}
	return whole_numbers(json.data)


static func has_save(path: String = DEFAULT_PATH) -> bool:
	return FileAccess.file_exists(path)


static func erase(path: String = DEFAULT_PATH) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


static func _play(game: Game, action: String, argument: Variant) -> Game.Problem:
	match action:
		"choose_profile":
			return game.choose_profile(StringName(argument))
		"accept_offer":
			return game.accept_offer(argument)
		"play_card":
			return game.play_card(argument)
		"move_to":
			return game.move_to(Vector2i(argument[0], argument[1]))
		"take_dish":
			return game.take_dish(argument)
		"drop_held":
			return game.drop_held(argument)
		"rotate_held":
			return game.rotate_held()
		"lift":
			return game.lift(argument)
		"set_held_aside":
			return game.set_held_aside()
		"take_from_aside":
			return game.take_from_aside(argument)
		"cancel_held":
			return game.cancel_held()
		"end_turn":
			return game.end_turn()
		"choose_reward":
			return game.choose_reward(argument)
		"buy":
			return game.buy(argument)
		"start_next_night":
			return game.start_next_night()
	return Game.Problem.WRONG_PHASE


## An entry is [name, argument] or [name, argument, problem], with the argument its action takes.
static func _valid(entry: Variant) -> bool:
	if not entry is Array or entry.size() < 2 or entry.size() > 3 or not entry[0] is String:
		return false
	if not ARGUMENTS.has(entry[0]) or typeof(entry[1]) != ARGUMENTS[entry[0]]:
		return false
	if entry.size() == 3 and not (entry[2] is String and Game.Problem.keys().has(entry[2])):
		return false
	if entry[0] == "move_to":
		var target: Array = entry[1]
		return target.size() == 2 and target[0] is int and target[1] is int
	return true


## The counters compared after playing the run again.
static func _check(state: GameState) -> Dictionary:
	return {
		"phase": GameState.Phase.keys()[state.phase],
		"night": state.night,
		"turn": state.turn,
		"wallet": state.wallet,
		"rating": state.rating_tenths,
		"acceptance": state.acceptance,
		"actions": state.actions.size(),
	}


## JSON has only one kind of number: it reads 3 as 3.0. Whole numbers become ints again.
static func whole_numbers(value: Variant) -> Variant:
	if value is float and value == floorf(value):
		return int(value)
	if value is Array:
		var out: Array = []
		for item: Variant in value:
			out.append(whole_numbers(item))
		return out
	if value is Dictionary:
		var out := {}
		for key: Variant in value:
			out[key] = whole_numbers(value[key])
		return out
	return value
