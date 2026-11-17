extends TestCase
## Drawing the city: crossroads, streets and places (design doc §3).

const SEEDS_TO_CHECK := 300

var content: GameContent
var config: GameConfig


func before_each() -> void:
	content = GameContent.load_from()
	config = content.config


func _generate(seed: int) -> City:
	return City.generate(config, content.restaurant_ids(), GameRng.new(seed))


func _all_streets(city: City) -> int:
	return city.streets_of(City.Street.NORMAL).size() + city.streets_of(City.Street.PAVED).size() \
			+ city.streets_of(City.Street.WORKS).size()


func test_city_has_the_expected_size_and_base() -> void:
	var city := _generate(1)
	assert_eq([city.columns, city.rows], [7, 6])
	assert_eq(city.base, Vector2i(3, 3))
	assert_eq(city.place_at(Vector2i(3, 3)), City.Place.BASE)
	assert_eq(_all_streets(city), 71, "6 × 6 horizontal + 7 × 5 vertical segments")


func test_city_has_the_expected_places() -> void:
	var city := _generate(2)
	assert_eq(city.crossroads_with(City.Place.BASE).size(), 1, "base")
	assert_eq(city.crossroads_with(City.Place.RESTAURANT).size(), 3, "restaurants")
	assert_eq(city.crossroads_with(City.Place.CLIENT).size(), 12, "clients")
	assert_eq(city.crossroads_without_place().size(), 42 - 16, "empty crossroads")


func test_city_has_the_expected_streets() -> void:
	var city := _generate(3)
	assert_eq(city.streets_of(City.Street.WORKS).size(), 7, "road works")
	assert_eq(city.streets_of(City.Street.PAVED).size(), 6, "paved streets")
	assert_eq(city.streets_of(City.Street.NORMAL).size(), 71 - 13, "normal streets")


func test_clients_are_numbered_from_1_to_12() -> void:
	var city := _generate(4)
	var numbers: Array[int] = []
	for crossroads in city.crossroads_with(City.Place.CLIENT):
		numbers.append(city.client_number_at(crossroads))
	numbers.sort()
	assert_eq(numbers, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
	assert_eq(city.client_number_at(city.client_crossroads(7)), 7)
	assert_eq(city.client_crossroads(13), City.NOWHERE)


func test_restaurants_are_of_different_known_types() -> void:
	for seed in 20:
		var kinds := _generate(seed).restaurant_kinds()
		assert_eq(kinds.size(), 3)
		for kind in kinds:
			assert_true(content.restaurants.has(kind), "unknown kind %s" % kind)
			assert_eq(kinds.count(kind), 1, "kind %s twice (seed %d)" % [kind, seed])


func test_every_building_sits_in_a_block_touching_its_crossroads() -> void:
	var city := _generate(5)
	for place in [City.Place.BASE, City.Place.RESTAURANT, City.Place.CLIENT]:
		for crossroads in city.crossroads_with(place):
			var block := city.building_block(crossroads)
			assert_true(block in city.blocks_around(crossroads), "%s -> %s" % [crossroads, block])


func test_blocks_around_a_crossroads() -> void:
	var city := _generate(6)
	assert_eq(city.blocks_around(Vector2i(0, 0)), [Vector2i(0, 0)], "a corner touches one block")
	assert_eq(city.blocks_around(Vector2i(6, 5)), [Vector2i(5, 4)])
	assert_eq(city.blocks_around(Vector2i(3, 0)).size(), 2, "an edge touches two blocks")
	assert_eq(city.blocks_around(Vector2i(3, 3)).size(), 4)


func test_every_crossroads_is_reachable_from_the_base() -> void:
	for seed in SEEDS_TO_CHECK:
		var city := _generate(seed)
		if not city.is_fully_connected():
			fail("seed %d is not fully connected\n%s" % [seed, city.to_text()])
			return


func test_same_seed_gives_the_same_city() -> void:
	for seed in [0, 1, 42, 123456789]:
		assert_eq(_generate(seed).snapshot(), _generate(seed).snapshot(), "seed %d" % seed)


func test_different_seeds_give_different_cities() -> void:
	assert_ne(_generate(1).snapshot(), _generate(2).snapshot())


func test_sizes_and_counts_come_from_the_config() -> void:
	var custom := config.duplicate() as GameConfig
	custom.city_columns = 5
	custom.city_rows = 5
	custom.base_cell = Vector2i(2, 2)
	custom.client_count = 4
	custom.works_count = 2
	custom.paved_count = 10
	var city := City.generate(custom, content.restaurant_ids(), GameRng.new(5))
	assert_eq([city.columns, city.rows], [5, 5])
	assert_eq(city.crossroads_with(City.Place.CLIENT).size(), 4)
	assert_eq(city.streets_of(City.Street.WORKS).size(), 2)
	assert_eq(city.streets_of(City.Street.PAVED).size(), 10)


func test_detects_a_disconnected_city() -> void:
	var city := City.from_text(PackedStringArray([
		"B-+#C",
		"| | #",
		"+-+-+",
	]))
	assert_false(city.is_fully_connected(), "C is cut off")
	var connected := City.from_text(PackedStringArray([
		"B-+#C",
		"| | |",
		"+-+-+",
	]))
	assert_true(connected.is_fully_connected())


func test_text_round_trip() -> void:
	var drawing := PackedStringArray([
		"B-R~+",
		"| # ~",
		"C-+-+",
	])
	var city := City.from_text(drawing)
	assert_eq(city.to_text(), "\n".join(drawing))
	assert_eq(city.street_between(Vector2i(1, 0), Vector2i(2, 0)), City.Street.PAVED)
	assert_eq(city.street_between(Vector2i(1, 1), Vector2i(1, 0)), City.Street.WORKS, "order does not matter")
	assert_eq(city.place_at(Vector2i(0, 1)), City.Place.CLIENT)
