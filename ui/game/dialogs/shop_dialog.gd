class_name ShopDialog
extends Dialog
## The shop between two nights (§10), with tomorrow's rent and event to weigh each purchase.

signal buy_pressed(index: int)
signal next_night_pressed

## Approximate height of an item, and the most the list takes before it scrolls.
const ITEM_HEIGHT := 62
const LIST_HEIGHT := 340
const COMPACT_LIST_HEIGHT := 300
const WIDTH := 620
const COMPACT_WIDTH := 720
const COMPACT_SIDE_WIDTH := 250


func setup(p_game: Game) -> void:
	super(p_game)
	custom_minimum_size.x = COMPACT_WIDTH if compact else WIDTH
	var state := game.state
	add_title(UiText.t("SHOP_TITLE"))
	# Normally everything is stacked; on a phone the list goes on the right, to fit the height.
	var side: BoxContainer = body
	var list_parent: BoxContainer = body
	if compact:
		var columns := UiStyle.hbox(14)
		body.add_child(columns)
		side = UiStyle.vbox(12)
		side.custom_minimum_size.x = COMPACT_SIDE_WIDTH
		columns.add_child(side)
		list_parent = columns
	side.add_child(UiStyle.paragraph(UiText.t("SHOP_INTRO") % [UiText.euros(state.wallet), UiText.euros(state.rent_tomorrow())]))

	var event: EventData = state.content.events[state.next_event]
	var announce := PanelContainer.new()
	announce.add_theme_stylebox_override("panel", UiStyle.box(Color(UiStyle.ACCENT, 0.06), UiStyle.ACCENT, 2, UiStyle.RADIUS, 8))
	var column := UiStyle.vbox(2)
	column.add_child(UiStyle.label(UiText.t("SHOP_TOMORROW").to_upper(), 10, UiStyle.ACCENT, true))
	column.add_child(UiStyle.label(UiText.name_of(event), UiStyle.TITLE_FONT_SIZE - 2, UiStyle.INK, true))
	column.add_child(UiStyle.paragraph(UiText.description_of(event), UiStyle.SMALL_FONT_SIZE + 1, UiStyle.MUTED))
	announce.add_child(column)
	side.add_child(announce)

	var list := UiStyle.vbox(6)
	for index in state.shop.items.size():
		list.add_child(_item(index))
	var area := UiStyle.scroll(list)
	area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	area.custom_minimum_size.y = mini(state.shop.items.size() * ITEM_HEIGHT, COMPACT_LIST_HEIGHT if compact else LIST_HEIGHT)
	list_parent.add_child(area)

	var owned := UiStyle.paragraph(UiText.t("SHOP_OWNED") % [state.deck.size(), state.bag.columns, state.bag.rows],
			UiStyle.FONT_SIZE, UiStyle.MUTED)
	var next := UiStyle.button(UiText.t("SHOP_NEXT_NIGHT") % (state.night + 1),
			func() -> void: next_night_pressed.emit(), "AccentButton")
	if compact:
		side.add_child(owned)
		next.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		side.add_child(next)
	else:
		body.add_child(owned)
		add_buttons([next])


func _item(index: int) -> PanelContainer:
	var state := game.state
	var item := state.shop.items[index]
	var data := UiText.reward_content(item.reward, state.content)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL, UiStyle.LINE, 2, UiStyle.RADIUS, 8))
	var row := UiStyle.hbox(10)
	var text := UiStyle.vbox(1)
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(UiStyle.label(UiText.reward_kind(item.reward).to_upper(), 10, UiStyle.ACCENT, true))
	text.add_child(UiStyle.label(UiText.name_of(data), UiStyle.FONT_SIZE, UiStyle.INK, true))
	text.add_child(UiStyle.paragraph(UiText.description_of(data), UiStyle.SMALL_FONT_SIZE + 1, UiStyle.MUTED))
	row.add_child(text)
	var label := UiText.t("SHOP_SOLD") if item.sold else UiText.euros(item.price)
	var buy := UiStyle.button(label, func() -> void: buy_pressed.emit(index), "SmallButton" if item.sold else "YesButton")
	buy.custom_minimum_size.x = 76
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var problem := game.buy_problem(index)
	buy.disabled = problem != Game.Problem.NONE
	if problem != Game.Problem.NONE and not item.sold:
		buy.tooltip_text = UiText.problem(problem)
	row.add_child(buy)
	panel.add_child(row)
	return panel
