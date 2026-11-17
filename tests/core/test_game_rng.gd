extends TestCase


func _sequence(rng: GameRng, count: int) -> Array:
	var out := []
	for _i in count:
		out.append(rng.range_int(0, 1000))
	return out


func test_same_seed_gives_same_sequence() -> void:
	assert_eq(_sequence(GameRng.new(42), 20), _sequence(GameRng.new(42), 20))


func test_different_seeds_give_different_sequences() -> void:
	assert_ne(_sequence(GameRng.new(1), 20), _sequence(GameRng.new(2), 20))


func test_range_int_stays_in_bounds() -> void:
	var rng := GameRng.new(7)
	for _i in 500:
		var v := rng.range_int(3, 5)
		assert_true(v >= 3 and v <= 5, "value %d out of [3, 5]" % v)


func test_shuffle_keeps_every_element() -> void:
	var items := [1, 2, 3, 4, 5, 6, 7, 8]
	var shuffled := GameRng.new(3).shuffle(items.duplicate())
	shuffled.sort()
	assert_eq(shuffled, items)


func test_shuffle_is_deterministic() -> void:
	var a := GameRng.new(9).shuffle([1, 2, 3, 4, 5, 6, 7, 8])
	var b := GameRng.new(9).shuffle([1, 2, 3, 4, 5, 6, 7, 8])
	assert_eq(a, b)


func test_pick_on_empty_array_returns_null() -> void:
	assert_null(GameRng.new(1).pick([]))


func test_restoring_state_replays_the_same_values() -> void:
	var rng := GameRng.new(123)
	_sequence(rng, 5)
	var saved := rng.get_state()
	var first := _sequence(rng, 10)
	rng.set_state(saved)
	assert_eq(_sequence(rng, 10), first)


func test_seed_value_is_exposed() -> void:
	assert_eq(GameRng.new(55).seed_value, 55)
