extends TestCase
## Moving through the city: one step per street segment, shortest paths, road works (design doc §3).


func _city(lines: Array) -> City:
	return City.from_text(PackedStringArray(lines))


func test_distance_on_an_open_grid() -> void:
	var city := _city([
		"B-+-+",
		"| | |",
		"+-+-+",
	])
	assert_eq(city.distance(city.base, Vector2i(2, 1)), 3)
	assert_eq(city.distance(city.base, city.base), 0)


func test_moves_follow_the_streets_only() -> void:
	var city := _city([
		"B-+",
		"| |",
		"+-+",
	])
	assert_eq(city.distance(Vector2i(0, 0), Vector2i(1, 1)), 2, "no diagonal step")
	assert_false(city.can_walk(Vector2i(0, 0), Vector2i(1, 1)))
	assert_false(city.can_walk(Vector2i(0, 0), Vector2i(2, 0)), "one segment per step")


func test_path_goes_around_road_works() -> void:
	var city := _city([
		"B#+",
		"| |",
		"+-+",
	])
	assert_eq(city.distance(city.base, Vector2i(1, 0)), 3)
	assert_eq(city.paths_from(city.base).path_to(Vector2i(1, 0)), [Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)])


func test_longer_detour_around_works() -> void:
	var city := _city([
		"B#+-+",
		"| # |",
		"+-+-+",
	])
	var path := city.paths_from(city.base).path_to(Vector2i(1, 0))
	assert_eq(path, [Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 0), Vector2i(1, 0)])


func test_path_excludes_the_start_and_ends_on_the_target() -> void:
	var city := _city([
		"B-+~+",
		"# | |",
		"C-R-+",
	])
	var target := Vector2i(0, 1)
	var paths := city.paths_from(city.base)
	var path := paths.path_to(target)
	assert_eq(path.size(), paths.distance_to(target))
	assert_ne(path[0], city.base)
	assert_eq(path[-1], target)
	var previous := city.base
	for crossroads in path:
		assert_true(city.can_walk(previous, crossroads), "%s -> %s" % [previous, crossroads])
		previous = crossroads


func test_paved_streets_and_places_can_be_walked_through() -> void:
	var city := _city(["B~R-C-+"])
	assert_eq(city.distance(city.base, Vector2i(3, 0)), 3)


func test_crossroads_behind_works_are_unreachable() -> void:
	var city := _city(["B#C"])
	var paths := city.paths_from(city.base)
	assert_eq(paths.distance_to(Vector2i(1, 0)), -1)
	assert_false(paths.is_reachable(Vector2i(1, 0)))
	assert_eq(paths.path_to(Vector2i(1, 0)), [])


func test_wrong_way_card_lets_the_courier_take_closed_streets() -> void:
	var city := _city(["B#C"])
	assert_eq(city.distance(city.base, Vector2i(1, 0), true), 1)
	assert_eq(city.paths_from(city.base, true).path_to(Vector2i(1, 0)), [Vector2i(1, 0)])


func test_path_to_the_start_is_empty() -> void:
	var city := _city(["B-+"])
	assert_eq(city.paths_from(city.base).path_to(city.base), [])


func test_crossroads_outside_the_city() -> void:
	var city := _city(["B-+"])
	var paths := city.paths_from(city.base)
	assert_eq(paths.distance_to(Vector2i(5, 0)), -1)
	assert_eq(paths.distance_to(Vector2i(-1, 0)), -1)
	assert_false(city.can_walk(Vector2i(0, 0), Vector2i(0, -1)))


func test_ties_are_broken_like_the_prototype() -> void:
	# The prototype explores right, left, down, up: the path to a diagonal crossroads goes right first.
	var city := _city([
		"B-+",
		"| |",
		"+-+",
	])
	assert_eq(city.paths_from(city.base).path_to(Vector2i(1, 1)), [Vector2i(1, 0), Vector2i(1, 1)])


func test_reachable_within_a_number_of_steps() -> void:
	var city := _city([
		"+-+#+",
		"| | |",
		"+-B-+",
	])
	var within_one := city.paths_from(city.base).reachable_within(1)
	within_one.sort()
	assert_eq(within_one, [Vector2i(0, 1), Vector2i(1, 0), Vector2i(2, 1)])
	assert_eq(city.paths_from(city.base).reachable_within(2).size(), 5, "every crossroads but the base")


func test_street_key_ignores_the_order_of_the_ends() -> void:
	assert_eq(City.street_key(Vector2i(2, 1), Vector2i(1, 1)), City.street_key(Vector2i(1, 1), Vector2i(2, 1)))
	assert_eq(City.street_ends(City.street_key(Vector2i(0, 3), Vector2i(0, 2))), [Vector2i(0, 2), Vector2i(0, 3)])


func test_manhattan_distance() -> void:
	assert_eq(City.manhattan(Vector2i(1, 2), Vector2i(4, 0)), 5)
