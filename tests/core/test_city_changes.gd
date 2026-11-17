extends TestCase
## Changes to the city during a run: the "works" event (§12) and the "new partner" reward (§8.5).


func _generated(seed: int) -> City:
	var content := GameContent.load_from()
	return City.generate(content.config, content.restaurant_ids(), GameRng.new(seed))


func test_relocated_works_stay_on_normal_streets_and_keep_the_city_connected() -> void:
	for seed in 50:
		var city := _generated(seed)
		var before := city.snapshot()
		var paved := city.streets_of(City.Street.PAVED)
		var works_count := city.streets_of(City.Street.WORKS).size()
		assert_true(city.relocate_works(GameRng.new(seed + 1000), 100), "seed %d" % seed)
		assert_eq(city.streets_of(City.Street.WORKS).size(), works_count, "same number of works")
		assert_eq(city.streets_of(City.Street.PAVED), paved, "paved streets do not move")
		assert_true(city.is_fully_connected(), "seed %d\n%s" % [seed, city.to_text()])
		var after := city.snapshot()
		for key in ["places", "restaurants", "clients", "buildings"]:
			assert_eq(after[key], before[key], "%s should not change" % key)


func test_relocating_works_is_deterministic() -> void:
	var a := _generated(7)
	var b := _generated(7)
	a.relocate_works(GameRng.new(99), 100)
	b.relocate_works(GameRng.new(99), 100)
	assert_eq(a.snapshot(), b.snapshot())


func test_relocation_gives_up_and_keeps_the_city_when_impossible() -> void:
	# A single line of streets: wherever the works go, they cut the city in two.
	var city := City.from_text(PackedStringArray(["B-+#C"]))
	var before := city.snapshot()
	assert_false(city.relocate_works(GameRng.new(1), 20))
	assert_eq(city.snapshot(), before)


func test_new_restaurant_opens_on_a_free_crossroads() -> void:
	var city := City.from_text(PackedStringArray([
		"B-+-C",
		"| | |",
		"C-C-+",
	]))
	var courier := Vector2i(2, 1)
	var crossroads := city.add_restaurant(&"pizza", GameRng.new(3), courier)
	assert_eq(crossroads, Vector2i(1, 0), "the only free crossroads without the courier")
	assert_eq(city.place_at(crossroads), City.Place.RESTAURANT)
	assert_eq(city.restaurant_kind_at(crossroads), &"pizza")
	assert_true(city.building_block(crossroads) in city.blocks_around(crossroads))


func test_new_restaurant_never_opens_under_the_courier() -> void:
	for seed in 20:
		var city := City.from_text(PackedStringArray(["B-+-+"]))
		assert_ne(city.add_restaurant(&"pizza", GameRng.new(seed), Vector2i(1, 0)), Vector2i(1, 0))


func test_new_restaurant_needs_a_free_crossroads() -> void:
	var city := City.from_text(PackedStringArray(["B-C-R"]))
	assert_eq(city.add_restaurant(&"pizza", GameRng.new(1), city.base), City.NOWHERE)
	assert_eq(city.crossroads_with(City.Place.RESTAURANT).size(), 1)
