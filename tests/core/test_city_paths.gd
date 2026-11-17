extends TestCase
## Moving through the city: orthogonal steps, shortest paths, road works (design doc §3).


func _city(lines: Array) -> City:
	return City.from_text(PackedStringArray(lines))


func test_distance_on_an_open_grid() -> void:
	var city := _city([
		"B....",
		".....",
		".....",
	])
	assert_eq(city.distance(city.base, Vector2i(4, 2)), 6)
	assert_eq(city.distance(city.base, city.base), 0)


func test_moves_are_orthogonal_only() -> void:
	var city := _city(["B.", ".."])
	assert_eq(city.distance(Vector2i(0, 0), Vector2i(1, 1)), 2, "no diagonal step")


func test_path_goes_around_road_works() -> void:
	var city := _city([
		"B#.",
		".#.",
		"...",
	])
	assert_eq(city.distance(city.base, Vector2i(2, 0)), 6)
	var path := city.paths_from(city.base).path_to(Vector2i(2, 0))
	assert_eq(path, [Vector2i(0, 1), Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2), Vector2i(2, 1), Vector2i(2, 0)])


func test_path_excludes_the_start_and_ends_on_the_target() -> void:
	var city := _city([
		"B...",
		"#~#.",
		"C.R.",
	])
	var target := Vector2i(0, 2)
	var paths := city.paths_from(city.base)
	var path := paths.path_to(target)
	assert_eq(path.size(), paths.distance_to(target))
	assert_ne(path[0], city.base)
	assert_eq(path[-1], target)
	var previous := city.base
	for cell in path:
		assert_eq(City.manhattan(previous, cell), 1, "%s -> %s is not one step" % [previous, cell])
		assert_true(city.is_passable(cell), "%s is not passable" % cell)
		previous = cell


func test_paved_streets_restaurants_and_clients_are_passable() -> void:
	var city := _city(["B~RC."])
	assert_eq(city.distance(city.base, Vector2i(4, 0)), 4)


func test_cells_behind_works_are_unreachable() -> void:
	var city := _city(["B#C"])
	var paths := city.paths_from(city.base)
	assert_eq(paths.distance_to(Vector2i(2, 0)), -1)
	assert_false(paths.is_reachable(Vector2i(2, 0)))
	assert_eq(paths.path_to(Vector2i(2, 0)), [])
	assert_false(paths.is_reachable(Vector2i(1, 0)), "road works themselves are not reachable")


func test_wrong_way_card_lets_the_courier_cross_works() -> void:
	var city := _city(["B#C"])
	assert_eq(city.distance(city.base, Vector2i(2, 0), true), 2)
	assert_eq(city.paths_from(city.base, true).path_to(Vector2i(2, 0)), [Vector2i(1, 0), Vector2i(2, 0)])


func test_path_to_the_start_is_empty() -> void:
	var city := _city(["B."])
	assert_eq(city.paths_from(city.base).path_to(city.base), [])


func test_cells_outside_the_city() -> void:
	var city := _city(["B."])
	var paths := city.paths_from(city.base)
	assert_eq(paths.distance_to(Vector2i(5, 0)), -1)
	assert_eq(paths.distance_to(Vector2i(-1, 0)), -1)
	assert_false(city.is_passable(Vector2i(0, -1)))


func test_ties_are_broken_like_the_prototype() -> void:
	# The prototype explores right, left, down, up: the path to a diagonal cell goes right first.
	var city := _city(["B.", ".."])
	assert_eq(city.paths_from(city.base).path_to(Vector2i(1, 1)), [Vector2i(1, 0), Vector2i(1, 1)])


func test_cells_within_a_number_of_steps() -> void:
	var city := _city([
		"..#",
		".B.",
		"...",
	])
	var within_one := city.paths_from(city.base).cells_within(1)
	within_one.sort()
	assert_eq(within_one, [Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 2), Vector2i(2, 1)])
	assert_eq(city.paths_from(city.base).cells_within(2).size(), 7, "every cell but the base and the works")


func test_manhattan_distance() -> void:
	assert_eq(City.manhattan(Vector2i(1, 2), Vector2i(4, 0)), 5)
