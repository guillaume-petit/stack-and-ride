class_name GameScreen
extends Control
## The game screen: runs one Game and shows it.
##
## The views only read the state and emit signals for what the player wants to do. This
## screen calls the matching action of Game, reports a refusal in the feed, then refreshes
## every view: simple and always in sync (the whole screen is cheap to rebuild).
##
## Layout: the top bar (with a hint for the next action); the map, the hand and the end-of-turn button on the left; the offers
## and accepted orders in the middle; the bag and the notifications on the right. The windows
## of the other phases (profile, end of night, shop, end of run) cover the board.

const MAIN_MENU := "res://ui/main.tscn"
const SIDE_WIDTH := 330

## Seed of the run; a random one when negative. Set it before adding the screen to the tree.
var run_seed: int = -1
var game: Game

var _hud: HudBar
var _city: CityView
var _turn_info: Label
var _end_turn: Button
var _hand: HandView
var _offers: OffersView
var _offers_panel: PanelContainer
var _orders: OrdersView
var _orders_panel: PanelContainer
var _bag: BagView
var _bag_panel: PanelContainer
var _feed: FeedView
var _overlay: Control
var _overlay_center: CenterContainer
## Last night whose accounts the player has seen (the window of the end of the night).
var _night_report_seen: int = 0
var _menu_open: bool = false


func _ready() -> void:
	if game == null:
		start()


## Builds the screen and starts a run. Called by _ready(); the tests call it directly, without
## adding the screen to the scene tree.
func start() -> void:
	theme = UiStyle.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	_start_run()


func _start_run() -> void:
	var content := GameContent.load_from()
	var problems := content.validate()
	if not problems.is_empty():
		push_error("Content problems:\n" + "\n".join(problems))
	# The interface may use the global random numbers: only the rules need a seeded GameRng.
	var seed_value := run_seed if run_seed >= 0 else randi()
	game = Game.new_run(content, seed_value)
	while game == null:
		seed_value += 1
		game = Game.new_run(content, seed_value)
	for view in [_hud, _city, _hand, _offers, _orders, _bag, _feed]:
		view.game = game
	refresh()


# --- Layout ---------------------------------------------------------------------------------

func _build() -> void:
	var background := ColorRect.new()
	background.color = UiStyle.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	add_child(margin)
	var page := UiStyle.vbox(10)
	margin.add_child(page)

	_hud = HudBar.new()
	_hud.menu_pressed.connect(_open_menu)
	page.add_child(_hud)

	var columns := UiStyle.hbox(12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)

	# Left: map, turn controls, hand.
	var left := UiStyle.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	var map_panel := PanelContainer.new()
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL, UiStyle.LINE, 1, 14, 0))
	_city = CityView.new()
	_city.crossroads_clicked.connect(_on_crossroads_clicked)
	map_panel.add_child(_city)
	left.add_child(map_panel)
	var turn_row := UiStyle.hbox(10)
	_turn_info = UiStyle.label("", UiStyle.FONT_SIZE, UiStyle.INK, true)
	_turn_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turn_row.add_child(_turn_info)
	_end_turn = UiStyle.button("", _on_end_turn, "AccentButton")
	turn_row.add_child(_end_turn)
	left.add_child(turn_row)
	_hand = HandView.new()
	_hand.card_clicked.connect(func(index: int) -> void: _after(game.play_card(index)))
	left.add_child(_hand)

	# Middle: offers and accepted orders.
	var middle := UiStyle.vbox(10)
	middle.custom_minimum_size.x = SIDE_WIDTH
	columns.add_child(middle)
	_offers = OffersView.new()
	_offers.accept_pressed.connect(func(id: int) -> void: _after(game.accept_offer(id)))
	_offers.offer_hovered.connect(_highlight)
	_offers_panel = UiStyle.titled_panel(UiText.t("OFFERS_TITLE"), _offers)
	_offers_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_offers_panel.size_flags_stretch_ratio = 1.15
	middle.add_child(_offers_panel)
	_orders = OrdersView.new()
	_orders.take_pressed.connect(func(id: int) -> void: _after(game.take_dish(id)))
	_orders.order_hovered.connect(_highlight)
	_orders_panel = UiStyle.titled_panel(UiText.t("ORDERS_TITLE"), _orders)
	_orders_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(_orders_panel)

	# Right: bag and notifications.
	var right := UiStyle.vbox(10)
	right.custom_minimum_size.x = SIDE_WIDTH
	columns.add_child(right)
	_bag = BagView.new()
	_bag.column_clicked.connect(func(column: int) -> void: _after(game.drop_held(column)))
	_bag.dish_clicked.connect(func(id: int) -> void: _after(game.lift(id)))
	_bag.rotate_pressed.connect(func() -> void: _after(game.rotate_held()))
	_bag.set_aside_pressed.connect(func() -> void: _after(game.set_held_aside()))
	_bag.cancel_pressed.connect(func() -> void: _after(game.cancel_held()))
	_bag.aside_dish_clicked.connect(func(id: int) -> void: _after(game.take_from_aside(id)))
	_bag_panel = UiStyle.titled_panel(UiText.t("BAG_TITLE"), _bag)
	right.add_child(_bag_panel)
	_feed = FeedView.new()
	var feed_panel := UiStyle.titled_panel(UiText.t("FEED_TITLE"), _feed)
	feed_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(feed_panel)

	# Windows over the board.
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.BACKGROUND, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	_overlay_center = CenterContainer.new()
	_overlay_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(_overlay_center)
	add_child(_overlay)


# --- Refresh --------------------------------------------------------------------------------

## Shows the current state everywhere.
func refresh() -> void:
	var state := game.state
	_city.highlighted = []
	for view in [_hud, _city, _hand, _offers, _orders, _bag, _feed]:
		view.refresh()
	_set_detail(_offers_panel, _offers.summary())
	_set_detail(_orders_panel, _orders.summary())
	_set_detail(_bag_panel, _bag.summary())

	var flags := PackedStringArray([UiText.t("TURN_STEPS") % state.steps,
			UiText.t("TURN_CARDS") % [state.paid_cards_played, state.max_paid_cards()],
			UiText.t("TURN_DRAW_PILE") % state.piles.draw_pile.size()])
	if state.crossing_works:
		flags.append(UiText.t("TURN_CROSSING_WORKS"))
	_turn_info.text = " · ".join(flags)
	var last_turn := state.turn >= state.config.turns_per_night
	_end_turn.text = UiText.t("TURN_END_NIGHT" if last_turn else "TURN_END")
	var problem := game.end_turn_problem()
	_end_turn.disabled = problem != Game.Problem.NONE
	_end_turn.tooltip_text = UiText.problem(problem) if problem != Game.Problem.NONE else ""
	_hud.hint.text = _hint_text()
	_refresh_overlay()


func _set_detail(panel: PanelContainer, text: String) -> void:
	(panel.find_child("Detail", true, false) as Label).text = text


## What to do next, for a new player.
func _hint_text() -> String:
	var state := game.state
	var bag := state.bag
	if state.phase != GameState.Phase.PLAYING:
		return ""
	if bag.held != null:
		return UiText.t("HINT_HELD")
	if not bag.aside_items().is_empty():
		return UiText.t("HINT_ASIDE")
	for order in state.orders:
		if game.take_dish_problem(order.id) == Game.Problem.NONE:
			return UiText.t("HINT_AT_RESTAURANT")
	if state.steps > 0:
		return UiText.t("HINT_MOVE")
	if state.orders.is_empty() and not state.offers.is_empty():
		return UiText.t("HINT_ACCEPT")
	return UiText.t("HINT_PLAY_CARDS") % state.max_paid_cards()


## The window of the current phase, if any.
func _refresh_overlay() -> void:
	UiStyle.clear(_overlay_center)
	var state := game.state
	var dialog: Dialog = null
	if _menu_open:
		dialog = _menu_dialog()
	else:
		match state.phase:
			GameState.Phase.CHOOSE_PROFILE:
				var profiles := ProfileDialog.new()
				profiles.profile_chosen.connect(func(id: StringName) -> void: _after(game.choose_profile(id)))
				dialog = profiles
			GameState.Phase.CHOOSING_REWARD:
				dialog = _night_dialog()
			GameState.Phase.SHOPPING:
				if state.night_summaries.back().night > _night_report_seen:
					dialog = _night_dialog()
				else:
					var shop := ShopDialog.new()
					shop.buy_pressed.connect(func(index: int) -> void: _after(game.buy(index)))
					shop.next_night_pressed.connect(func() -> void: _after(game.start_next_night()))
					dialog = shop
			GameState.Phase.WON, GameState.Phase.LOST:
				var end := RunEndDialog.new()
				end.new_run_pressed.connect(_new_run)
				end.menu_pressed.connect(_to_main_menu)
				dialog = end
	_overlay.visible = dialog != null
	if dialog != null:
		if dialog.game == null:
			dialog.setup(game)
		_overlay_center.add_child(dialog)


func _night_dialog() -> NightDialog:
	var night := NightDialog.new()
	var summary: NightSummary = game.state.night_summaries.back()
	night.reward_chosen.connect(func(index: int) -> void:
		_night_report_seen = summary.night
		_after(game.choose_reward(index)))
	night.continue_pressed.connect(func() -> void:
		_night_report_seen = summary.night
		refresh())
	return night


## Leaving the run: it is not saved yet (iteration 6), so the player confirms.
func _menu_dialog() -> Dialog:
	var menu := Dialog.new()
	menu.setup(game)
	menu.custom_minimum_size.x = 420
	menu.add_title(UiText.t("MENU_LEAVE_TITLE"))
	menu.add_text(UiText.t("MENU_LEAVE_TEXT"), UiStyle.MUTED)
	menu.add_buttons([
		UiStyle.button(UiText.t("MENU_LEAVE_CONFIRM"), _to_main_menu),
		UiStyle.button(UiText.t("MENU_LEAVE_CANCEL"), func() -> void:
			_menu_open = false
			refresh(), "AccentButton"),
	])
	return menu


# --- Actions --------------------------------------------------------------------------------

## After every action: a refusal goes to the feed, then everything is shown again.
func _after(problem: Game.Problem) -> void:
	if problem != Game.Problem.NONE:
		_feed.add_problem(problem)
	refresh()


func _on_crossroads_clicked(crossroads: Vector2i) -> void:
	if crossroads == game.state.courier_position:
		return
	_after(game.move_to(crossroads))


func _on_end_turn() -> void:
	_after(game.end_turn())


func _highlight(crossroads: Array[Vector2i]) -> void:
	_city.highlighted = crossroads
	_city.refresh()


func _open_menu() -> void:
	_menu_open = true
	refresh()


func _new_run() -> void:
	get_tree().reload_current_scene()


func _to_main_menu() -> void:
	get_tree().change_scene_to_file(MAIN_MENU)


## Keyboard shortcuts while a dish is in hand: R turns it, Escape puts it back.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or game == null or _overlay.visible:
		return
	if game.state.bag.held == null:
		return
	if key.keycode == KEY_R:
		_after(game.rotate_held())
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE:
		_after(game.cancel_held())
		get_viewport().set_input_as_handled()
