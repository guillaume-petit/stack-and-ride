class_name GameRng
extends RefCounted
## Deterministic random source for all game rules.
##
## Every random decision in the core (city layout, offers, card draws, events)
## must go through a GameRng so that a run can be replayed from its seed.
## Never call the global randi()/randf() from core code.

var seed_value: int:
	get:
		return _seed

var _seed: int
var _rng := RandomNumberGenerator.new()


func _init(p_seed: int = 0) -> void:
	_seed = p_seed
	_rng.seed = p_seed


## Integer in [from, to], both ends included.
func range_int(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


## Float in [0, 1).
func next_float() -> float:
	return _rng.randf()


## True with probability p (0 = never, 1 = always).
func chance(p: float) -> bool:
	return _rng.randf() < p


## Random element of the array, or null if it is empty.
func pick(items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[_rng.randi_range(0, items.size() - 1)]


## Shuffles the array in place (Fisher-Yates) and returns it.
func shuffle(items: Array) -> Array:
	for i in range(items.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp: Variant = items[i]
		items[i] = items[j]
		items[j] = tmp
	return items


## Internal state, to save a run in progress.
func get_state() -> int:
	return _rng.state


## Restores a state previously returned by get_state().
func set_state(state: int) -> void:
	_rng.state = state
