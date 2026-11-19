class_name OffersView
extends VBoxContainer
## The offers of the app, with the acceptance rate. Hovering an offer shows its restaurant and
## clients on the map (offer_hovered); the Accepter button emits accept_pressed.

signal accept_pressed(offer_id: int)
## Crossroads of the hovered offer, empty when the mouse leaves it.
signal offer_hovered(crossroads: Array[Vector2i])

var game: Game

var _rate: ProgressBar
var _list: VBoxContainer


func _init() -> void:
	add_theme_constant_override("separation", 8)
	_rate = ProgressBar.new()
	_rate.show_percentage = false
	_rate.custom_minimum_size.y = 6
	_rate.max_value = 100
	add_child(_rate)
	_list = UiStyle.vbox(6)
	var area := UiStyle.scroll(_list)
	area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(area)


func summary() -> String:
	return UiText.t("OFFERS_ACCEPTANCE") % game.state.acceptance


func refresh() -> void:
	var state := game.state
	_rate.value = state.acceptance
	var low := state.acceptance < state.config.vip_min_acceptance
	_rate.add_theme_stylebox_override("fill", UiStyle.box(UiStyle.BAD if low else UiStyle.OK, UiStyle.OK, 0, 3, 0))
	UiStyle.clear(_list)
	var from_here := game.paths()
	if state.offers.is_empty():
		_list.add_child(UiStyle.paragraph(UiText.t("OFFERS_EMPTY"), UiStyle.SMALL_FONT_SIZE + 1, UiStyle.MUTED))
	for offer in state.offers:
		_list.add_child(_offer(offer, from_here.distance_to(offer.restaurant)))


## distance: steps from the courier to the restaurant, -1 when it cannot be reached.
func _offer(offer: Offer, distance: int) -> PanelContainer:
	var state := game.state
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL, UiStyle.MUSTARD, 2, UiStyle.RADIUS, 8))
	var column := UiStyle.vbox(4)
	panel.add_child(column)

	var total := 0
	var deadline := 999
	var places: Array[Vector2i] = [offer.restaurant]
	for part in offer.parts:
		total += part.pay
		deadline = mini(deadline, part.deadline)
		places.append(part.client)
	var top := UiStyle.hbox(8)
	var restaurant := UiStyle.label(UiText.restaurant_at(state, offer.restaurant), UiStyle.FONT_SIZE - 1, UiStyle.INK, true)
	restaurant.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(restaurant)
	top.add_child(UiStyle.label(UiText.t("OFFER_PAY_AND_TIME") % [UiText.euros(total), deadline],
			UiStyle.FONT_SIZE - 1, UiStyle.INK, true))
	column.add_child(top)

	for part in offer.parts:
		column.add_child(UiStyle.paragraph(UiText.dish_to_client(state, part.dish, part.client),
				UiStyle.SMALL_FONT_SIZE + 1, UiStyle.MUTED))
	var chips := UiText.modifier_chips(offer.modifiers)
	if not chips.is_empty():
		var chip_row := HFlowContainer.new()
		chip_row.add_theme_constant_override("h_separation", 4)
		chip_row.add_theme_constant_override("v_separation", 4)
		for chip: Array in chips:
			chip_row.add_child(UiStyle.chip(chip[0], chip[1], UiStyle.INK if chip[1] == UiStyle.MUSTARD else Color.WHITE))
		column.add_child(chip_row)
	var bottom := UiStyle.hbox(6)
	var where := ""
	if distance == 0:
		where = UiText.t("OFFER_HERE")
	elif distance > 0:
		where = UiText.t("OFFER_DISTANCE") % distance
	var spacer := UiStyle.label(where, UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	var accept := UiStyle.button(UiText.t("OFFER_ACCEPT"), func() -> void: accept_pressed.emit(offer.id), "YesButton")
	var problem := game.offer_problem(offer.id)
	accept.disabled = problem != Game.Problem.NONE
	if problem != Game.Problem.NONE:
		accept.tooltip_text = UiText.problem(problem)
	bottom.add_child(accept)
	column.add_child(bottom)

	panel.mouse_entered.connect(func() -> void: offer_hovered.emit(places))
	panel.mouse_exited.connect(func() -> void: offer_hovered.emit([] as Array[Vector2i]))
	return panel
