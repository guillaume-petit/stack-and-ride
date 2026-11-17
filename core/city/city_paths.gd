class_name CityPaths
extends RefCounted
## Shortest paths from one cell to every other cell of the city (breadth-first search).
##
## Built by City.paths_from(). Moves are orthogonal, one step per cell.

var start: Vector2i

var _width: int
var _height: int
## Number of steps to reach each cell (indexed by y * width + x), -1 if unreachable.
var _distance: PackedInt32Array
## Index of the previous cell on the shortest path, -1 for the start and unreachable cells.
var _previous: PackedInt32Array


func _init(p_start: Vector2i, width: int, height: int, distance: PackedInt32Array, previous: PackedInt32Array) -> void:
	start = p_start
	_width = width
	_height = height
	_distance = distance
	_previous = previous


## Number of steps to reach the cell, or -1 if it cannot be reached.
func distance_to(cell: Vector2i) -> int:
	if not _is_inside(cell):
		return -1
	return _distance[_index(cell)]


func is_reachable(cell: Vector2i) -> bool:
	return distance_to(cell) >= 0


## Cells to walk through to reach the target, start excluded and target included.
## Empty if the target is the start or cannot be reached.
func path_to(cell: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not is_reachable(cell):
		return path
	var index := _index(cell)
	while _previous[index] != -1:
		path.append(_cell(index))
		index = _previous[index]
	path.reverse()
	return path


## Every cell reachable in 1 to max_steps steps (to show where the courier can go).
func cells_within(max_steps: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for index in _distance.size():
		var d := _distance[index]
		if d > 0 and d <= max_steps:
			out.append(_cell(index))
	return out


func _is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _width and cell.y < _height


func _index(cell: Vector2i) -> int:
	return cell.y * _width + cell.x


func _cell(index: int) -> Vector2i:
	return Vector2i(index % _width, index / _width)
