extends Control
## Throwaway debug screen for iteration 2: plays with a Bag by hand to check its rules
## (drop, rotate, lift, set aside, shake, delivery with falls and crushing, equipment).
## Not part of the game (the real bag is ui/game/bag_view.gd); kept to try bag rules by hand.
##
## Open ui/debug/bag_debug.tscn in the editor and press F6 (run the current scene).
## Mouse on the bag: left click drops the dish in hand in that column, or lifts the
## clicked dish; right click delivers the clicked dish. R turns the dish in hand.

const CELL := 76
const GAP := 4.0
const MARGIN := 32
const BACKGROUND := Color("#eceff3")
const INK := Color("#1a1e24")
const MUTED := Color("#5d6570")
const BAG_COLOR := Color("#3a4049")
const EMPTY_CELL := Color("#4a515b")
const LOOSE_COLOR := Color("#f0b020")
const PREVIEW_OK := Color(0.2, 0.75, 0.4, 0.55)
const PREVIEW_BAD := Color(0.9, 0.2, 0.15, 0.55)
const TEMPERATURE_COLORS := {
	DishData.Temperature.NEUTRAL: Color("#8a8f96"),
	DishData.Temperature.HOT: Color("#e2672b"),
	DishData.Temperature.COLD: Color("#3a8fd6"),
}
const PROBLEM_KEYS := {
	Bag.Problem.NO_ROOM: "BAG_PROBLEM_NO_ROOM",
	Bag.Problem.ON_FRAGILE: "BAG_PROBLEM_ON_FRAGILE",
	Bag.Problem.HOT_COLD_TOUCH: "BAG_PROBLEM_HOT_COLD_TOUCH",
	Bag.Problem.SOMETHING_ON_TOP: "BAG_PROBLEM_SOMETHING_ON_TOP",
	Bag.Problem.HAND_BUSY: "BAG_PROBLEM_HAND_BUSY",
	Bag.Problem.NOTHING_HELD: "BAG_PROBLEM_NOTHING_HELD",
	Bag.Problem.NOT_IN_BAG: "BAG_PROBLEM_NOT_IN_BAG",
}

var _content: GameContent
var _bag: Bag
var _next_order_id: int = 1
## Column under the mouse, or -1.
var _hover_column: int = -1

var _bag_view: Control
var _hand_view: Control
var _hand_buttons: Array[Button] = []
var _aside_row: HFlowContainer
var _cup_holder_label: Label
var _status: Label
var _summary: Label
var _separator_box: CheckBox
var _straps_box: CheckBox
var _cup_holder_box: CheckBox
var _columns_box: SpinBox
var _rows_box: SpinBox


func _ready() -> void:
	_content = GameContent.load_from()
	var problems := _content.validate()
	if not problems.is_empty():
		push_error("Content problems:\n" + "\n".join(problems))
	_bag = Bag.new(_content.config.bag_columns, _content.config.bag_rows)
	_build_layout()
	_say(tr("DEBUG_BAG_HINT"))
	_refresh()


# --- Layout -----------------------------------------------------------------------------------

func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = MARGIN
	row.offset_top = MARGIN
	row.offset_right = -MARGIN
	row.offset_bottom = -MARGIN
	row.add_theme_constant_override("separation", MARGIN)
	add_child(row)

	# The bag is a plain Control whose drawing and clicks are handled here.
	_bag_view = Control.new()
	_bag_view.mouse_filter = Control.MOUSE_FILTER_STOP
	_bag_view.draw.connect(_draw_bag)
	_bag_view.gui_input.connect(_on_bag_input)
	_bag_view.mouse_exited.connect(func() -> void: _set_hover(-1))
	row.add_child(_bag_view)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	row.add_child(scroll)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	scroll.add_child(side)

	side.add_child(_label(tr("DEBUG_BAG_TITLE"), 28, INK))
	_summary = _label("", 16, INK)
	side.add_child(_summary)
	# Result of the last action, right under the title so that it is always visible.
	_status = _label("", 18, INK)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(420, 50)
	side.add_child(_status)

	side.add_child(_label(tr("DEBUG_BAG_TAKE"), 16, MUTED))
	var dishes := HFlowContainer.new()
	for dish_id in _content.dish_ids():
		var dish := _content.dishes[dish_id]
		dishes.add_child(_button(tr(dish.name_key()), func() -> void: _take(dish)))
	side.add_child(dishes)

	side.add_child(_label(tr("DEBUG_BAG_HAND"), 16, MUTED))
	var hand_row := HBoxContainer.new()
	hand_row.add_theme_constant_override("separation", 12)
	_hand_view = Control.new()
	_hand_view.custom_minimum_size = Vector2(3, 3) * CELL / 2.0
	_hand_view.draw.connect(_draw_hand)
	hand_row.add_child(_hand_view)
	var hand_actions := VBoxContainer.new()
	_hand_buttons = [
		_button(tr("DEBUG_BAG_ROTATE"), _rotate),
		_button(tr("DEBUG_BAG_SET_ASIDE"), _set_aside),
		_button(tr("DEBUG_BAG_CANCEL"), _cancel),
	]
	for button in _hand_buttons:
		hand_actions.add_child(button)
	hand_row.add_child(hand_actions)
	side.add_child(hand_row)

	side.add_child(_label(tr("DEBUG_BAG_ASIDE"), 16, MUTED))
	_aside_row = HFlowContainer.new()
	side.add_child(_aside_row)
	_cup_holder_label = _label("", 16, INK)
	side.add_child(_cup_holder_label)

	side.add_child(_label(tr("DEBUG_BAG_ACTIONS"), 16, MUTED))
	var actions := HFlowContainer.new()
	actions.add_child(_button(tr("DEBUG_BAG_SHAKE"), _shake))
	actions.add_child(_button(tr("DEBUG_BAG_BRACE"), _brace))
	side.add_child(actions)

	side.add_child(_label(tr("DEBUG_BAG_EQUIPMENT"), 16, MUTED))
	var equipment := HFlowContainer.new()
	_separator_box = _check_box(tr("EQUIPMENT_SEPARATOR"), _equip)
	_straps_box = _check_box(tr("EQUIPMENT_STRAPS"), _equip)
	_cup_holder_box = _check_box(tr("EQUIPMENT_CUPHOLDER"), _equip)
	for box in [_separator_box, _straps_box, _cup_holder_box]:
		equipment.add_child(box)
	side.add_child(equipment)

	side.add_child(_label(tr("DEBUG_BAG_SIZE"), 16, MUTED))
	var size_row := HFlowContainer.new()
	_columns_box = _spin_box(1, 8, _bag.columns)
	_rows_box = _spin_box(1, 6, _bag.rows)
	size_row.add_child(_columns_box)
	size_row.add_child(_label("×", 18, INK))
	size_row.add_child(_rows_box)
	size_row.add_child(_button(tr("DEBUG_BAG_NEW_BAG"), _new_bag))
	size_row.add_child(_button(tr("UPGRADE_WIDE"), func() -> void: _grow(1, 0)))
	size_row.add_child(_button(tr("UPGRADE_TALL"), func() -> void: _grow(0, 1)))
	size_row.add_child(_button(tr("DEBUG_BAG_CLEAR"), _clear))
	side.add_child(size_row)

	var legend := _label(tr("DEBUG_BAG_LEGEND"), 15, MUTED)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	legend.custom_minimum_size.x = 420
	side.add_child(legend)


# --- Actions ----------------------------------------------------------------------------------

func _take(dish: DishData) -> void:
	var item := BagItem.new(_next_order_id, dish)
	if not _bag.take_from_restaurant(item):
		_say(tr(PROBLEM_KEYS[Bag.Problem.HAND_BUSY]))
		return
	_next_order_id += 1
	if _bag.location_of(item.order_id) == Bag.Location.CUP_HOLDER:
		_say(tr("DEBUG_BAG_IN_CUP_HOLDER") % _name(item))
	else:
		_say(tr("DEBUG_BAG_TAKEN") % _name(item))
	_refresh()


func _rotate() -> void:
	_bag.rotate_held()
	_refresh()


func _set_aside() -> void:
	_bag.set_held_aside()
	_refresh()


func _cancel() -> void:
	var back := _bag.cancel_held()
	if back != null:
		_say(tr("DEBUG_BAG_BACK_TO_RESTAURANT") % _name(back))
	_refresh()


func _drop(column: int) -> void:
	var item := _bag.held
	var problem := _bag.drop_held(column)
	if problem == Bag.Problem.NONE:
		_say(tr("DEBUG_BAG_DROPPED") % _name(item))
	else:
		_say(tr(PROBLEM_KEYS[problem]))
	_refresh()


func _lift(item: BagItem) -> void:
	var problem := _bag.lift(item.order_id)
	if problem == Bag.Problem.NONE:
		_say(tr("DEBUG_BAG_LIFTED") % _name(item))
	else:
		_say(tr(PROBLEM_KEYS[problem]))
	_refresh()


func _deliver(item: BagItem) -> void:
	var crushed := _bag.remove(item.order_id)
	var text := tr("DEBUG_BAG_DELIVERED") % [_name(item), _state_text(item)]
	if not crushed.is_empty():
		text += "\n" + tr("DEBUG_BAG_CRUSHED") % _names(crushed)
	_say(text)
	_refresh()


func _take_from_aside(item: BagItem) -> void:
	if not _bag.take_from_aside(item.order_id):
		_say(tr(PROBLEM_KEYS[Bag.Problem.HAND_BUSY]))
	_refresh()


func _shake() -> void:
	var result := _bag.shake()
	if result.braced:
		_say(tr("DEBUG_BAG_SHAKE_BRACED"))
	elif result.damaged.is_empty():
		_say(tr("DEBUG_BAG_SHAKE_NOTHING"))
	else:
		_say(tr("DEBUG_BAG_SHAKE_DAMAGED") % _names(result.damaged))
	_refresh()


func _brace() -> void:
	_bag.brace()
	_refresh()


func _equip(_on: bool) -> void:
	_bag.set_equipment(_separator_box.button_pressed, _straps_box.button_pressed, _cup_holder_box.button_pressed)
	_refresh()


func _new_bag() -> void:
	var old := _bag
	_bag = Bag.new(int(_columns_box.value), int(_rows_box.value))
	_bag.set_equipment(old.hot_and_cold_may_touch, old.only_fragile_dishes_shaken, old.has_cup_holder)
	_say("")
	_refresh()


func _grow(extra_columns: int, extra_rows: int) -> void:
	_bag.grow(extra_columns, extra_rows)
	_refresh()


func _clear() -> void:
	_bag.clear()
	_say("")
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_R:
		_rotate()


func _on_bag_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_set_hover(_column_at(motion.position))
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed:
		return
	var cell := _cell_at(click.position)
	var item: BagItem = _bag.item_at(cell)
	if click.button_index == MOUSE_BUTTON_LEFT:
		if _bag.held != null:
			if cell.x >= 0 and cell.x < _bag.columns:
				_drop(cell.x)
		elif item != null:
			_lift(item)
	elif click.button_index == MOUSE_BUTTON_RIGHT and item != null:
		_deliver(item)


func _set_hover(column: int) -> void:
	if column != _hover_column:
		_hover_column = column
		_bag_view.queue_redraw()


# --- Display ----------------------------------------------------------------------------------

func _refresh() -> void:
	_bag_view.custom_minimum_size = Vector2(_bag.columns, _bag.rows + 1) * CELL + Vector2(GAP, GAP) * 4
	for button in _hand_buttons:
		button.disabled = _bag.held == null
	for child in _aside_row.get_children():
		child.queue_free()
	for item in _bag.aside_items():
		var button := _button(_name(item), func() -> void: _take_from_aside(item))
		button.disabled = _bag.held != null
		_aside_row.add_child(button)
	if _bag.aside_items().is_empty():
		_aside_row.add_child(_label(tr("DEBUG_BAG_NOTHING"), 16, MUTED))
	var cups: PackedStringArray = []
	for item in _bag.cup_holder_items():
		cups.append(_name(item))
	_cup_holder_label.text = tr("DEBUG_BAG_CUP_HOLDER") % (", ".join(cups) if not cups.is_empty() else "—")
	_summary.text = tr("DEBUG_BAG_SUMMARY") % [_bag.columns, _bag.rows, _bag.dish_count(),
			_bag.loose_items().size(),
			tr("DEBUG_BAG_SORTING") if _bag.is_sorting() else tr("DEBUG_BAG_READY")]
	if _bag.braced:
		_summary.text += tr("DEBUG_BAG_IS_BRACED")
	_bag_view.queue_redraw()
	_hand_view.queue_redraw()


func _draw_bag() -> void:
	# One empty row above the bag shows where the dish is dropped from.
	var origin := _bag_origin()
	var frame := Rect2(origin - Vector2(GAP, GAP), Vector2(_bag.columns, _bag.rows) * CELL + Vector2(GAP, GAP) * 2)
	_bag_view.draw_rect(frame, BAG_COLOR)
	for y in _bag.rows:
		for x in _bag.columns:
			_bag_view.draw_rect(_cell_rect(Vector2i(x, y)).grow(-GAP / 2), EMPTY_CELL)
	var loose := _bag.loose_items()
	for item in _bag.items():
		_draw_item(_bag_view, item, item.cells, origin, CELL, item in loose)
	_draw_preview()
	var font := ThemeDB.fallback_font
	_bag_view.draw_string(font, Vector2(frame.position.x, frame.end.y + 22), tr("DEBUG_BAG_BOTTOM"),
			HORIZONTAL_ALIGNMENT_CENTER, frame.size.x, 14, MUTED)


## Where the dish in hand would land, green if allowed, red otherwise.
func _draw_preview() -> void:
	if _bag.held == null or _hover_column < 0:
		return
	var shape := _bag.held.shape
	var cells := _bag.drop_cells(shape, _hover_column)
	var allowed := _bag.drop_problem(_hover_column) == Bag.Problem.NONE
	if cells.is_empty():
		# No room: show the shape above the bag, at its anchor column.
		var anchor := _bag.anchor_column(shape, _hover_column)
		var height := 0
		for cell in shape:
			height = maxi(height, cell.y + 1)
		for cell in shape:
			cells.append(cell + Vector2i(anchor, -height))
	for cell in cells:
		_bag_view.draw_rect(_cell_rect(cell).grow(-GAP / 2), PREVIEW_OK if allowed else PREVIEW_BAD)


func _draw_hand() -> void:
	if _bag.held == null:
		return
	_draw_item(_hand_view, _bag.held, _bag.held.shape, Vector2.ZERO, CELL / 2.0, false)


## Draws a dish cell by cell, without gaps between its own cells.
func _draw_item(canvas: CanvasItem, item: BagItem, cells: Array[Vector2i], origin: Vector2,
		size: float, loose: bool) -> void:
	var color: Color = TEMPERATURE_COLORS[item.temperature()]
	if item.damaged:
		color = color.darkened(0.45)
	var font := ThemeDB.fallback_font
	for cell in cells:
		var rect := Rect2(origin + Vector2(cell) * size, Vector2(size, size))
		# Shrink the sides that are an edge of the dish, so that dishes stay apart.
		var inset := {}
		for side in Bag.SIDES:
			inset[side] = 0.0 if (cell + side) in cells else GAP
		rect.position += Vector2(inset[Vector2i.LEFT], inset[Vector2i.UP])
		rect.size -= Vector2(inset[Vector2i.LEFT] + inset[Vector2i.RIGHT], inset[Vector2i.UP] + inset[Vector2i.DOWN])
		canvas.draw_rect(rect, color)
		if loose:
			for side in Bag.SIDES:
				if inset[side] > 0.0:
					_draw_side(canvas, rect, side, LOOSE_COLOR, 3.0)
		if item.damaged:
			canvas.draw_line(rect.position, rect.end, INK, 2.0)
			canvas.draw_line(Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), INK, 2.0)
		if item.is_fragile():
			var top_left := rect.position + Vector2(5, 5)
			var tri := size * 0.22
			canvas.draw_colored_polygon(PackedVector2Array([
				top_left + Vector2(tri / 2, 0), top_left + Vector2(tri, tri), top_left + Vector2(0, tri)]), Color.WHITE)
	# The order number on the first cell (top left).
	var first := cells[0]
	for cell in cells:
		if cell.y < first.y or (cell.y == first.y and cell.x < first.x):
			first = cell
	var font_size := int(size * 0.24)
	canvas.draw_string(font, origin + Vector2(first) * size + Vector2(GAP + 2, size - GAP - 4),
			"#%d %s" % [item.order_id, tr(item.dish.name_key()).get_slice(" ", 0)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _draw_side(canvas: CanvasItem, rect: Rect2, side: Vector2i, color: Color, width: float) -> void:
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


func _bag_origin() -> Vector2:
	return Vector2(GAP * 2, CELL + GAP * 2)


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(_bag_origin() + Vector2(cell) * CELL, Vector2(CELL, CELL))


func _cell_at(position: Vector2) -> Vector2i:
	return Vector2i(((position - _bag_origin()) / CELL).floor())


func _column_at(position: Vector2) -> int:
	var column := _cell_at(position).x
	return column if column >= 0 and column < _bag.columns else -1


# --- Small helpers ----------------------------------------------------------------------------

func _say(text: String) -> void:
	_status.text = text


func _name(item: BagItem) -> String:
	return "#%d %s" % [item.order_id, tr(item.dish.name_key())]


func _names(items: Array[BagItem]) -> String:
	var names: PackedStringArray = []
	for item in items:
		names.append(_name(item))
	return ", ".join(names)


func _state_text(item: BagItem) -> String:
	return tr("DEBUG_BAG_DAMAGED") if item.damaged else tr("DEBUG_BAG_INTACT")


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	button.pressed.connect(on_pressed)
	return button


func _check_box(text: String, on_toggled: Callable) -> CheckBox:
	var box := CheckBox.new()
	box.text = text
	box.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	# The default theme has light text, made for a dark background.
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		box.add_theme_color_override(color_name, INK)
	box.toggled.connect(on_toggled)
	return box


func _spin_box(min_value: int, max_value: int, value: int) -> SpinBox:
	var box := SpinBox.new()
	box.min_value = min_value
	box.max_value = max_value
	box.value = value
	return box
