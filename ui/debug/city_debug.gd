extends Control
## Throwaway debug screen for iteration 1: draws a generated city and the shortest path
## from the base to the clicked cell. Not part of the game; the real UI comes in iteration 4.
##
## Open ui/debug/city_debug.tscn in the editor and press F6 (run the current scene).

const CELL_SIZE := 72
const GRID_MARGIN := 24
const BACKGROUND := Color("#eceff3")
const INK := Color("#1a1e24")
const MUTED := Color("#5d6570")
const PATH_COLOR := Color("#e2452b")
const TILE_COLORS := {
	City.Tile.ROAD: Color("#ffffff"),
	City.Tile.PAVED: Color("#b9b2a6"),
	City.Tile.WORKS: Color("#f0a020"),
	City.Tile.BASE: Color("#1a1e24"),
	City.Tile.RESTAURANT: Color("#2f7fc4"),
	City.Tile.CLIENT: Color("#23935a"),
}

var _content: GameContent
var _city: City
var _seed: int = 1
## Clicked cell, or (-1, -1) when nothing is selected.
var _target := Vector2i(-1, -1)

var _map: Control
var _seed_box: SpinBox
var _cross_works: CheckBox
var _info: Label


func _ready() -> void:
	_content = GameContent.load_from()
	var problems := _content.validate()
	if not problems.is_empty():
		push_error("Content problems:\n" + "\n".join(problems))
	_build_layout()
	_generate()


func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_right = -GRID_MARGIN
	row.offset_top = GRID_MARGIN
	row.add_theme_constant_override("separation", GRID_MARGIN)
	add_child(row)

	# The map is a plain Control whose drawing and clicks are handled here.
	_map = Control.new()
	_map.custom_minimum_size = Vector2.ONE * (CELL_SIZE * 8 + GRID_MARGIN * 2)
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	_map.draw.connect(_draw_map)
	_map.gui_input.connect(_on_map_input)
	row.add_child(_map)

	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 12)
	row.add_child(side)

	side.add_child(_label(tr("DEBUG_CITY_TITLE"), 28, INK))

	var seed_row := HBoxContainer.new()
	seed_row.add_child(_label(tr("DEBUG_CITY_SEED"), 18, INK))
	_seed_box = SpinBox.new()
	_seed_box.min_value = 0
	_seed_box.max_value = 999999999
	_seed_box.value = _seed
	_seed_box.value_changed.connect(func(value: float) -> void: _set_seed(int(value)))
	seed_row.add_child(_seed_box)
	side.add_child(seed_row)

	side.add_child(_button(tr("DEBUG_CITY_NEXT_SEED"), func() -> void: _set_seed(_seed + 1)))
	side.add_child(_button(tr("DEBUG_CITY_RANDOM_SEED"), func() -> void: _set_seed(randi() % 1000000)))
	side.add_child(_button(tr("DEBUG_CITY_RELOCATE_WORKS"), _relocate_works))

	_cross_works = CheckBox.new()
	_cross_works.text = tr("DEBUG_CITY_CROSS_WORKS")
	_cross_works.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	# The default theme has light text, made for a dark background.
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		_cross_works.add_theme_color_override(color_name, INK)
	_cross_works.toggled.connect(func(_on: bool) -> void: _refresh())
	side.add_child(_cross_works)

	_info = _label("", 18, INK)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_info)

	var legend := _label(tr("DEBUG_CITY_LEGEND"), 15, MUTED)
	legend.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(legend)


func _set_seed(value: int) -> void:
	if value == _seed and _city != null:
		return
	_seed = value
	_seed_box.set_value_no_signal(value)
	_generate()


func _generate() -> void:
	_city = City.generate(_content.config, _content.restaurant_ids(), GameRng.new(_seed))
	_target = Vector2i(-1, -1)
	_refresh()


func _relocate_works() -> void:
	# Its own random source, so the same seed always gives the same first city.
	var moved := _city.relocate_works(GameRng.new(randi()), _content.config.works_relocation_attempts)
	if not moved:
		push_warning("No valid layout found for the road works.")
	_refresh()


func _refresh() -> void:
	_info.text = _describe_target()
	_map.queue_redraw()


func _describe_target() -> String:
	var connected := tr("DEBUG_CITY_CONNECTED") if _city.is_fully_connected() else tr("DEBUG_CITY_NOT_CONNECTED")
	if _target == Vector2i(-1, -1):
		return connected + "\n" + tr("DEBUG_CITY_CLICK_HINT")
	var distance := _city.distance(_city.base, _target, _cross_works.button_pressed)
	var where := "(%d, %d)" % [_target.x, _target.y]
	if distance < 0:
		return connected + "\n" + tr("DEBUG_CITY_UNREACHABLE") % where
	return connected + "\n" + tr("DEBUG_CITY_DISTANCE") % [where, distance]


func _on_map_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var cell := Vector2i(((click.position - Vector2.ONE * GRID_MARGIN) / CELL_SIZE).floor())
	if _city.is_inside(cell):
		_target = cell
		_refresh()


func _draw_map() -> void:
	for y in _city.height:
		for x in _city.width:
			var cell := Vector2i(x, y)
			_map.draw_rect(_cell_rect(cell).grow(-2), TILE_COLORS[_city.tile_at(cell)])
	# The path goes under the labels so that it never hides them.
	if _target != Vector2i(-1, -1):
		var path := _city.paths_from(_city.base, _cross_works.button_pressed).path_to(_target)
		var points := PackedVector2Array([_cell_rect(_city.base).get_center()])
		for cell in path:
			points.append(_cell_rect(cell).get_center())
		if points.size() > 1:
			_map.draw_polyline(points, PATH_COLOR, 5.0, true)
		_map.draw_rect(_cell_rect(_target).grow(-2), PATH_COLOR, false, 4.0)
	var font := ThemeDB.fallback_font
	for y in _city.height:
		for x in _city.width:
			var cell := Vector2i(x, y)
			var tile := _city.tile_at(cell)
			var text := _cell_text(cell, tile)
			if text.is_empty():
				continue
			var rect := _cell_rect(cell)
			var color := INK if tile in [City.Tile.ROAD, City.Tile.PAVED, City.Tile.WORKS] else Color.WHITE
			# Thin outline so the label stays readable over the path.
			_map.draw_string_outline(font, rect.position + Vector2(0, CELL_SIZE * 0.6), text,
					HORIZONTAL_ALIGNMENT_CENTER, CELL_SIZE, 16, 4, TILE_COLORS[tile])
			_map.draw_string(font, rect.position + Vector2(0, CELL_SIZE * 0.6), text,
					HORIZONTAL_ALIGNMENT_CENTER, CELL_SIZE, 16, color)


func _cell_text(cell: Vector2i, tile: City.Tile) -> String:
	match tile:
		City.Tile.BASE:
			return tr("DEBUG_CITY_BASE")
		City.Tile.RESTAURANT:
			# Restaurant names are long: show the first word only.
			return tr("RESTAURANT_" + String(_city.restaurant_kind_at(cell)).to_upper()).get_slice(" ", 0)
		City.Tile.CLIENT:
			return "%d" % _city.client_number_at(cell)
		City.Tile.WORKS:
			return "#"
	return ""


func _cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(Vector2(cell) * CELL_SIZE + Vector2.ONE * GRID_MARGIN, Vector2.ONE * CELL_SIZE)


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
