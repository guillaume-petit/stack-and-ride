class_name Bag
extends RefCounted
## The delivery bag, seen from the front (design doc §6).
##
## A grid of columns and rows, row 0 at the top and the last row at the bottom.
## Dishes are dropped from the top of a column and fall until they rest on something.
## The bag also tracks the dish in the player's hand and the dishes set aside while
## reorganizing, because the rules for moving dishes around depend on them.
##
## The equipment that changes the bag rules is given as flags (see the "Equipment" section)
## so that this class does not need to know about the rest of the game state.
## Each order has at most one dish, so items are identified by their order id.

## Why a dish cannot be placed.
enum Problem {
	NONE,
	## The shape does not fit at the top of the column (§6.2).
	NO_ROOM,
	## A cell would sit right above a fragile dish (§6.2).
	ON_FRAGILE,
	## A hot dish would touch a cold one, side by side (§6.2).
	HOT_COLD_TOUCH,
}

## Where a dish is.
enum Location { NONE, HELD, BAG, CUP_HOLDER, ASIDE }

## Where the dish in hand comes from, to put it back on cancel (§6.3, §6.8).
enum Origin { RESTAURANT, BAG, ASIDE }

## What a shake did (§6.5).
class ShakeResult:
	extends RefCounted
	## The shake was cancelled by "Caler le sac".
	var braced: bool = false
	## Dishes damaged by this shake.
	var damaged: Array[BagItem] = []

const _SIDES: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var columns: int
var rows: int

# Equipment that changes the rules, set by the game from what the player owns.
## Séparateur isotherme: hot and cold dishes may touch.
var hot_and_cold_may_touch: bool = false
## Sangles: shakes only damage fragile dishes.
var only_fragile_dishes_shaken: bool = false
## Porte-gobelet: dishes that fit in it (sodas) go there instead of the grid.
var has_cup_holder: bool = false

## "Caler le sac" was played: the next shake damages nothing.
var braced: bool = false

## Dish in the player's hand, or null.
var held: BagItem = null
var held_origin: Origin = Origin.RESTAURANT

## Dishes in the grid.
var _items: Array[BagItem] = []
var _cup_holder: Array[BagItem] = []
var _aside: Array[BagItem] = []
## Cells of the held dish before it was lifted from the bag.
var _held_previous_cells: Array[Vector2i] = []


func _init(p_columns: int, p_rows: int) -> void:
	columns = p_columns
	rows = p_rows


# --- Reading the bag ----------------------------------------------------------------------

## Dishes in the grid, from the bottom of the bag to the top (then by order id).
func items() -> Array[BagItem]:
	var out := _items.duplicate()
	out.sort_custom(func(a: BagItem, b: BagItem) -> bool:
		var bottom_a := _bottom_row(a)
		var bottom_b := _bottom_row(b)
		return bottom_a > bottom_b or (bottom_a == bottom_b and a.order_id < b.order_id))
	return out


func cup_holder_items() -> Array[BagItem]:
	return _cup_holder.duplicate()


func aside_items() -> Array[BagItem]:
	return _aside.duplicate()


## Number of dishes carried in the bag, cup holder included (for the "mule" profile, §11).
func dish_count() -> int:
	return _items.size() + _cup_holder.size()


func is_empty() -> bool:
	return _items.is_empty() and _cup_holder.is_empty() and _aside.is_empty() and held == null


## A dish is in hand or set aside: the courier can neither move nor end the turn (§6.8).
func is_sorting() -> bool:
	return held != null or not _aside.is_empty()


func find(order_id: int) -> BagItem:
	if held != null and held.order_id == order_id:
		return held
	for list: Array[BagItem] in [_items, _cup_holder, _aside]:
		for item in list:
			if item.order_id == order_id:
				return item
	return null


func location_of(order_id: int) -> Location:
	if held != null and held.order_id == order_id:
		return Location.HELD
	if _index_of(_items, order_id) >= 0:
		return Location.BAG
	if _index_of(_cup_holder, order_id) >= 0:
		return Location.CUP_HOLDER
	if _index_of(_aside, order_id) >= 0:
		return Location.ASIDE
	return Location.NONE


## The dish can be delivered: it is in the grid or in the cup holder (§7.2).
func is_ready_to_deliver(order_id: int) -> bool:
	var location := location_of(order_id)
	return location == Location.BAG or location == Location.CUP_HOLDER


## Item occupying a cell of the grid, or null.
func item_at(cell: Vector2i) -> BagItem:
	for item in _items:
		if cell in item.cells:
			return item
	return null


## True when another dish sits right above one of its cells (§6.3).
func has_something_on_top(item: BagItem) -> bool:
	var occupancy := _occupancy()
	for cell in item.cells:
		var above: BagItem = occupancy.get(cell + Vector2i.UP)
		if above != null and above != item:
			return true
	return false


## Held on both sides: at least one cell blocked on the left and one on the right,
## by the wall or another dish (§6.4).
func is_wedged(item: BagItem) -> bool:
	if item.cells.is_empty():
		return false
	var occupancy := _occupancy()
	var left := false
	var right := false
	for cell in item.cells:
		var on_left: BagItem = occupancy.get(cell + Vector2i.LEFT)
		var on_right: BagItem = occupancy.get(cell + Vector2i.RIGHT)
		left = left or cell.x == 0 or (on_left != null and on_left != item)
		right = right or cell.x == columns - 1 or (on_right != null and on_right != item)
	return left and right


## Dishes of the grid that a shake could damage, to warn the player (§6.4).
func loose_items() -> Array[BagItem]:
	var out: Array[BagItem] = []
	for item in items():
		if not is_wedged(item):
			out.append(item)
	return out


# --- Placing dishes -----------------------------------------------------------------------

## Column where a shape dropped in the given column is anchored (§6.2).
func anchor_column(shape: Array[Vector2i], column: int) -> int:
	return mini(column, columns - BagItem.shape_width(shape))


## Cells a shape would take if dropped in the column, or an empty array if it does not fit.
## Used for the drop preview as well as the drop itself.
func drop_cells(shape: Array[Vector2i], column: int) -> Array[Vector2i]:
	var anchor := anchor_column(shape, column)
	var occupancy := _occupancy()
	var none: Array[Vector2i] = []
	if not _fits(shape, Vector2i(anchor, 0), occupancy):
		return none
	var top := 0
	while _fits(shape, Vector2i(anchor, top + 1), occupancy):
		top += 1
	return _translated(shape, Vector2i(anchor, top))


## Why the held dish cannot be dropped in the column, or Problem.NONE.
func drop_problem(column: int) -> Problem:
	if held == null:
		return Problem.NO_ROOM
	return _cells_problem(held, drop_cells(held.shape, column))


## Drops the held dish in the column. Nothing changes if there is a problem.
func drop_held(column: int) -> Problem:
	var problem := drop_problem(column)
	if problem != Problem.NONE:
		return problem
	held.cells = drop_cells(held.shape, column)
	_items.append(held)
	held = null
	_held_previous_cells = []
	return Problem.NONE


## Takes a dish at the restaurant. It goes to the hand, or straight to the cup holder
## if it fits there (§6.9). Returns false if a dish is already in hand.
func take_from_restaurant(item: BagItem) -> bool:
	if held != null:
		return false
	if has_cup_holder and item.dish.fits_cup_holder:
		_cup_holder.append(item)
		return true
	held = item
	held_origin = Origin.RESTAURANT
	return true


## Lifts a dish of the grid into the hand; refused if a dish is already in hand
## or another dish sits on it (§6.3).
func lift(order_id: int) -> bool:
	var index := _index_of(_items, order_id)
	if held != null or index < 0:
		return false
	var item := _items[index]
	if has_something_on_top(item):
		return false
	_items.remove_at(index)
	_held_previous_cells = item.cells
	item.cells = []
	item.shape = BagItem.normalized(_held_previous_cells)
	held = item
	held_origin = Origin.BAG
	return true


## Turns the held dish a quarter turn clockwise.
func rotate_held() -> void:
	if held != null:
		held.rotate()


## Puts the held dish back where it came from: exactly in its previous place in the bag,
## aside, or back at the restaurant (it then leaves the bag, the caller marks the order
## as waiting again). Returns the dish that went back to the restaurant, or null.
func cancel_held() -> BagItem:
	if held == null:
		return null
	var item := held
	held = null
	match held_origin:
		Origin.BAG:
			item.cells = _held_previous_cells
			item.shape = BagItem.normalized(item.cells)
			_items.append(item)
		Origin.ASIDE:
			_aside.append(item)
		Origin.RESTAURANT:
			_held_previous_cells = []
			return item
	_held_previous_cells = []
	return null


## Sets the held dish next to the bag (§6.8).
func set_held_aside() -> void:
	if held == null:
		return
	_aside.append(held)
	held = null
	_held_previous_cells = []


## Takes back in hand a dish set aside. Returns false if a dish is already in hand.
func take_from_aside(order_id: int) -> bool:
	var index := _index_of(_aside, order_id)
	if held != null or index < 0:
		return false
	held = _aside[index]
	_aside.remove_at(index)
	held_origin = Origin.ASIDE
	return true


# --- Dishes leaving the bag, shakes ----------------------------------------------------------

## Removes a dish wherever it is (delivery or cancellation, §6.7). If it leaves the grid,
## the dishes above fall. Returns the fragile dishes crushed by the fall.
func remove(order_id: int) -> Array[BagItem]:
	var none: Array[BagItem] = []
	if held != null and held.order_id == order_id:
		held = null
		_held_previous_cells = []
		return none
	for list: Array[BagItem] in [_cup_holder, _aside]:
		var other_index := _index_of(list, order_id)
		if other_index >= 0:
			list.remove_at(other_index)
			return none
	var index := _index_of(_items, order_id)
	if index < 0:
		return none
	_items.remove_at(index)
	return _settle()


## Shakes the bag (§6.5). Every loose dish not damaged yet becomes damaged; with the straps
## only the fragile ones. "Caler le sac" cancels the shake and is used up.
func shake() -> ShakeResult:
	var result := ShakeResult.new()
	if braced:
		braced = false
		result.braced = true
		return result
	for item in items():
		if item.damaged or is_wedged(item):
			continue
		if only_fragile_dishes_shaken and not item.is_fragile():
			continue
		item.damaged = true
		result.damaged.append(item)
	return result


## Empties the bag for a new night (§9). The size and the equipment flags are kept.
func clear() -> void:
	_items.clear()
	_cup_holder.clear()
	_aside.clear()
	held = null
	_held_previous_cells = []
	braced = false


## Makes the bag bigger ("Sac plus large" / "Sac plus haut", §8.5). New rows are added at
## the top, so the dishes already in the bag keep resting on the bottom.
func grow(extra_columns: int, extra_rows: int) -> void:
	columns += extra_columns
	rows += extra_rows
	for item in _items:
		item.cells = _translated(item.cells, Vector2i(0, extra_rows))
	_held_previous_cells = _translated(_held_previous_cells, Vector2i(0, extra_rows))


## Text view of the grid for tests and debugging: one character per cell, "." when empty,
## otherwise the last digit of the order id.
func to_text() -> PackedStringArray:
	var lines := PackedStringArray()
	var occupancy := _occupancy()
	for y in rows:
		var line := ""
		for x in columns:
			var item: BagItem = occupancy.get(Vector2i(x, y))
			line += "." if item == null else str(item.order_id % 10)
		lines.append(line)
	return lines


# --- Internals ------------------------------------------------------------------------------

func _cells_problem(item: BagItem, cells: Array[Vector2i]) -> Problem:
	if cells.is_empty():
		return Problem.NO_ROOM
	var occupancy := _occupancy()
	for cell in cells:
		var below: BagItem = occupancy.get(cell + Vector2i.DOWN)
		if below != null and below.is_fragile():
			return Problem.ON_FRAGILE
	if hot_and_cold_may_touch or item.temperature() == DishData.Temperature.NEUTRAL:
		return Problem.NONE
	var opposite := DishData.Temperature.COLD if item.temperature() == DishData.Temperature.HOT \
		else DishData.Temperature.HOT
	for cell in cells:
		for side in _SIDES:
			var neighbour: BagItem = occupancy.get(cell + side)
			if neighbour != null and neighbour != item and neighbour.temperature() == opposite:
				return Problem.HOT_COLD_TOUCH
	return Problem.NONE


## Lets the dishes fall until nothing moves, lowest first, each one as a block.
## Then every fragile dish with something on it is crushed (§6.7).
func _settle() -> Array[BagItem]:
	var crushed: Array[BagItem] = []
	var fell := false
	var moved := true
	while moved:
		moved = false
		for item in items():
			var others := _occupancy(item)
			var lowered := _translated(item.cells, Vector2i.DOWN)
			if _cells_free(lowered, others):
				item.cells = lowered
				moved = true
				fell = true
	if not fell:
		return crushed
	for item in items():
		if item.is_fragile() and not item.damaged and has_something_on_top(item):
			item.damaged = true
			crushed.append(item)
	return crushed


## Cell -> item, for the dishes of the grid except the one to skip.
func _occupancy(skip: BagItem = null) -> Dictionary[Vector2i, BagItem]:
	var out: Dictionary[Vector2i, BagItem] = {}
	for item in _items:
		if item == skip:
			continue
		for cell in item.cells:
			out[cell] = item
	return out


func _fits(shape: Array[Vector2i], offset: Vector2i, occupancy: Dictionary[Vector2i, BagItem]) -> bool:
	return _cells_free(_translated(shape, offset), occupancy)


func _cells_free(cells: Array[Vector2i], occupancy: Dictionary[Vector2i, BagItem]) -> bool:
	for cell in cells:
		if cell.x < 0 or cell.x >= columns or cell.y < 0 or cell.y >= rows or occupancy.has(cell):
			return false
	return true


func _bottom_row(item: BagItem) -> int:
	var bottom := -1
	for cell in item.cells:
		bottom = maxi(bottom, cell.y)
	return bottom


static func _translated(cells: Array[Vector2i], offset: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for cell in cells:
		out.append(cell + offset)
	return out


static func _index_of(list: Array[BagItem], order_id: int) -> int:
	for i in list.size():
		if list[i].order_id == order_id:
			return i
	return -1
