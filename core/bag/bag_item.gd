class_name BagItem
extends RefCounted
## One dish of an order, followed from the restaurant to the client: in hand, in the bag,
## in the cup holder or set aside (design doc §6).
##
## The damage lives here so that it follows the dish wherever the player moves it.

## Order this dish belongs to; it identifies the item in the bag.
var order_id: int
var dish: DishData
## Current orientation, normalized: the smallest column and row are 0, row 0 at the top.
var shape: Array[Vector2i] = []
## Cells taken in the bag as (column, row), row 0 at the top of the bag. Empty when the
## dish is not in the grid (in hand, set aside, in the cup holder).
var cells: Array[Vector2i] = []
## Damaged by a shake or crushed: it stays damaged until delivered.
var damaged: bool = false


func _init(p_order_id: int, p_dish: DishData) -> void:
	order_id = p_order_id
	dish = p_dish
	shape = normalized(p_dish.cells)


func is_fragile() -> bool:
	return dish.fragile


func temperature() -> DishData.Temperature:
	return dish.temperature


## Width of the current orientation, in columns.
func width() -> int:
	return shape_width(shape)


## Turns the shape a quarter turn clockwise.
func rotate() -> void:
	var turned: Array[Vector2i] = []
	for cell in shape:
		turned.append(Vector2i(-cell.y, cell.x))
	shape = normalized(turned)


## Moves the shape so that its smallest column and row are 0, cells sorted row by row.
static func normalized(source: Array[Vector2i]) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if source.is_empty():
		return out
	var min_x := source[0].x
	var min_y := source[0].y
	for cell in source:
		min_x = mini(min_x, cell.x)
		min_y = mini(min_y, cell.y)
	for cell in source:
		out.append(cell - Vector2i(min_x, min_y))
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out


static func shape_width(source: Array[Vector2i]) -> int:
	var width := 0
	for cell in source:
		width = maxi(width, cell.x + 1)
	return width
