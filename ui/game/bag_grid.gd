class_name BagGrid
extends Control
## The bag seen from the front: its cells, the dishes in it and, while a dish is in hand, where
## it would land in the column under the mouse (green if allowed, red otherwise).
##
## Clicks: with a dish in hand, a click drops it in the column; otherwise a click on a dish
## lifts it.

signal column_clicked(column: int)
signal dish_clicked(order_id: int)
## The column under the mouse changed (-1 when the mouse left the bag).
signal hover_changed(column: int)

const MAX_CELL := 46.0
const GAP := 3.0
const FLOOR := 8.0
const PREVIEW_OK := Color(0.13, 0.57, 0.35, 0.55)
const PREVIEW_BAD := Color(0.81, 0.21, 0.16, 0.55)

var game: Game

var _hover_column: int = -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func refresh() -> void:
	var bag := game.state.bag
	# One row above the bag shows a dish that does not fit.
	custom_minimum_size = Vector2(bag.columns * MAX_CELL, (bag.rows + 1) * MAX_CELL + FLOOR) + Vector2.ONE * GAP * 2
	if _hover_column >= bag.columns:
		_hover_column = -1
	queue_redraw()


func hover_column() -> int:
	return _hover_column


func _gui_input(event: InputEvent) -> void:
	if game == null:
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		_set_hover(_column_at(motion.position))
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var bag := game.state.bag
	var cell := _cell_at(click.position)
	if bag.held != null:
		if cell.x >= 0 and cell.x < bag.columns:
			accept_event()
			column_clicked.emit(cell.x)
		return
	var item := bag.item_at(cell)
	if item != null:
		accept_event()
		dish_clicked.emit(item.order_id)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_set_hover(-1)


func _set_hover(column: int) -> void:
	if column == _hover_column:
		return
	_hover_column = column
	queue_redraw()
	hover_changed.emit(column)


# --- Drawing --------------------------------------------------------------------------------

func _draw() -> void:
	if game == null:
		return
	var bag := game.state.bag
	var cell := _cell_size()
	var origin := _origin()
	var frame := Rect2(origin - Vector2.ONE * GAP, Vector2(bag.columns, bag.rows) * cell + Vector2.ONE * GAP * 2)
	draw_rect(frame, UiStyle.INK)
	draw_rect(Rect2(frame.position.x, frame.end.y, frame.size.x, FLOOR), UiStyle.INK)
	for y in bag.rows:
		for x in bag.columns:
			draw_rect(_cell_rect(Vector2i(x, y)).grow(-GAP / 2), UiStyle.ROAD.darkened(0.05))
	if bag.held != null and _hover_column >= 0:
		var x := bag.anchor_column(bag.held.shape, _hover_column)
		draw_rect(Rect2(origin.x + x * cell, origin.y, bag.held.width() * cell, bag.rows * cell),
				Color(UiStyle.MUSTARD, 0.15))
	var loose := bag.loose_items()
	for item in bag.items():
		draw_dish(self, item, item.cells, origin, cell, item in loose and not item.damaged)
	_draw_preview()


## Where the dish in hand would land.
func _draw_preview() -> void:
	var bag := game.state.bag
	if bag.held == null or _hover_column < 0:
		return
	var shape := bag.held.shape
	var cells := bag.drop_cells(shape, _hover_column)
	var allowed := bag.drop_problem(_hover_column) == Bag.Problem.NONE
	if cells.is_empty():
		# No room: show the shape above the bag, at its anchor column.
		var anchor := bag.anchor_column(shape, _hover_column)
		var height := 0
		for cell in shape:
			height = maxi(height, cell.y + 1)
		for cell in shape:
			cells.append(cell + Vector2i(anchor, -height))
	for cell in cells:
		draw_rect(_cell_rect(cell).grow(-GAP / 2), PREVIEW_OK if allowed else PREVIEW_BAD)


## Draws a dish cell by cell, without gaps between its own cells: the color of its order, a dot
## for hot or cold, a triangle when fragile, a cross when damaged, a yellow outline when loose.
## Shared with the dish in hand and the dishes set aside.
static func draw_dish(canvas: CanvasItem, item: BagItem, cells: Array[Vector2i], origin: Vector2,
		size: float, loose: bool) -> void:
	var color := UiStyle.order_color(item.order_id)
	if item.damaged:
		color = color.darkened(0.35)
	var inset_size := maxf(1.5, size * 0.06)
	for cell in cells:
		var rect := Rect2(origin + Vector2(cell) * size, Vector2(size, size))
		# Shrink the sides that are an edge of the dish, so that dishes stay apart.
		var inset: Dictionary[Vector2i, float] = {}
		for side in Bag.SIDES:
			inset[side] = 0.0 if (cell + side) in cells else inset_size
		rect.position += Vector2(inset[Vector2i.LEFT], inset[Vector2i.UP])
		rect.size -= Vector2(inset[Vector2i.LEFT] + inset[Vector2i.RIGHT], inset[Vector2i.UP] + inset[Vector2i.DOWN])
		canvas.draw_rect(rect, color)
		if loose:
			for side in Bag.SIDES:
				if inset[side] > 0.0:
					_draw_side(canvas, rect, side, UiStyle.MUSTARD, maxf(2.0, size * 0.07))
		if item.damaged:
			var white := Color(1, 1, 1, 0.8)
			canvas.draw_line(rect.position + Vector2(4, 4), rect.end - Vector2(4, 4), white, 2.0)
			canvas.draw_line(Vector2(rect.end.x - 4, rect.position.y + 4), Vector2(rect.position.x + 4, rect.end.y - 4), white, 2.0)
	var first := _first_cell(cells)
	var corner := origin + Vector2(first) * size
	var mark := size * 0.2
	if item.temperature() != DishData.Temperature.NEUTRAL:
		var dot := corner + Vector2(size - mark * 0.9, mark * 0.9)
		canvas.draw_circle(dot, mark * 0.45 + 1.5, Color.WHITE)
		canvas.draw_circle(dot, mark * 0.45, UiStyle.temperature_color(item.temperature()))
	if item.is_fragile():
		var top_left := corner + Vector2(mark * 0.5, mark * 0.5)
		canvas.draw_colored_polygon(PackedVector2Array([top_left + Vector2(mark / 2, 0),
				top_left + Vector2(mark, mark), top_left + Vector2(0, mark)]), Color.WHITE)
	if size >= 30:
		canvas.draw_string(UiStyle.bold_font(), corner + Vector2(inset_size + 3, size - inset_size - 4),
				str(item.order_id), HORIZONTAL_ALIGNMENT_LEFT, -1, int(size * 0.3), Color.WHITE)


static func _first_cell(cells: Array[Vector2i]) -> Vector2i:
	var first := cells[0]
	for cell in cells:
		if cell.y < first.y or (cell.y == first.y and cell.x < first.x):
			first = cell
	return first


static func _draw_side(canvas: CanvasItem, rect: Rect2, side: Vector2i, color: Color, width: float) -> void:
	var a := rect.position
	var b := rect.end
	match side:
		Vector2i.LEFT:
			canvas.draw_line(a, Vector2(a.x, b.y), color, width)
		Vector2i.RIGHT:
			canvas.draw_line(Vector2(b.x, a.y), b, color, width)
		Vector2i.UP:
			canvas.draw_line(a, Vector2(b.x, a.y), color, width)
		Vector2i.DOWN:
			canvas.draw_line(Vector2(a.x, b.y), b, color, width)


# --- Geometry -------------------------------------------------------------------------------

func _cell_size() -> float:
	var bag := game.state.bag
	return minf(MAX_CELL, (size.x - GAP * 2) / bag.columns)


## Top left of the bag grid, centered horizontally, below the row for dishes that do not fit.
func _origin() -> Vector2:
	var bag := game.state.bag
	var cell := _cell_size()
	return Vector2((size.x - bag.columns * cell) / 2, cell + GAP)


func _cell_rect(cell: Vector2i) -> Rect2:
	var size_ := _cell_size()
	return Rect2(_origin() + Vector2(cell) * size_, Vector2(size_, size_))


func _cell_at(position: Vector2) -> Vector2i:
	return Vector2i(((position - _origin()) / _cell_size()).floor())


func _column_at(position: Vector2) -> int:
	var column := _cell_at(position).x
	return column if column >= 0 and column < game.state.bag.columns else -1
