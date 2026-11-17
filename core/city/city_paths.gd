class_name CityPaths
extends RefCounted
## Shortest paths from one crossroads to every other one (breadth-first search).
##
## Built by City.paths_from(), which keeps it in a cache: it never changes once built.
## One step per street segment.

var start: Vector2i:
	get:
		return _start

var _start: Vector2i
var _columns: int
var _rows: int
## Number of steps to reach each crossroads (indexed by y * columns + x), -1 if unreachable.
var _distance: PackedInt32Array
## Index of the previous crossroads on the shortest path, -1 for the start and unreachable ones.
var _previous: PackedInt32Array


func _init(p_start: Vector2i, columns: int, rows: int, distance: PackedInt32Array, previous: PackedInt32Array) -> void:
	_start = p_start
	_columns = columns
	_rows = rows
	_distance = distance
	_previous = previous


## Number of steps to reach the crossroads, or -1 if it cannot be reached.
func distance_to(crossroads: Vector2i) -> int:
	if not _is_inside(crossroads):
		return -1
	return _distance[_index(crossroads)]


func is_reachable(crossroads: Vector2i) -> bool:
	return distance_to(crossroads) >= 0


## Crossroads to walk through to reach the target, start excluded and target included.
## Empty if the target is the start or cannot be reached.
func path_to(crossroads: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not is_reachable(crossroads):
		return path
	var index := _index(crossroads)
	while _previous[index] != -1:
		path.append(_crossroads(index))
		index = _previous[index]
	path.reverse()
	return path


## Every crossroads reachable in 1 to max_steps steps (to show where the courier can go).
func reachable_within(max_steps: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for index in _distance.size():
		var d := _distance[index]
		if d > 0 and d <= max_steps:
			out.append(_crossroads(index))
	return out


func _is_inside(crossroads: Vector2i) -> bool:
	return City.is_in_grid(crossroads, _columns, _rows)


func _index(crossroads: Vector2i) -> int:
	return City.grid_index(crossroads, _columns)


func _crossroads(index: int) -> Vector2i:
	return City.grid_crossroads(index, _columns)
