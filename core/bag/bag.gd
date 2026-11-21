class_name Bag
extends RefCounted
## The delivery bag, seen from the front (design doc §6).
##
## A grid of columns and rows, row 0 at the top and the last row at the bottom.
## Dishes are dropped from the top of a column and fall until they rest on something.
## The bag also tracks the dish in the player's hand and the dishes set aside while
## reorganizing, because the rules for moving dishes around depend on them.
##
## The equipment that changes the bag rules is given as flags (see set_equipment())
## so that this class does not need to know about the rest of the game state.
## Each order has at most one dish, so items are identified by their order id.
## Every field is read-only from outside: the state only changes through the actions below.

## Why an action on the bag is refused.
enum Problem {
	NONE,
	## The shape does not fit at the top of the column (§6.2).
	NO_ROOM,
	## A cell would sit right above a fragile dish (§6.2).
	ON_FRAGILE,
	## A hot dish would touch a cold one, side by side (§6.2).
	HOT_COLD_TOUCH,
	## Another dish sits on the dish to lift (§6.3).
	SOMETHING_ON_TOP,
	## A dish is already in hand.
	HAND_BUSY,
	## No dish in hand to drop.
	NOTHING_HELD,
	## The dish to lift is not in the grid.
	NOT_IN_BAG,
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

## The four neighbours of a cell, side by side.
const SIDES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

var columns: int:
	get:
		return _columns
var rows: int:
	get:
		return _rows

## Séparateur isotherme: hot and cold dishes may touch.
var hot_and_cold_may_touch: bool:
	get:
		return _hot_and_cold_may_touch
## Sangles: shakes only damage fragile dishes.
var only_fragile_dishes_shaken: bool:
	get:
		return _only_fragile_dishes_shaken
## Porte-gobelet: dishes that fit in it (sodas) go there instead of the grid.
var has_cup_holder: bool:
	get:
		return _has_cup_holder

## "Caler le sac" was played: the next shake damages nothing.
var braced: bool:
	get:
		return _braced

## Dish in the player's hand, or null.
var held: BagItem:
	get:
		return _held
var held_origin: Origin:
	get:
		return _held_origin

var _columns: int
var _rows: int
var _hot_and_cold_may_touch: bool = false
var _only_fragile_dishes_shaken: bool = false
var _has_cup_holder: bool = false
var _braced: bool = false
var _held: BagItem = null
var _held_origin: Origin = Origin.RESTAURANT

## Dishes in the grid.
var _items: Array[BagItem] = []
var _cup_holder: Array[BagItem] = []
var _aside: Array[BagItem] = []
## Cells of the held dish before it was lifted from the bag.
var _held_previous_cells: Array[Vector2i] = []
## Orders whose dish was taken at the restaurant where the courier still stands: it can go
## back there from the hand or from aside (decision of 19/11/2026). See leave_stop().
var _from_this_stop: Array[int] = []


func _init(p_columns: int, p_rows: int) -> void:
	_columns = p_columns
	_rows = p_rows


## Sets the equipment that changes the rules (§8.4), from what the player owns.
func set_equipment(separator: bool, straps: bool, cup_holder: bool) -> void:
	_hot_and_cold_may_touch = separator
	_only_fragile_dishes_shaken = straps
	_has_cup_holder = cup_holder


## "Caler le sac": the next shake damages nothing (§6.5).
func brace() -> void:
	_braced = true


## End of the turn: an unused "Caler le sac" is lost (§6.5, "la prochaine secousse du tour").
func release_brace() -> void:
	_braced = false


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
	return _items.is_empty() and _cup_holder.is_empty() and _aside.is_empty() and _held == null


## A dish is in hand or set aside: the courier can neither move nor end the turn (§6.8).
func is_sorting() -> bool:
	return _held != null or not _aside.is_empty()


## The dish of an order wherever it is, or null.
func find(order_id: int) -> BagItem:
	match location_of(order_id):
		Location.NONE:
			return null
		Location.HELD:
			return _held
		var location:
			var list := _list_at(location)
			return list[_index_of(list, order_id)]


func location_of(order_id: int) -> Location:
	if _held != null and _held.order_id == order_id:
		return Location.HELD
	for location: Location in [Location.BAG, Location.CUP_HOLDER, Location.ASIDE]:
		if _index_of(_list_at(location), order_id) >= 0:
			return location
	return Location.NONE


## The dish can be delivered: it is in the grid or in the cup holder (§7.2).
func is_ready_to_deliver(order_id: int) -> bool:
	var location := location_of(order_id)
	return location == Location.BAG or location == Location.CUP_HOLDER


## Item occupying a cell of the grid, or null.
func item_at(cell: Vector2i) -> BagItem:
	return _occupancy().get(cell)


## True when another dish sits right above one of its cells (§6.3).
func has_something_on_top(item: BagItem) -> bool:
	return _has_something_on_top(item, _occupancy())


## Held on both sides: at least one cell blocked on the left and one on the right,
## by the wall or another dish (§6.4).
func is_wedged(item: BagItem) -> bool:
	return _is_wedged(item, _occupancy())


## Dishes of the grid that a shake could damage, to warn the player (§6.4).
func loose_items() -> Array[BagItem]:
	var occupancy := _occupancy()
	var out: Array[BagItem] = []
	for item in items():
		if not _is_wedged(item, occupancy):
			out.append(item)
	return out


# --- Placing dishes -----------------------------------------------------------------------

## Column where a shape dropped in the given column is anchored (§6.2).
func anchor_column(shape: Array[Vector2i], column: int) -> int:
	return mini(column, _columns - BagItem.shape_width(shape))


## Cells a shape would take if dropped in the column, or an empty array if it does not fit.
## Used for the drop preview as well as the drop itself.
func drop_cells(shape: Array[Vector2i], column: int) -> Array[Vector2i]:
	var anchor := anchor_column(shape, column)
	var occupancy := _occupancy()
	var none: Array[Vector2i] = []
	if not _cells_free(_translated(shape, Vector2i(anchor, 0)), occupancy):
		return none
	var top := 0
	while _cells_free(_translated(shape, Vector2i(anchor, top + 1)), occupancy):
		top += 1
	return _translated(shape, Vector2i(anchor, top))


## Why the held dish cannot be dropped in the column, or Problem.NONE.
func drop_problem(column: int) -> Problem:
	if _held == null:
		return Problem.NOTHING_HELD
	return _cells_problem(_held, drop_cells(_held.shape, column), _occupancy())


## Drops the held dish in the column. Nothing changes if there is a problem.
func drop_held(column: int) -> Problem:
	var problem := drop_problem(column)
	if problem != Problem.NONE:
		return problem
	_held.cells = drop_cells(_held.shape, column)
	_items.append(_held)
	_release_hand()
	return Problem.NONE


## Takes a dish at the restaurant. It goes to the hand, or straight to the cup holder
## if it fits there (§6.9). Returns false if a dish is already in hand.
func take_from_restaurant(item: BagItem) -> bool:
	if _held != null:
		return false
	if _has_cup_holder and item.dish.fits_cup_holder:
		_cup_holder.append(item)
		return true
	_take_in_hand(item, Origin.RESTAURANT)
	_from_this_stop.append(item.order_id)
	return true


## The courier left the place: the dishes taken there can no longer be given back.
func leave_stop() -> void:
	_from_this_stop.clear()


## Cancelling now sends the dish in hand back to the restaurant: it comes from there (straight,
## or after being set aside) and the courier has not left since.
func held_returns_to_restaurant() -> bool:
	if _held == null:
		return false
	return _held_origin == Origin.RESTAURANT \
			or (_held_origin == Origin.ASIDE and _held.order_id in _from_this_stop)


## This dish set aside was taken at the restaurant where the courier still stands: taken back
## in hand, it can go back there.
func can_return_from_aside(order_id: int) -> bool:
	return location_of(order_id) == Location.ASIDE and order_id in _from_this_stop


## Gives back to the restaurant every dish set aside that can go there (end of the turn).
## Returns them; the caller marks their orders as waiting again.
func return_aside_to_restaurant() -> Array[BagItem]:
	var returned: Array[BagItem] = []
	for item in _aside.duplicate():
		if item.order_id in _from_this_stop:
			_aside.erase(item)
			_from_this_stop.erase(item.order_id)
			returned.append(item)
	return returned


## Lifts a dish of the grid into the hand; refused if a dish is already in hand
## or another dish sits on it (§6.3).
func lift(order_id: int) -> Problem:
	var index := _index_of(_items, order_id)
	if _held != null:
		return Problem.HAND_BUSY
	if index < 0:
		return Problem.NOT_IN_BAG
	var item := _items[index]
	if has_something_on_top(item):
		return Problem.SOMETHING_ON_TOP
	_items.remove_at(index)
	_take_in_hand(item, Origin.BAG)
	_held_previous_cells = item.cells
	item.cells = []
	item.shape = BagItem.normalized(_held_previous_cells)
	return Problem.NONE


## Turns the held dish a quarter turn clockwise.
func rotate_held() -> void:
	if _held != null:
		_held.rotate()


## Puts the held dish back where it came from: exactly in its previous place in the bag,
## aside, or back at the restaurant (it then leaves the bag, the caller marks the order
## as waiting again). Returns the dish that went back to the restaurant, or null.
##
## A dish taken from aside goes back to the restaurant when it was taken there and the courier
## has not left (see held_returns_to_restaurant()): otherwise a dish that fits nowhere in the
## bag would stay aside for good, and the courier could neither move nor end the turn.
##
## While a dish is in hand, others can leave the bag (a delivery when a card is played on
## the spot) and the dishes above them fall. If its previous place is no longer free, no
## longer rests on something, or now breaks a rule, the dish is set aside instead.
func cancel_held() -> BagItem:
	if _held == null:
		return null
	var item := _held
	var origin := _held_origin
	var previous := _held_previous_cells
	if held_returns_to_restaurant():
		origin = Origin.RESTAURANT
	_release_hand()
	match origin:
		Origin.RESTAURANT:
			_from_this_stop.erase(item.order_id)
			return item
		Origin.BAG:
			if _can_rest_at(item, previous):
				item.cells = previous
				item.shape = BagItem.normalized(previous)
				_items.append(item)
			else:
				_aside.append(item)
		Origin.ASIDE:
			_aside.append(item)
	return null


## Sets the held dish next to the bag (§6.8).
func set_held_aside() -> void:
	if _held == null:
		return
	_aside.append(_held)
	_release_hand()


## Takes back in hand a dish set aside. Returns false if a dish is already in hand.
func take_from_aside(order_id: int) -> bool:
	var index := _index_of(_aside, order_id)
	if _held != null or index < 0:
		return false
	_take_in_hand(_aside[index], Origin.ASIDE)
	_aside.remove_at(index)
	return true


# --- Dishes leaving the bag, shakes ----------------------------------------------------------

## Removes a dish wherever it is (delivery or cancellation, §6.7). If it leaves the grid,
## the dishes above fall. Returns the fragile dishes crushed by the fall.
func remove(order_id: int) -> Array[BagItem]:
	var none: Array[BagItem] = []
	_from_this_stop.erase(order_id)
	var location := location_of(order_id)
	match location:
		Location.NONE:
			return none
		Location.HELD:
			_release_hand()
			return none
	var list := _list_at(location)
	list.remove_at(_index_of(list, order_id))
	return _settle() if location == Location.BAG else none


## Shakes the bag (§6.5). Every loose dish not damaged yet becomes damaged; with the straps
## only the fragile ones. "Caler le sac" cancels the shake and is used up.
func shake() -> ShakeResult:
	var result := ShakeResult.new()
	if _braced:
		_braced = false
		result.braced = true
		return result
	var occupancy := _occupancy()
	for item in items():
		if item.damaged or _is_wedged(item, occupancy):
			continue
		if _only_fragile_dishes_shaken and not item.is_fragile():
			continue
		item.damaged = true
		result.damaged.append(item)
	return result


## Empties the bag for a new night (§9). The size and the equipment are kept.
func clear() -> void:
	_items.clear()
	_cup_holder.clear()
	_aside.clear()
	_release_hand()
	_from_this_stop.clear()
	_braced = false


## Makes the bag bigger ("Sac plus large" / "Sac plus haut", §8.5). New rows are added at
## the top, so the dishes already in the bag keep resting on the bottom.
func grow(extra_columns: int, extra_rows: int) -> void:
	_columns += extra_columns
	_rows += extra_rows
	for item in _items:
		item.cells = _translated(item.cells, Vector2i(0, extra_rows))
	_held_previous_cells = _translated(_held_previous_cells, Vector2i(0, extra_rows))


## Text view of the grid for tests and debugging: one character per cell, "." when empty,
## otherwise the last digit of the order id.
func to_text() -> PackedStringArray:
	var lines := PackedStringArray()
	var occupancy := _occupancy()
	for y in _rows:
		var line := ""
		for x in _columns:
			var item: BagItem = occupancy.get(Vector2i(x, y))
			line += "." if item == null else str(item.order_id % 10)
		lines.append(line)
	return lines


# --- Internals ------------------------------------------------------------------------------

func _take_in_hand(item: BagItem, origin: Origin) -> void:
	_held = item
	_held_origin = origin
	_held_previous_cells = []


func _release_hand() -> void:
	_held = null
	_held_previous_cells = []


func _list_at(location: Location) -> Array[BagItem]:
	match location:
		Location.BAG:
			return _items
		Location.CUP_HOLDER:
			return _cup_holder
		Location.ASIDE:
			return _aside
	assert(false, "no list for location %d" % location)
	return []


func _cells_problem(item: BagItem, cells: Array[Vector2i], occupancy: Dictionary[Vector2i, BagItem]) -> Problem:
	if cells.is_empty():
		return Problem.NO_ROOM
	for cell in cells:
		var below: BagItem = occupancy.get(cell + Vector2i.DOWN)
		if below != null and below.is_fragile():
			return Problem.ON_FRAGILE
	if _hot_and_cold_may_touch or item.temperature() == DishData.Temperature.NEUTRAL:
		return Problem.NONE
	var opposite := DishData.Temperature.COLD if item.temperature() == DishData.Temperature.HOT \
		else DishData.Temperature.HOT
	for cell in cells:
		for side in SIDES:
			var neighbour: BagItem = occupancy.get(cell + side)
			if neighbour != null and neighbour != item and neighbour.temperature() == opposite:
				return Problem.HOT_COLD_TOUCH
	return Problem.NONE


## The dish could stay on these cells: they are free, it rests on the bottom or on another
## dish, and no placing rule is broken.
func _can_rest_at(item: BagItem, cells: Array[Vector2i]) -> bool:
	var occupancy := _occupancy()
	if cells.is_empty() or not _cells_free(cells, occupancy):
		return false
	if _cells_free(_translated(cells, Vector2i.DOWN), occupancy):
		return false
	return _cells_problem(item, cells, occupancy) == Problem.NONE


## Lets the dishes fall until nothing moves, lowest first, each one as a block.
## Then every fragile dish with something on it is crushed (§6.7).
func _settle() -> Array[BagItem]:
	var crushed: Array[BagItem] = []
	var occupancy := _occupancy()
	var fell := false
	var moved := true
	while moved:
		moved = false
		for item in items():
			for cell in item.cells:
				occupancy.erase(cell)
			var lowered := _translated(item.cells, Vector2i.DOWN)
			if _cells_free(lowered, occupancy):
				item.cells = lowered
				moved = true
				fell = true
			for cell in item.cells:
				occupancy[cell] = item
	if not fell:
		return crushed
	for item in items():
		if item.is_fragile() and not item.damaged and _has_something_on_top(item, occupancy):
			item.damaged = true
			crushed.append(item)
	return crushed


func _has_something_on_top(item: BagItem, occupancy: Dictionary[Vector2i, BagItem]) -> bool:
	for cell in item.cells:
		var above: BagItem = occupancy.get(cell + Vector2i.UP)
		if above != null and above != item:
			return true
	return false


func _is_wedged(item: BagItem, occupancy: Dictionary[Vector2i, BagItem]) -> bool:
	if item.cells.is_empty():
		return false
	var left := false
	var right := false
	for cell in item.cells:
		var on_left: BagItem = occupancy.get(cell + Vector2i.LEFT)
		var on_right: BagItem = occupancy.get(cell + Vector2i.RIGHT)
		left = left or cell.x == 0 or (on_left != null and on_left != item)
		right = right or cell.x == _columns - 1 or (on_right != null and on_right != item)
	return left and right


## Cell -> item, for the dishes of the grid.
func _occupancy() -> Dictionary[Vector2i, BagItem]:
	var out: Dictionary[Vector2i, BagItem] = {}
	for item in _items:
		for cell in item.cells:
			out[cell] = item
	return out


func _cells_free(cells: Array[Vector2i], occupancy: Dictionary[Vector2i, BagItem]) -> bool:
	for cell in cells:
		if cell.x < 0 or cell.x >= _columns or cell.y < 0 or cell.y >= _rows or occupancy.has(cell):
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
