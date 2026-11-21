class_name BagView
extends BoxContainer
## The bag panel: the grid, the dish in hand with its buttons, the dishes set aside and the
## cup holder. Sends the player's actions as signals; GameScreen calls the core.
##
## Normally everything is stacked; in the compact layout (phones) the grid and its legend are
## on the left and the rest on the right, so that the whole bag fits in its tab.

signal column_clicked(column: int)
signal dish_clicked(order_id: int)
signal rotate_pressed
signal set_aside_pressed
signal cancel_pressed
signal aside_dish_clicked(order_id: int)

const SHAPE_CELL := 16.0

var game: Game

var _grid: BagGrid
var _status: Label
var _held_box: PanelContainer
var _held_shape: Control
var _held_text: Label
var _cancel_button: Button
var _aside_box: PanelContainer
var _aside_row: HFlowContainer
var _cup_holder: Label


func _init(compact: bool = false) -> void:
	var touch := Device.touch_screen()
	vertical = not compact
	add_theme_constant_override("separation", 12 if compact else 6)
	var grid_column := UiStyle.vbox(6)
	add_child(grid_column)
	var side := UiStyle.vbox(6)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(side)
	_grid = BagGrid.new()
	_grid.compact = compact
	_grid.column_clicked.connect(func(column: int) -> void: column_clicked.emit(column))
	_grid.dish_clicked.connect(func(order_id: int) -> void: dish_clicked.emit(order_id))
	_grid.hover_changed.connect(func(_column: int) -> void: _update_status())
	grid_column.add_child(_grid)

	var legend := UiStyle.hbox(10)
	legend.alignment = BoxContainer.ALIGNMENT_CENTER
	legend.add_child(UiStyle.label("● " + UiText.t("BAG_LEGEND_HOT"), UiStyle.SMALL_FONT_SIZE, UiStyle.HOT))
	legend.add_child(UiStyle.label("● " + UiText.t("BAG_LEGEND_COLD"), UiStyle.SMALL_FONT_SIZE, UiStyle.COLD))
	legend.add_child(UiStyle.label("▲ " + UiText.t("BAG_LEGEND_FRAGILE"), UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	legend.add_child(UiStyle.label("▢ " + UiText.t("BAG_LEGEND_LOOSE"), UiStyle.SMALL_FONT_SIZE, UiStyle.MUSTARD.darkened(0.2)))
	grid_column.add_child(legend)

	_status = UiStyle.paragraph("", UiStyle.SMALL_FONT_SIZE + (1 if compact else 0), UiStyle.MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if compact else HORIZONTAL_ALIGNMENT_CENTER
	side.add_child(_status)

	_held_box = PanelContainer.new()
	_held_box.add_theme_stylebox_override("panel", _dashed_box(UiStyle.MUSTARD))
	var held := UiStyle.vbox(6)
	_held_box.add_child(held)
	var held_top := UiStyle.hbox(10)
	_held_shape = Control.new()
	_held_shape.draw.connect(_draw_held)
	held_top.add_child(_held_shape)
	_held_text = UiStyle.paragraph("", UiStyle.SMALL_FONT_SIZE + 1)
	held_top.add_child(_held_text)
	held.add_child(held_top)
	var buttons := HFlowContainer.new()
	buttons.add_theme_constant_override("h_separation", 6)
	buttons.add_theme_constant_override("v_separation", 6)
	buttons.add_child(UiStyle.button(UiText.t("BAG_ROTATE_TOUCH" if touch else "BAG_ROTATE"), func() -> void: rotate_pressed.emit(), "SmallButton"))
	buttons.add_child(UiStyle.button(UiText.t("BAG_SET_ASIDE"), func() -> void: set_aside_pressed.emit(), "SmallButton"))
	_cancel_button = UiStyle.button("", func() -> void: cancel_pressed.emit(), "SmallButton")
	buttons.add_child(_cancel_button)
	held.add_child(buttons)
	side.add_child(_held_box)

	_aside_box = PanelContainer.new()
	_aside_box.theme_type_variation = "Inset"
	var aside := UiStyle.vbox(6)
	aside.add_child(UiStyle.paragraph(UiText.t("BAG_ASIDE_TITLE_TOUCH" if touch else "BAG_ASIDE_TITLE"),
			UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	_aside_row = HFlowContainer.new()
	_aside_row.add_theme_constant_override("h_separation", 6)
	_aside_row.add_theme_constant_override("v_separation", 6)
	aside.add_child(_aside_row)
	_aside_box.add_child(aside)
	side.add_child(_aside_box)

	_cup_holder = UiStyle.paragraph("", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	side.add_child(_cup_holder)


func refresh() -> void:
	_grid.game = game
	_grid.refresh()
	var state := game.state
	var bag := state.bag
	var playing := state.phase == GameState.Phase.PLAYING

	_held_box.visible = bag.held != null and playing
	if bag.held != null:
		var order := state.find_order(bag.held.order_id)
		var properties := PackedStringArray([UiText.t("TEMPERATURE_" + DishData.Temperature.keys()[bag.held.temperature()])])
		if bag.held.is_fragile():
			properties.append(UiText.t("BAG_FRAGILE"))
		_held_text.text = "#%d %s\n%s" % [order.id, UiText.dish_to_client(state, order.dish, order.client),
				" · ".join(properties)]
		# At least 3 × 3 so that turning a small dish does not move the text around.
		var shape_size := Vector2i(3, 3)
		for cell in bag.held.shape:
			shape_size = shape_size.max(cell + Vector2i.ONE)
		_held_shape.custom_minimum_size = Vector2(shape_size) * SHAPE_CELL
		_held_shape.queue_redraw()
		var origin := Bag.Origin.RESTAURANT if bag.held_returns_to_restaurant() else bag.held_origin
		_cancel_button.text = UiText.t("BAG_CANCEL_" + Bag.Origin.keys()[origin])

	UiStyle.clear(_aside_row)
	_aside_box.visible = not bag.aside_items().is_empty()
	for item in bag.aside_items():
		var button := UiStyle.button("#%d %s" % [item.order_id, UiText.name_of(item.dish)],
				_on_aside_pressed.bind(item.order_id), "SmallButton")
		var problem := game.take_from_aside_problem(item.order_id)
		button.disabled = problem != Game.Problem.NONE
		if problem != Game.Problem.NONE:
			button.tooltip_text = UiText.problem(problem)
		_aside_row.add_child(button)

	var cups := PackedStringArray()
	for item in bag.cup_holder_items():
		cups.append("#%d %s" % [item.order_id, UiText.name_of(item.dish)])
	_cup_holder.visible = bag.has_cup_holder
	_cup_holder.text = UiText.t("BAG_CUP_HOLDER") % (", ".join(cups) if not cups.is_empty() else "—")
	_update_status()


## Detail for the panel title: size and loose dishes.
func summary() -> String:
	var bag := game.state.bag
	var text := UiText.t("BAG_SIZE") % [bag.columns, bag.rows]
	var loose := 0
	for item in bag.loose_items():
		if not item.damaged:
			loose += 1
	if loose > 0:
		text += " · " + UiText.t("BAG_LOOSE_COUNT") % loose
	if bag.braced:
		text += " · " + UiText.t("BAG_BRACED")
	return text


## Shakes the bag (a card or a paved street shook it).
func shake() -> void:
	_grid.shake()


func _on_aside_pressed(order_id: int) -> void:
	aside_dish_clicked.emit(order_id)


## Under the bag: why the dish in hand cannot go in the hovered column, or what to do.
func _update_status() -> void:
	var bag := game.state.bag
	var column := _grid.hover_column()
	_status.remove_theme_color_override("font_color")
	_status.add_theme_color_override("font_color", UiStyle.MUTED)
	if bag.held != null and column >= 0:
		var problem := Game.BAG_PROBLEMS[bag.drop_problem(column)]
		if problem != Game.Problem.NONE:
			_status.add_theme_color_override("font_color", UiStyle.BAD)
			_status.text = UiText.problem(problem)
			return
	var touch := Device.touch_screen()
	if bag.held != null:
		_status.text = UiText.t("BAG_HINT_HELD_TOUCH" if touch else "BAG_HINT_HELD")
	elif not bag.items().is_empty():
		_status.text = UiText.t("BAG_HINT_LIFT_TOUCH" if touch else "BAG_HINT_LIFT")
	else:
		_status.text = UiText.t("BAG_EMPTY")


func _draw_held() -> void:
	var item := game.state.bag.held
	if item != null:
		BagGrid.draw_dish(_held_shape, item, item.shape, Vector2.ZERO, SHAPE_CELL, false)


static func _dashed_box(color: Color) -> StyleBoxFlat:
	var style := UiStyle.box(Color(color, 0.08), color, 2, UiStyle.RADIUS, 8)
	return style
