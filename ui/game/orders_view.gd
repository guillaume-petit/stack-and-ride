class_name OrdersView
extends VBoxContainer
## The accepted orders: where each dish is, the turns left, and a button to take the dish when
## the courier is at its restaurant.

signal take_pressed(order_id: int)
## Crossroads of the hovered order (restaurant or client), empty when the mouse leaves it.
signal order_hovered(crossroads: Array[Vector2i])

var game: Game

var _list: VBoxContainer


func _init() -> void:
	_list = UiStyle.vbox(6)
	var area := UiStyle.scroll(_list)
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(area)


func summary() -> String:
	return UiText.t("ORDERS_COUNT") % [game.state.orders.size(), game.state.config.max_active_orders]


func refresh() -> void:
	UiStyle.clear(_list)
	if game.state.orders.is_empty():
		_list.add_child(UiStyle.paragraph(UiText.t("ORDERS_EMPTY"), UiStyle.SMALL_FONT_SIZE + 1, UiStyle.MUTED))
	for order in game.state.orders:
		_list.add_child(_order(order))


func _order(order: Order) -> PanelContainer:
	var state := game.state
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL, UiStyle.LINE, 1, UiStyle.RADIUS, 7))
	var row := UiStyle.hbox(8)
	panel.add_child(row)

	var pin := PanelContainer.new()
	var color := UiStyle.order_color(order.id)
	pin.add_theme_stylebox_override("panel", UiStyle.box(color, Color.WHITE, 2, 12, 2))
	pin.custom_minimum_size = Vector2(24, 24)
	pin.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var number := UiStyle.label(str(order.id), UiStyle.SMALL_FONT_SIZE, Color.WHITE, true)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pin.add_child(number)
	row.add_child(pin)

	var middle := UiStyle.vbox(2)
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(UiStyle.label(UiText.dish_to_client(state, order.dish, order.client), UiStyle.FONT_SIZE - 1, UiStyle.INK, true))
	middle.add_child(UiStyle.paragraph("%s · %s" % [UiText.order_status(state, order), UiText.euros(order.pay)],
			UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED))
	var chips := UiText.modifier_chips(order.modifiers)
	if not chips.is_empty():
		var chip_row := UiStyle.hbox(4)
		for chip: Array in chips:
			chip_row.add_child(UiStyle.chip(chip[0], chip[1], UiStyle.INK if chip[1] == UiStyle.MUSTARD else Color.WHITE))
		middle.add_child(chip_row)
	if game.take_dish_problem(order.id) == Game.Problem.NONE:
		var take := UiStyle.button(UiText.t("ORDER_TAKE"), func() -> void: take_pressed.emit(order.id), "YesButton")
		take.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		middle.add_child(take)
	row.add_child(middle)

	row.add_child(_timer(order))
	var place := order.client if order.picked_up else order.restaurant
	panel.mouse_entered.connect(func() -> void: order_hovered.emit([place] as Array[Vector2i]))
	panel.mouse_exited.connect(func() -> void: order_hovered.emit([] as Array[Vector2i]))
	return panel


## Turns left, red when it is the last one, black when late.
func _timer(order: Order) -> PanelContainer:
	var color := UiStyle.ROAD
	var text_color := UiStyle.INK
	var text := UiText.t("ORDER_TURNS_LEFT") % order.deadline
	if order.is_late():
		color = UiStyle.INK
		text_color = Color.WHITE
		text = UiText.t("ORDER_LATE")
	elif order.deadline <= 1:
		color = UiStyle.BAD
		text_color = Color.WHITE
	var chip := PanelContainer.new()
	var style := UiStyle.box(color, color, 0, 9, 0)
	style.content_margin_left = 8
	style.content_margin_right = 8
	chip.add_theme_stylebox_override("panel", style)
	chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	chip.add_child(UiStyle.label(text, UiStyle.SMALL_FONT_SIZE + 1, text_color, true))
	return chip
