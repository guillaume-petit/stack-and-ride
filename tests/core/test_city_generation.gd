extends TestCase
## Drawing the city (design doc §3).

const SEEDS_TO_CHECK := 300

var content: GameContent
var config: GameConfig


func before_each() -> void:
	content = GameContent.load_from()
	config = content.config


func _generate(seed: int) -> City:
	return City.generate(config, content.restaurant_ids(), GameRng.new(seed))


func test_city_has_the_expected_size_and_base() -> void:
	var city := _generate(1)
	assert_eq([city.width, city.height], [8, 8])
	assert_eq(city.base, Vector2i(3, 4))
	assert_eq(city.tile_at(Vector2i(3, 4)), City.Tile.BASE)


func test_city_has_the_expected_content() -> void:
	var city := _generate(2)
	assert_eq(city.cells_of(City.Tile.BASE).size(), 1, "base")
	assert_eq(city.cells_of(City.Tile.RESTAURANT).size(), 3, "restaurants")
	assert_eq(city.cells_of(City.Tile.CLIENT).size(), 12, "clients")
	assert_eq(city.cells_of(City.Tile.WORKS).size(), 7, "road works")
	assert_eq(city.cells_of(City.Tile.PAVED).size(), 6, "paved streets")
	assert_eq(city.cells_of(City.Tile.ROAD).size(), 64 - 29, "plain roads")


func test_clients_are_numbered_from_1_to_12() -> void:
	var city := _generate(3)
	var numbers: Array[int] = []
	for cell in city.cells_of(City.Tile.CLIENT):
		numbers.append(city.client_number_at(cell))
	numbers.sort()
	assert_eq(numbers, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
	assert_eq(city.client_number_at(city.client_cell(7)), 7)
	assert_eq(city.client_cell(13), Vector2i(-1, -1))


func test_restaurants_are_of_different_known_types() -> void:
	for seed in 20:
		var kinds := _generate(seed).restaurant_kinds()
		assert_eq(kinds.size(), 3)
		for kind in kinds:
			assert_true(content.restaurants.has(kind), "unknown kind %s" % kind)
			assert_eq(kinds.count(kind), 1, "kind %s twice (seed %d)" % [kind, seed])


func test_every_cell_but_works_is_reachable_from_the_base() -> void:
	for seed in SEEDS_TO_CHECK:
		var city := _generate(seed)
		var paths := city.paths_from(city.base)
		for y in city.height:
			for x in city.width:
				var cell := Vector2i(x, y)
				if city.tile_at(cell) != City.Tile.WORKS and not paths.is_reachable(cell):
					fail("seed %d: %s unreachable\n%s" % [seed, cell, city.to_text()])
					return


func test_same_seed_gives_the_same_city() -> void:
	for seed in [0, 1, 42, 123456789]:
		assert_eq(_generate(seed).snapshot(), _generate(seed).snapshot(), "seed %d" % seed)


func test_different_seeds_give_different_cities() -> void:
	assert_ne(_generate(1).snapshot(), _generate(2).snapshot())


func test_works_and_paved_counts_come_from_the_config() -> void:
	var custom := config.duplicate() as GameConfig
	custom.works_count = 2
	custom.paved_count = 10
	var city := City.generate(custom, content.restaurant_ids(), GameRng.new(5))
	assert_eq(city.cells_of(City.Tile.WORKS).size(), 2)
	assert_eq(city.cells_of(City.Tile.PAVED).size(), 10)


func test_detects_a_disconnected_city() -> void:
	var city := City.from_text(PackedStringArray([
		"B.#C",
		"..#.",
		"####",
	]))
	assert_false(city.is_fully_connected())
	var connected := City.from_text(PackedStringArray([
		"B.#C",
		"....",
	]))
	assert_true(connected.is_fully_connected())


func test_text_round_trip() -> void:
	var drawing := PackedStringArray(["B.R", "~#C"])
	assert_eq(City.from_text(drawing).to_text(), "\n".join(drawing))
