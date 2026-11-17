class_name City
extends RefCounted
## The neighbourhood: a grid of cells with the base, restaurants, client homes,
## road works and paved streets (design doc §3).
##
## Cells are addressed with Vector2i(column, row), (0, 0) at the top left.

enum Tile { ROAD, PAVED, WORKS, BASE, RESTAURANT, CLIENT }

## Same order as the prototype, so that ties between shortest paths are broken the same way.
const DIRECTIONS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var width: int
var height: int
var base: Vector2i

var _tiles: PackedInt32Array
var _restaurant_kinds: Dictionary[Vector2i, StringName] = {}
var _client_numbers: Dictionary[Vector2i, int] = {}


func _init(p_width: int, p_height: int, p_base: Vector2i) -> void:
	width = p_width
	height = p_height
	base = p_base
	_tiles = PackedInt32Array()
	_tiles.resize(width * height)
	_tiles.fill(Tile.ROAD)
	_set_tile(base, Tile.BASE)


## Draws a new city. Cells are drawn again until every cell but road works can be reached
## from the base; after config.city_generation_attempts failures the last draw is kept
## (check is_fully_connected()).
static func generate(config: GameConfig, restaurant_ids: Array[StringName], rng: GameRng) -> City:
	var needed := 1 + config.restaurant_count + config.client_count + config.works_count + config.paved_count
	assert(needed <= config.city_width * config.city_height, "the city is too small for its content")
	assert(restaurant_ids.size() >= config.restaurant_count, "not enough restaurant types")
	var city: City = null
	for _attempt in config.city_generation_attempts:
		city = City.new(config.city_width, config.city_height, config.base_cell)
		var free := city.cells_of(Tile.ROAD)
		rng.shuffle(free)
		var kinds := restaurant_ids.duplicate()
		rng.shuffle(kinds)
		for i in config.restaurant_count:
			city._place_restaurant(free.pop_back(), kinds[i])
		for number in range(1, config.client_count + 1):
			var cell: Vector2i = free.pop_back()
			city._set_tile(cell, Tile.CLIENT)
			city._client_numbers[cell] = number
		for _i in config.works_count:
			city._set_tile(free.pop_back(), Tile.WORKS)
		for _i in config.paved_count:
			city._set_tile(free.pop_back(), Tile.PAVED)
		if city.is_fully_connected():
			return city
	return city


## Builds a city from a drawing (same symbols as to_text()), mostly for tests.
## Clients are numbered in reading order; restaurants get the given kind.
static func from_text(lines: PackedStringArray, restaurant_kind: StringName = &"test") -> City:
	const TILES := {".": Tile.ROAD, "~": Tile.PAVED, "#": Tile.WORKS, "B": Tile.BASE, "R": Tile.RESTAURANT, "C": Tile.CLIENT}
	var base_cell := Vector2i(-1, -1)
	for y in lines.size():
		var x := lines[y].find("B")
		if x != -1:
			base_cell = Vector2i(x, y)
	assert(base_cell != Vector2i(-1, -1), "the drawing needs a base (B)")
	var city := City.new(lines[0].length(), lines.size(), base_cell)
	var next_client := 1
	for y in lines.size():
		assert(lines[y].length() == city.width, "every line must have the same length")
		for x in city.width:
			var cell := Vector2i(x, y)
			var tile: Tile = TILES[lines[y][x]]
			if tile == Tile.RESTAURANT:
				city._place_restaurant(cell, restaurant_kind)
			else:
				city._set_tile(cell, tile)
			if tile == Tile.CLIENT:
				city._client_numbers[cell] = next_client
				next_client += 1
	return city


## Grid distance ignoring obstacles (used to pick the second client of a grouped order).
static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


func tile_at(cell: Vector2i) -> Tile:
	return _tiles[_index(cell)] as Tile


## Road works block the way, unless the courier can cross them this turn (Contresens).
func is_passable(cell: Vector2i, cross_works: bool = false) -> bool:
	if not is_inside(cell):
		return false
	return cross_works or tile_at(cell) != Tile.WORKS


## Restaurant type on this cell, or &"" if there is no restaurant.
func restaurant_kind_at(cell: Vector2i) -> StringName:
	return _restaurant_kinds.get(cell, &"")


## Client number (1 to 12) living on this cell, or 0 if there is none.
func client_number_at(cell: Vector2i) -> int:
	return _client_numbers.get(cell, 0)


## Cell of the client with this number, or Vector2i(-1, -1) if there is none.
func client_cell(number: int) -> Vector2i:
	for cell: Vector2i in _client_numbers:
		if _client_numbers[cell] == number:
			return cell
	return Vector2i(-1, -1)


## Every cell with this tile, from the top-left corner, row by row.
func cells_of(tile: Tile) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for index in _tiles.size():
		if _tiles[index] == tile:
			out.append(_cell(index))
	return out


## Restaurant types present in the city, sorted.
func restaurant_kinds() -> Array[StringName]:
	var kinds: Array[StringName] = []
	for kind: StringName in _restaurant_kinds.values():
		kinds.append(kind)
	kinds.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	return kinds


## Shortest paths from a cell (breadth-first search). Moves are orthogonal, one step per
## cell; road works are skipped unless cross_works is true.
func paths_from(start: Vector2i, cross_works: bool = false) -> CityPaths:
	var distance := PackedInt32Array()
	distance.resize(width * height)
	distance.fill(-1)
	var previous := PackedInt32Array()
	previous.resize(width * height)
	previous.fill(-1)
	if is_inside(start):
		distance[_index(start)] = 0
		var queue: Array[Vector2i] = [start]
		var head := 0
		while head < queue.size():
			var cell := queue[head]
			head += 1
			for direction in DIRECTIONS:
				var next := cell + direction
				if not is_passable(next, cross_works) or distance[_index(next)] != -1:
					continue
				distance[_index(next)] = distance[_index(cell)] + 1
				previous[_index(next)] = _index(cell)
				queue.append(next)
	return CityPaths.new(start, width, height, distance, previous)


## Number of steps between two cells, or -1 if b cannot be reached from a.
func distance(a: Vector2i, b: Vector2i, cross_works: bool = false) -> int:
	return paths_from(a, cross_works).distance_to(b)


## True when every cell but road works can be reached from the base.
func is_fully_connected() -> bool:
	var paths := paths_from(base)
	for index in _tiles.size():
		if _tiles[index] != Tile.WORKS and not paths.is_reachable(_cell(index)):
			return false
	return true


## "Works" event: road works move to other plain roads (not paved streets), keeping every
## cell reachable. Returns false and leaves the city unchanged if no valid layout was found.
func relocate_works(rng: GameRng, attempts: int) -> bool:
	var saved := _tiles.duplicate()
	var works := cells_of(Tile.WORKS)
	for cell in works:
		_set_tile(cell, Tile.ROAD)
	var original := _tiles.duplicate()
	for _attempt in attempts:
		var roads := cells_of(Tile.ROAD)
		rng.shuffle(roads)
		for i in mini(works.size(), roads.size()):
			_set_tile(roads[i], Tile.WORKS)
		if is_fully_connected():
			return true
		_tiles = original.duplicate()
	_tiles = saved
	return false


## "New partner" reward: a restaurant of this type opens on a plain road (not paved,
## not under the courier). Returns its cell, or Vector2i(-1, -1) if there is no room.
func add_restaurant(kind: StringName, rng: GameRng, courier_cell: Vector2i) -> Vector2i:
	var roads := cells_of(Tile.ROAD)
	roads.erase(courier_cell)
	if roads.is_empty():
		return Vector2i(-1, -1)
	var cell: Vector2i = rng.pick(roads)
	_place_restaurant(cell, kind)
	return cell


## Plain data describing the layout, to compare two cities (and later to save a run).
func snapshot() -> Dictionary:
	return {
		"width": width,
		"height": height,
		"base": base,
		"tiles": Array(_tiles),
		"restaurants": _restaurant_kinds.duplicate(),
		"clients": _client_numbers.duplicate(),
	}


## Text drawing of the city, for debugging and test failure messages.
## B base, R restaurant, C client, # road works, ~ paved street, . road.
func to_text() -> String:
	const SYMBOLS := {Tile.ROAD: ".", Tile.PAVED: "~", Tile.WORKS: "#", Tile.BASE: "B", Tile.RESTAURANT: "R", Tile.CLIENT: "C"}
	var lines := PackedStringArray()
	for y in height:
		var line := ""
		for x in width:
			line += SYMBOLS[tile_at(Vector2i(x, y))]
		lines.append(line)
	return "\n".join(lines)


func _place_restaurant(cell: Vector2i, kind: StringName) -> void:
	_set_tile(cell, Tile.RESTAURANT)
	_restaurant_kinds[cell] = kind


func _set_tile(cell: Vector2i, tile: Tile) -> void:
	_tiles[_index(cell)] = tile


func _index(cell: Vector2i) -> int:
	return cell.y * width + cell.x


func _cell(index: int) -> Vector2i:
	return Vector2i(index % width, index / width)
