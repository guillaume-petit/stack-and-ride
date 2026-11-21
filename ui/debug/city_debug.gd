extends Control
## Throwaway debug screen for iteration 1: draws a generated city (streets, blocks and
## buildings) and the shortest path from the base to the clicked crossroads. Not part of the game
## (the real map is ui/game/city_view.gd); kept to check a seed or a city layout quickly.
##
## Open ui/debug/city_debug.tscn in the editor and press F6 (run the current scene).

## Distance between two crossroads on screen.
const SPACING := 120
const MAP_MARGIN := 36
const STREET_WIDTH := 16.0
const BACKGROUND := Color("#eceff3")
const INK := Color("#1a1e24")
const MUTED := Color("#5d6570")
const PATH_COLOR := Color("#e2452b")
const BLOCK_COLOR := Color("#cfd6de")
const STREET_COLORS := {
	City.Street.NORMAL: Color("#ffffff"),
	City.Street.PAVED: Color("#a99f90"),
	City.Street.WORKS: Color("#f0a020"),
}
const PLACE_COLORS := {
	City.Place.BASE: Color("#1a1e24"),
	City.Place.RESTAURANT: Color("#2f7fc4"),
	City.Place.CLIENT: Color("#23935a"),
}

var _content: GameContent
var _city: City
var _seed: int = 1
## Clicked crossroads, or City.NOWHERE when nothing is selected.
var _target := City.NOWHERE

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
	row.offset_right = -MAP_MARGIN
	row.offset_top = MAP_MARGIN
	row.add_theme_constant_override("separation", MAP_MARGIN)
	add_child(row)

	# The map is a plain Control whose drawing and clicks are handled here.
	_map = Control.new()
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
	var city := City.generate(_content.config, _content.restaurant_ids(), GameRng.new(_seed))
	if city == null:
		# The previous city (if any) stays on screen.
		_info.text = tr("DEBUG_CITY_NO_VALID_CITY") % _seed
		return
	_city = city
	_target = City.NOWHERE
	# Sized here rather than while drawing: changing it in the draw callback relayouts the screen.
	_map.custom_minimum_size = Vector2((_city.columns - 1) * SPACING, (_city.rows - 1) * SPACING) \
			+ Vector2.ONE * MAP_MARGIN * 2
	_refresh()


func _relocate_works() -> void:
	if _city == null:
		return
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
	if _target == City.NOWHERE:
		return connected + "\n" + tr("DEBUG_CITY_CLICK_HINT")
	var distance := _city.distance(_city.base, _target, _cross_works.button_pressed)
	var where := "(%d, %d)" % [_target.x, _target.y]
	if distance < 0:
		return connected + "\n" + tr("DEBUG_CITY_UNREACHABLE") % where
	return connected + "\n" + tr("DEBUG_CITY_DISTANCE") % [where, distance]


func _on_map_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if _city == null or click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	# Nearest crossroads to the click.
	var crossroads := Vector2i(((click.position - Vector2.ONE * MAP_MARGIN) / SPACING).round())
	if _city.is_inside(crossroads):
		_target = crossroads
		_refresh()


func _draw_map() -> void:
	if _city == null:
		return
	# Blocks first, then the streets over their edges, then the buildings in the block corners.
	_map.draw_rect(Rect2(_point(Vector2i.ZERO), Vector2((_city.columns - 1) * SPACING, (_city.rows - 1) * SPACING)),
			BLOCK_COLOR)
	for street in [City.Street.NORMAL, City.Street.PAVED, City.Street.WORKS]:
		for key in _city.streets_of(street):
			_draw_street(key, street)
	for y in _city.rows:
		for x in _city.columns:
			_map.draw_circle(_point(Vector2i(x, y)), STREET_WIDTH / 2, STREET_COLORS[City.Street.NORMAL])
	if _target != City.NOWHERE:
		var points := PackedVector2Array([_point(_city.base)])
		for crossroads in _city.paths_from(_city.base, _cross_works.button_pressed).path_to(_target):
			points.append(_point(crossroads))
		if points.size() > 1:
			_map.draw_polyline(points, PATH_COLOR, 6.0, true)
		_map.draw_arc(_point(_target), STREET_WIDTH * 0.8, 0, TAU, 32, PATH_COLOR, 4.0, true)
	for place in [City.Place.BASE, City.Place.RESTAURANT, City.Place.CLIENT]:
		for crossroads in _city.crossroads_with(place):
			_draw_building(crossroads, place)


func _draw_street(key: Vector4i, street: City.Street) -> void:
	var ends := City.street_ends(key)
	var from := _point(ends[0])
	var to := _point(ends[1])
	_map.draw_line(from, to, STREET_COLORS[street], STREET_WIDTH)
	if street == City.Street.WORKS:
		# A barrier across the middle of the street.
		var middle := (from + to) / 2
		var across := (to - from).normalized().orthogonal() * STREET_WIDTH * 0.7
		_map.draw_line(middle - across, middle + across, INK, 4.0)
	elif street == City.Street.PAVED:
		# Cobbles: a row of dots along the street.
		for i in range(1, 8):
			_map.draw_circle(from.lerp(to, i / 8.0), 2.5, INK.lerp(STREET_COLORS[street], 0.5))


## The building takes the corner of its block that touches its crossroads, with a "door"
## line to the crossroads.
func _draw_building(crossroads: Vector2i, place: City.Place) -> void:
	var block := _city.building_block(crossroads)
	if block == City.NOWHERE:
		return
	var corner := _point(crossroads)
	var block_center := _point(block) + Vector2.ONE * SPACING / 2
	var gap := STREET_WIDTH / 2 + 2
	var toward := (block_center - corner).sign()
	var near := corner + toward * gap
	var far := block_center - toward * 2
	var rect := Rect2(near, Vector2.ZERO).expand(far)
	var color: Color = PLACE_COLORS[place]
	_map.draw_line(corner, near, color, 4.0)
	_map.draw_rect(rect, color)
	var text := _place_text(crossroads, place)
	var font := ThemeDB.fallback_font
	var font_size := 13
	var baseline := rect.position.y + rect.size.y / 2 + font_size * 0.35
	_map.draw_string(font, Vector2(rect.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER,
			rect.size.x, font_size, Color.WHITE)


func _place_text(crossroads: Vector2i, place: City.Place) -> String:
	match place:
		City.Place.BASE:
			return tr("DEBUG_CITY_BASE")
		City.Place.RESTAURANT:
			# Restaurant names are long: show the first word only.
			return tr("RESTAURANT_" + String(_city.restaurant_kind_at(crossroads)).to_upper()).get_slice(" ", 0)
		City.Place.CLIENT:
			return "%d" % _city.client_number_at(crossroads)
	return ""


func _point(crossroads: Vector2i) -> Vector2:
	return Vector2(crossroads) * SPACING + Vector2.ONE * MAP_MARGIN


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
