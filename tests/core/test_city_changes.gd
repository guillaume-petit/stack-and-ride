extends TestCase
## Changes to the city during a run: the "works" event (§12) and the "new partner" reward (§8.5).


func _generated(seed: int) -> City:
	var content := GameContent.load_from()
	return City.generate(content.config, content.restaurant_ids(), GameRng.new(seed))


func test_relocated_works_stay_on_plain_roads_and_keep_the_city_connected() -> void:
	for seed in 50:
		var city := _generated(seed)
		var before := city.snapshot()
		var works_before := city.cells_of(City.Tile.WORKS)
		assert_true(city.relocate_works(GameRng.new(seed + 1000), 100), "seed %d" % seed)
		assert_eq(city.cells_of(City.Tile.WORKS).size(), works_before.size(), "same number of works")
		assert_true(city.is_fully_connected(), "seed %d\n%s" % [seed, city.to_text()])
		for index in before["tiles"].size():
			var cell := Vector2i(index % city.width, index / city.width)
			var old_tile: int = before["tiles"][index]
			var new_tile := city.tile_at(cell)
			if old_tile == City.Tile.ROAD or old_tile == City.Tile.WORKS:
				assert_true(new_tile == City.Tile.ROAD or new_tile == City.Tile.WORKS, "%s" % cell)
			else:
				assert_eq(new_tile, old_tile, "%s should not change" % cell)


func test_relocating_works_is_deterministic() -> void:
	var a := _generated(7)
	var b := _generated(7)
	a.relocate_works(GameRng.new(99), 100)
	b.relocate_works(GameRng.new(99), 100)
	assert_eq(a.snapshot(), b.snapshot())


func test_relocation_gives_up_and_keeps_the_city_when_impossible() -> void:
	# Wherever the works go, they cut the client off.
	var city := City.from_text(PackedStringArray(["B.#C"]))
	var before := city.snapshot()
	assert_false(city.relocate_works(GameRng.new(1), 20))
	assert_eq(city.snapshot(), before)


func test_new_restaurant_opens_on_a_plain_road() -> void:
	var city := City.from_text(PackedStringArray([
		"B~.",
		"~C~",
	]))
	var courier := Vector2i(0, 0)
	var cell := city.add_restaurant(&"pizza", GameRng.new(3), courier)
	assert_eq(cell, Vector2i(2, 0), "the only plain road")
	assert_eq(city.tile_at(cell), City.Tile.RESTAURANT)
	assert_eq(city.restaurant_kind_at(cell), &"pizza")


func test_new_restaurant_never_opens_under_the_courier() -> void:
	var city := City.from_text(PackedStringArray(["B.."]))
	for seed in 20:
		var copy := City.from_text(PackedStringArray(["B.."]))
		assert_eq(copy.add_restaurant(&"pizza", GameRng.new(seed), Vector2i(1, 0)), Vector2i(2, 0))
	assert_eq(city.restaurant_kind_at(Vector2i(1, 0)), &"")


func test_new_restaurant_needs_a_free_road() -> void:
	var city := City.from_text(PackedStringArray(["B~C"]))
	assert_eq(city.add_restaurant(&"pizza", GameRng.new(1), city.base), Vector2i(-1, -1))
	assert_eq(city.cells_of(City.Tile.RESTAURANT).size(), 0)
