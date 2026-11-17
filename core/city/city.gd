class_name City
extends RefCounted
## The neighbourhood: a grid of crossroads linked by street segments, with buildings
## in the corners of the blocks between the streets (design doc §3).
##
## A crossroads is addressed with Vector2i(column, row), (0, 0) at the top left.
## The courier always stands on a crossroads and moves one street segment per step.
## A street segment is identified by its two ends, see street_key().
## A place (base, restaurant, client) is a building that opens on one crossroads:
## standing on that crossroads means being at the place.

enum Street { NORMAL, PAVED, WORKS }
enum Place { NONE, BASE, RESTAURANT, CLIENT }

## Same order as the prototype, so that ties between shortest paths are broken the same way.
const DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const NOWHERE := Vector2i(-1, -1)

## Number of crossroads across and down. There are (columns - 1) × (rows - 1) blocks.
var columns: int
var rows: int
var base: Vector2i

## Every change to a street after the first paths_from() call must empty _paths_cache.
var _streets: Dictionary[Vector4i, Street] = {}
var _places: Dictionary[Vector2i, Place] = {}
var _restaurant_kinds: Dictionary[Vector2i, StringName] = {}
var _client_numbers: Dictionary[Vector2i, int] = {}
## Block whose corner holds the building of each place (for drawing only).
var _building_blocks: Dictionary[Vector2i, Vector2i] = {}
## Shortest paths already computed, by Vector3i(start.x, start.y, cross_works).
## Emptied whenever a street changes.
var _paths_cache: Dictionary[Vector3i, CityPaths] = {}


func _init(p_columns: int, p_rows: int, p_base: Vector2i) -> void:
	columns = p_columns
	rows = p_rows
	base = p_base
	for y in rows:
		for x in columns:
			var crossroads := Vector2i(x, y)
			for direction in [Vector2i(1, 0), Vector2i(0, 1)]:
				if is_inside(crossroads + direction):
					_streets[street_key(crossroads, crossroads + direction)] = Street.NORMAL
	_places[base] = Place.BASE
	_building_blocks[base] = _first_or_nowhere(blocks_around(base))


## Draws a new city. Everything is drawn again until every crossroads can be reached from
## the base. Returns null, with an error, when the config makes it impossible or when
## config.city_generation_attempts draws all failed.
static func generate(config: GameConfig, restaurant_ids: Array[StringName], rng: GameRng) -> City:
	var problems := config.city_problems()
	if restaurant_ids.size() < config.restaurant_count:
		problems.append("not enough restaurant types")
	if not problems.is_empty():
		push_error("City.generate: " + "; ".join(problems))
		return null
	var city: City = null
	for _attempt in config.city_generation_attempts:
		city = City.new(config.city_columns, config.city_rows, config.base_cell)
		var free := city.crossroads_without_place()
		rng.shuffle(free)
		var kinds := restaurant_ids.duplicate()
		rng.shuffle(kinds)
		for i in config.restaurant_count:
			var restaurant: Vector2i = free.pop_back()
			city._add_place(restaurant, Place.RESTAURANT, rng)
			city._restaurant_kinds[restaurant] = kinds[i]
		for number in range(1, config.client_count + 1):
			var home: Vector2i = free.pop_back()
			city._add_place(home, Place.CLIENT, rng)
			city._client_numbers[home] = number
		city._building_blocks[city.base] = _pick_or_nowhere(city.blocks_around(city.base), rng)
		var streets := city.streets_of(Street.NORMAL)
		rng.shuffle(streets)
		for i in config.works_count:
			city._streets[streets[i]] = Street.WORKS
		for i in config.paved_count:
			city._streets[streets[config.works_count + i]] = Street.PAVED
		if city.is_fully_connected():
			return city
	push_error("City.generate: no connected city in %d attempts" % config.city_generation_attempts)
	return null


## Builds a city from a drawing, mostly for tests. Even lines are crossroads rows, odd lines
## hold the vertical streets. On a crossroads row, even characters are crossroads
## ("+" nothing, "B" base, "R" restaurant, "C" client) and odd characters are streets
## ("-" normal, "~" paved, "#" works). On a street row, even characters are streets
## ("|" normal, "~" paved, "#" works) and odd characters are blocks (any character).
## Clients are numbered in reading order; restaurants get the given kind.
##     B-+-C
##     | | #
##     +~R-+
static func from_text(lines: PackedStringArray, restaurant_kind: StringName = &"test") -> City:
	const PLACES := {"+": Place.NONE, "B": Place.BASE, "R": Place.RESTAURANT, "C": Place.CLIENT}
	const STREETS := {"-": Street.NORMAL, "|": Street.NORMAL, "~": Street.PAVED, "#": Street.WORKS}
	var base_cell := NOWHERE
	for y in range(0, lines.size(), 2):
		var x := lines[y].find("B")
		if x != -1:
			assert(x % 2 == 0, "line %d: the base must be on a crossroads (even position)" % y)
			base_cell = Vector2i(x / 2, y / 2)
	assert(base_cell != NOWHERE, "the drawing needs a base (B)")
	var city := City.new((lines[0].length() + 1) / 2, (lines.size() + 1) / 2, base_cell)
	var next_client := 1
	for y in city.rows:
		var line := lines[y * 2]
		assert(line.length() == city.columns * 2 - 1, "line %d has the wrong length" % (y * 2))
		for x in city.columns:
			var crossroads := Vector2i(x, y)
			var place: Place = PLACES[line[x * 2]]
			if place == Place.RESTAURANT:
				city._add_place(crossroads, place, null)
				city._restaurant_kinds[crossroads] = restaurant_kind
			elif place == Place.CLIENT:
				city._add_place(crossroads, place, null)
				city._client_numbers[crossroads] = next_client
				next_client += 1
			if x + 1 < city.columns:
				city._streets[street_key(crossroads, crossroads + Vector2i(1, 0))] = STREETS[line[x * 2 + 1]]
			if y + 1 < city.rows:
				var below := lines[y * 2 + 1]
				city._streets[street_key(crossroads, crossroads + Vector2i(0, 1))] = STREETS[below[x * 2]]
	return city


## Key of the street segment between two neighbouring crossroads, whatever their order:
## Vector4i(first.x, first.y, second.x, second.y) with the top-left end first.
static func street_key(a: Vector2i, b: Vector2i) -> Vector4i:
	if b.y < a.y or (b.y == a.y and b.x < a.x):
		var swap := a
		a = b
		b = swap
	return Vector4i(a.x, a.y, b.x, b.y)


## The two crossroads at the ends of a street segment.
static func street_ends(key: Vector4i) -> Array[Vector2i]:
	return [Vector2i(key.x, key.y), Vector2i(key.z, key.w)]


## Grid distance ignoring streets (used to pick the second client of a grouped order).
static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func is_inside(crossroads: Vector2i) -> bool:
	return is_in_grid(crossroads, columns, rows)


## Grid helpers shared with CityPaths: crossroads are stored in flat arrays, row by row.
static func is_in_grid(crossroads: Vector2i, p_columns: int, p_rows: int) -> bool:
	return crossroads.x >= 0 and crossroads.y >= 0 and crossroads.x < p_columns and crossroads.y < p_rows


static func grid_index(crossroads: Vector2i, p_columns: int) -> int:
	return crossroads.y * p_columns + crossroads.x


static func grid_crossroads(index: int, p_columns: int) -> Vector2i:
	return Vector2i(index % p_columns, index / p_columns)


## State of the street between two neighbouring crossroads.
func street_between(a: Vector2i, b: Vector2i) -> Street:
	return _streets[street_key(a, b)]


## Whether the courier can go from a crossroads to a neighbouring one. Road works block the
## street, unless the courier can cross them this turn (Contresens).
func can_walk(from: Vector2i, to: Vector2i, cross_works: bool = false) -> bool:
	if not is_inside(from) or not is_inside(to) or manhattan(from, to) != 1:
		return false
	return cross_works or street_between(from, to) != Street.WORKS


## Every street segment in this state, in a stable order.
func streets_of(street: Street) -> Array[Vector4i]:
	var out: Array[Vector4i] = []
	for key: Vector4i in _streets:
		if _streets[key] == street:
			out.append(key)
	return out


func place_at(crossroads: Vector2i) -> Place:
	return _places.get(crossroads, Place.NONE)


## Every crossroads with this kind of place, from the top left, row by row.
func crossroads_with(place: Place) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in rows:
		for x in columns:
			if place_at(Vector2i(x, y)) == place:
				out.append(Vector2i(x, y))
	return out


func crossroads_without_place() -> Array[Vector2i]:
	return crossroads_with(Place.NONE)


## Restaurant type at this crossroads, or &"" if there is no restaurant.
func restaurant_kind_at(crossroads: Vector2i) -> StringName:
	return _restaurant_kinds.get(crossroads, &"")


## Client number (1 to 12) at this crossroads, or 0 if there is none.
func client_number_at(crossroads: Vector2i) -> int:
	return _client_numbers.get(crossroads, 0)


## Crossroads of the client with this number, or NOWHERE if there is none.
func client_crossroads(number: int) -> Vector2i:
	for crossroads: Vector2i in _client_numbers:
		if _client_numbers[crossroads] == number:
			return crossroads
	return NOWHERE


## Restaurant types present in the city, sorted.
func restaurant_kinds() -> Array[StringName]:
	var kinds: Array[StringName] = []
	for kind: StringName in _restaurant_kinds.values():
		kinds.append(kind)
	kinds.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return kinds


## Blocks touching a crossroads (1 to 4). Block (x, y) lies between crossroads (x, y) and (x + 1, y + 1).
func blocks_around(crossroads: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for offset in [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 0)]:
		var block: Vector2i = crossroads + offset
		if block.x >= 0 and block.y >= 0 and block.x < columns - 1 and block.y < rows - 1:
			out.append(block)
	return out


## Block whose corner holds the building of the place at this crossroads (for drawing),
## NOWHERE if there is no place or no block.
func building_block(crossroads: Vector2i) -> Vector2i:
	return _building_blocks.get(crossroads, NOWHERE)


## Shortest paths from a crossroads (breadth-first search), one step per street segment;
## road works are avoided unless cross_works is true. Computed once per start until a
## street changes.
func paths_from(start: Vector2i, cross_works: bool = false) -> CityPaths:
	var key := Vector3i(start.x, start.y, 1 if cross_works else 0)
	if not _paths_cache.has(key):
		_paths_cache[key] = _search_paths(start, cross_works)
	return _paths_cache[key]


func _search_paths(start: Vector2i, cross_works: bool) -> CityPaths:
	var distance := PackedInt32Array()
	distance.resize(columns * rows)
	distance.fill(-1)
	var previous := PackedInt32Array()
	previous.resize(columns * rows)
	previous.fill(-1)
	if is_inside(start):
		distance[_index(start)] = 0
		var queue: Array[Vector2i] = [start]
		var head := 0
		while head < queue.size():
			var current := queue[head]
			head += 1
			for direction in DIRECTIONS:
				var next := current + direction
				if not can_walk(current, next, cross_works) or distance[_index(next)] != -1:
					continue
				distance[_index(next)] = distance[_index(current)] + 1
				previous[_index(next)] = _index(current)
				queue.append(next)
	return CityPaths.new(start, columns, rows, distance, previous)


## Number of steps between two crossroads, or -1 if b cannot be reached from a.
func distance(a: Vector2i, b: Vector2i, cross_works: bool = false) -> int:
	return paths_from(a, cross_works).distance_to(b)


## True when every crossroads can be reached from the base.
func is_fully_connected() -> bool:
	var paths := paths_from(base)
	for y in rows:
		for x in columns:
			if not paths.is_reachable(Vector2i(x, y)):
				return false
	return true


## "Works" event: road works move to other normal streets (not paved ones), keeping every
## crossroads reachable. Returns false and leaves the city unchanged if no valid layout was found.
func relocate_works(rng: GameRng, attempts: int) -> bool:
	var saved := _streets.duplicate()
	var works := streets_of(Street.WORKS)
	for key in works:
		_streets[key] = Street.NORMAL
	var cleared := _streets.duplicate()
	for _attempt in attempts:
		var normal := streets_of(Street.NORMAL)
		rng.shuffle(normal)
		for i in mini(works.size(), normal.size()):
			_streets[normal[i]] = Street.WORKS
		_paths_cache.clear()
		if is_fully_connected():
			return true
		_streets = cleared.duplicate()
	_streets = saved
	_paths_cache.clear()
	return false


## "New partner" reward: a restaurant of this type opens on a crossroads without any place,
## not the courier's. Returns its crossroads, or NOWHERE if there is no room.
func add_restaurant(kind: StringName, rng: GameRng, courier: Vector2i) -> Vector2i:
	var free := crossroads_without_place()
	free.erase(courier)
	if free.is_empty():
		return NOWHERE
	var crossroads: Vector2i = rng.pick(free)
	_add_place(crossroads, Place.RESTAURANT, rng)
	_restaurant_kinds[crossroads] = kind
	return crossroads


## Plain data describing the layout, to compare two cities (and later to save a run).
func snapshot() -> Dictionary:
	return {
		"columns": columns,
		"rows": rows,
		"base": base,
		"streets": _streets.duplicate(),
		"places": _places.duplicate(),
		"restaurants": _restaurant_kinds.duplicate(),
		"clients": _client_numbers.duplicate(),
		"buildings": _building_blocks.duplicate(),
	}


## Text drawing of the city, in the from_text() format, for debugging and test messages.
func to_text() -> String:
	const PLACE_SYMBOLS := {Place.NONE: "+", Place.BASE: "B", Place.RESTAURANT: "R", Place.CLIENT: "C"}
	const ACROSS := {Street.NORMAL: "-", Street.PAVED: "~", Street.WORKS: "#"}
	const DOWN := {Street.NORMAL: "|", Street.PAVED: "~", Street.WORKS: "#"}
	var lines := PackedStringArray()
	for y in rows:
		var line := ""
		var below := ""
		for x in columns:
			var crossroads := Vector2i(x, y)
			line += PLACE_SYMBOLS[place_at(crossroads)]
			if x + 1 < columns:
				line += ACROSS[street_between(crossroads, crossroads + Vector2i(1, 0))]
			if y + 1 < rows:
				below += DOWN[street_between(crossroads, crossroads + Vector2i(0, 1))]
				if x + 1 < columns:
					below += " "
		lines.append(line)
		if y + 1 < rows:
			lines.append(below)
	return "\n".join(lines)


## Puts a place on a crossroads. Its building goes in a corner of a block drawn with rng,
## or the first block when rng is null (drawings).
func _add_place(crossroads: Vector2i, place: Place, rng: GameRng) -> void:
	_places[crossroads] = place
	var blocks := blocks_around(crossroads)
	_building_blocks[crossroads] = _first_or_nowhere(blocks) if rng == null else _pick_or_nowhere(blocks, rng)


## A city one crossroads wide or high has no block: its buildings are then NOWHERE.
static func _first_or_nowhere(blocks: Array[Vector2i]) -> Vector2i:
	return NOWHERE if blocks.is_empty() else blocks[0]


static func _pick_or_nowhere(blocks: Array[Vector2i], rng: GameRng) -> Vector2i:
	return NOWHERE if blocks.is_empty() else rng.pick(blocks)


func _index(crossroads: Vector2i) -> int:
	return grid_index(crossroads, columns)
