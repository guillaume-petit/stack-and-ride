class_name GameScreen
extends Control
## The game screen: runs one Game and shows it.
##
## The views only read the state and emit signals for what the player wants to do. This
## screen calls the matching action of Game, reports a refusal in the feed, then refreshes
## every view: simple and always in sync (the whole screen is cheap to rebuild).
##
## Layout: the top bar (with a hint for the next action); the map, the hand and the end-of-turn
## button on the left; the offers and accepted orders in the middle; the bag and the
## notifications on the right. The windows of the other phases (profile, end of night, shop,
## end of run) cover the board.
##
## Compact layout (phones, see Device): the map on the left, and on the right one tab each for
## the cards, the offers, the orders, the bag and the notifications, with the hint and the
## end-of-turn button under them. The screen opens the tab that the next action needs.

const MAIN_MENU := "res://ui/main.tscn"
const SIDE_WIDTH := 330
## Narrowest width of the tabs in the compact layout.
const COMPACT_TABS_WIDTH := 340
enum Tab { CARDS, OFFERS, ORDERS, BAG, FEED }
## Seeds tried in a row before giving up when no city can be drawn.
const MAX_SEED_ATTEMPTS := 100

## Seed of the run; a random one when negative. Set it before adding the screen to the tree.
var run_seed: int = -1
## Compact layout (phones). Chosen from the size of the screen in _ready(); the tests set it.
var compact: bool = false
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
## Compact layout only.
var _tabs: TabContainer
var _overlay: Control
var _overlay_center: CenterContainer
var _toast: Toast
## Last night whose accounts the player has seen (the window of the end of the night).
var _night_report_seen: int = 0
var _menu_open: bool = false
## What the compact layout last saw, to open the right tab when it changes.
var _seen_turn: int = -1
var _seen_held: bool = false
## Tab last opened by the screen (a TabContainer only shows it from the next frame).
var _opened_tab := Tab.CARDS
## History entries already shown as animations.
var _events_shown: int = 0
## Seconds the courier's ride lasts after the last move (what happens at the end waits for it).
var _ride_seconds: float = 0.0
## Kind of the window shown, to animate only a new one ("" when none).
var _dialog_kind: String = ""
## start() already ran (the tests call it before _ready()).
var _built: bool = false


func _ready() -> void:
	if not _built:
		# Already done by the main menu; needed when this scene is launched alone (F6).
		Device.apply_scale(get_window())
		compact = compact or Device.is_compact(get_viewport_rect().size)
		start()


## Builds the screen and starts a run. Called by _ready(); the tests call it directly, without
## adding the screen to the scene tree.
func start() -> void:
	_built = true
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
	# No city for this seed: try the next ones, but not forever (a broken configuration would
	# never give one).
	var attempts := 1
	while game == null and attempts < MAX_SEED_ATTEMPTS:
		seed_value += 1
		attempts += 1
		game = Game.new_run(content, seed_value)
	if game == null:
		push_error("No city could be drawn after %d seeds" % MAX_SEED_ATTEMPTS)
		return
	for view in [_hud, _city, _hand, _offers, _orders, _bag, _feed]:
		view.game = game
	_events_shown = game.state.history.size()
	refresh()


# --- Layout ---------------------------------------------------------------------------------

func _build() -> void:
	var background := ColorRect.new()
	background.color = UiStyle.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var sides := ["left", "top", "right", "bottom"]
	var safe := Device.safe_margins(get_viewport()) if is_inside_tree() else PackedFloat32Array([0, 0, 0, 0])
	for i in sides.size():
		margin.add_theme_constant_override("margin_" + sides[i], (8 if compact else 12) + int(safe[i]))
	add_child(margin)

	_make_views()
	if compact:
		margin.add_child(_compact_page())
	else:
		margin.add_child(_wide_page())

	# Windows over the board. They scroll when they are taller than the screen.
	_overlay = Control.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.BACKGROUND, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)
	var overlay_scroll := ScrollContainer.new()
	overlay_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_overlay.add_child(overlay_scroll)
	_overlay_center = CenterContainer.new()
	_overlay_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_overlay_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	overlay_scroll.add_child(_overlay_center)
	add_child(_overlay)

	_toast = Toast.new()
	add_child(_toast)


## The views, wired to the core; the layouts only place them.
func _make_views() -> void:
	_hud = HudBar.new(compact)
	_hud.menu_pressed.connect(_open_menu)
	_city = CityView.new()
	_city.crossroads_clicked.connect(_on_crossroads_clicked)
	_turn_info = UiStyle.label("", UiStyle.SMALL_FONT_SIZE + 1 if compact else UiStyle.FONT_SIZE, UiStyle.INK, true)
	_turn_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_end_turn = UiStyle.button("", _on_end_turn, "AccentButton")
	_hand = HandView.new(compact)
	_hand.card_clicked.connect(func(index: int) -> void: _after(game.play_card(index)))
	_offers = OffersView.new()
	_offers.accept_pressed.connect(func(id: int) -> void: _after(game.accept_offer(id)))
	_offers.offer_hovered.connect(_highlight)
	_orders = OrdersView.new()
	_orders.take_pressed.connect(func(id: int) -> void: _after(game.take_dish(id)))
	_orders.order_hovered.connect(_highlight)
	_bag = BagView.new(compact)
	_bag.column_clicked.connect(func(column: int) -> void: _after(game.drop_held(column)))
	_bag.dish_clicked.connect(func(id: int) -> void: _after(game.lift(id)))
	_bag.rotate_pressed.connect(func() -> void: _after(game.rotate_held()))
	_bag.set_aside_pressed.connect(func() -> void: _after(game.set_held_aside()))
	_bag.cancel_pressed.connect(func() -> void: _after(game.cancel_held()))
	_bag.aside_dish_clicked.connect(func(id: int) -> void: _after(game.take_from_aside(id)))
	_feed = FeedView.new()


func _map_panel() -> PanelContainer:
	var map_panel := PanelContainer.new()
	map_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_panel.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL, UiStyle.LINE, 1, 14, 0))
	map_panel.add_child(_city)
	return map_panel


func _wide_page() -> VBoxContainer:
	var page := UiStyle.vbox(10)
	page.add_child(_hud)
	var columns := UiStyle.hbox(12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)

	# Left: map, turn controls, hand.
	var left := UiStyle.vbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	left.add_child(_map_panel())
	var turn_row := UiStyle.hbox(10)
	turn_row.add_child(_turn_info)
	turn_row.add_child(_end_turn)
	left.add_child(turn_row)
	left.add_child(_hand)

	# Middle: offers and accepted orders.
	var middle := UiStyle.vbox(10)
	middle.custom_minimum_size.x = SIDE_WIDTH
	columns.add_child(middle)
	_offers_panel = UiStyle.titled_panel(UiText.t("OFFERS_TITLE"), _offers)
	_offers_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_offers_panel.size_flags_stretch_ratio = 1.15
	middle.add_child(_offers_panel)
	_orders_panel = UiStyle.titled_panel(UiText.t("ORDERS_TITLE"), _orders)
	_orders_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(_orders_panel)

	# Right: bag and notifications. It scrolls when a big bag, a dish in hand and dishes set
	# aside do not fit in the window.
	var right := UiStyle.vbox(10)
	right.custom_minimum_size.x = SIDE_WIDTH
	right.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var right_scroll := UiStyle.scroll(right)
	right_scroll.custom_minimum_size.x = SIDE_WIDTH
	columns.add_child(right_scroll)
	_bag_panel = UiStyle.titled_panel(UiText.t("BAG_TITLE"), _bag)
	right.add_child(_bag_panel)
	var feed_panel := UiStyle.titled_panel(UiText.t("FEED_TITLE"), _feed)
	feed_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feed_panel.custom_minimum_size.y = 150
	right.add_child(feed_panel)
	return page


func _compact_page() -> VBoxContainer:
	var page := UiStyle.vbox(6)
	page.add_child(_hud)
	var columns := UiStyle.hbox(8)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(columns)

	var left := UiStyle.vbox(4)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(_map_panel())
	left.add_child(_turn_info)
	columns.add_child(left)

	var right := UiStyle.vbox(6)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size.x = COMPACT_TABS_WIDTH
	columns.add_child(right)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_tabs)
	# Same order as the Tab enum.
	_tabs.add_child(_hand)
	_offers_panel = _tab_page(_offers)
	_tabs.add_child(_offers_panel)
	_orders_panel = _tab_page(_orders)
	_tabs.add_child(_orders_panel)
	_bag_panel = _tab_page(UiStyle.scroll(_bag))
	_tabs.add_child(_bag_panel)
	_tabs.add_child(_feed)
	var bottom := UiStyle.hbox(8)
	_hud.hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(_hud.hint)
	_end_turn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bottom.add_child(_end_turn)
	right.add_child(bottom)
	return page


## A tab with a detail line at its top (acceptance rate, bag size...).
func _tab_page(content: Control) -> PanelContainer:
	var page := PanelContainer.new()
	page.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var column := UiStyle.vbox(6)
	page.add_child(column)
	var detail := UiStyle.label("", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	detail.name = "Detail"
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(detail)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content)
	return page


# --- Refresh --------------------------------------------------------------------------------

## Shows the current state everywhere. Nothing to show when no run could start (see _start_run()).
func refresh() -> void:
	if game == null:
		return
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
	if compact:
		_refresh_tabs()
	_refresh_overlay()


## Tab titles with their counts, and the tab that the next action needs: the bag when a dish is
## taken, the orders or the cards once it is stowed, the offers at the start of a turn.
func _refresh_tabs() -> void:
	var state := game.state
	_tabs.set_tab_title(Tab.CARDS, UiText.t("TAB_CARDS") % state.piles.hand.size())
	_tabs.set_tab_title(Tab.OFFERS, UiText.t("TAB_OFFERS") % state.offers.size())
	_tabs.set_tab_title(Tab.ORDERS, UiText.t("TAB_ORDERS") % state.orders.size())
	_tabs.set_tab_title(Tab.BAG, UiText.t("TAB_BAG"))
	_tabs.set_tab_title(Tab.FEED, UiText.t("TAB_FEED"))
	if state.phase != GameState.Phase.PLAYING:
		return
	var held := state.bag.held != null
	var turn := state.night * 100 + state.turn
	if held and not _seen_held:
		_open_tab(Tab.BAG)
	elif not held and _seen_held and state.bag.aside_items().is_empty():
		_open_tab(Tab.ORDERS if _can_take_a_dish() else Tab.CARDS)
	elif turn != _seen_turn:
		var room := state.orders.size() < state.config.max_active_orders
		_open_tab(Tab.OFFERS if room and not state.offers.is_empty() else Tab.CARDS)
	_seen_held = held
	_seen_turn = turn


func _open_tab(tab: Tab) -> void:
	_opened_tab = tab
	_tabs.current_tab = tab


func _can_take_a_dish() -> bool:
	for order in game.state.orders:
		if game.take_dish_problem(order.id) == Game.Problem.NONE:
			return true
	return false


func _set_detail(panel: Control, text: String) -> void:
	(panel.find_child("Detail", true, false) as Label).text = text


## What to do next, for a new player.
func _hint_text() -> String:
	var state := game.state
	var bag := state.bag
	var touch := Device.touch_screen()
	if state.phase != GameState.Phase.PLAYING:
		return ""
	if bag.held != null:
		return UiText.t("HINT_HELD_TOUCH" if touch else "HINT_HELD")
	if not bag.aside_items().is_empty():
		for item in bag.aside_items():
			if bag.can_return_from_aside(item.order_id):
				return UiText.t("HINT_ASIDE_RETURN")
		return UiText.t("HINT_ASIDE")
	if _can_take_a_dish():
		return UiText.t("HINT_AT_RESTAURANT")
	if state.orders.is_empty() and not state.offers.is_empty():
		return UiText.t("HINT_ACCEPT_TOUCH" if touch else "HINT_ACCEPT")
	if state.steps > 0:
		return UiText.t("HINT_MOVE_TOUCH" if touch else "HINT_MOVE")
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
	var kind := ""
	if dialog != null:
		dialog.compact = compact
		if dialog.game == null:
			dialog.setup(game)
		_overlay_center.add_child(dialog)
		kind = "menu" if _menu_open else dialog.get_script().get_global_name()
		if kind != _dialog_kind:
			Motion.appear(dialog)
	_dialog_kind = kind


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

## After every action: a refusal goes to the feed and pops up, what happened is animated, then
## everything is shown again.
func _after(problem: Game.Problem) -> void:
	if problem != Game.Problem.NONE:
		_feed.add_problem(problem)
		_toast.show_text(UiText.problem(problem))
	_show_events()
	_ride_seconds = 0.0
	refresh()


## Animates the events of the history since the last action: money that rises from the client's
## door, a bag that shakes...
func _show_events() -> void:
	var state := game.state
	for index in range(_events_shown, state.history.size()):
		var event := state.history[index]
		match event.kind:
			GameEvent.Kind.DELIVERED:
				var delivery := event.delivery
				var text := "+" + UiText.euros(delivery.total())
				if delivery.rating_tenths != 0:
					text += "  " + UiText.stars_change(delivery.rating_tenths) + " ★"
				var good := delivery.outcome == Delivery.Outcome.PERFECT
				_city.float_text(event.order.client, text, UiStyle.OK if good else UiStyle.BAD, _ride_seconds)
			GameEvent.Kind.CANCELLED:
				_city.float_text(event.order.client, UiText.stars_change(event.rating_tenths) + " ★", UiStyle.BAD)
			GameEvent.Kind.CARD_RATING_COST:
				_city.float_text(state.courier_position, UiText.stars_change(event.rating_tenths) + " ★", UiStyle.BAD)
			GameEvent.Kind.SHAKE, GameEvent.Kind.CRUSHED:
				if not event.braced:
					_bag.shake()
	_events_shown = state.history.size()


func _on_crossroads_clicked(crossroads: Vector2i) -> void:
	if crossroads == game.state.courier_position:
		return
	var path: Array[Vector2i] = [game.state.courier_position]
	path.append_array(game.paths().path_to(crossroads))
	var problem := game.move_to(crossroads)
	if problem == Game.Problem.NONE:
		_city.ride(path)
		_ride_seconds = CityView.ride_seconds(path.size() - 1)
	_after(problem)


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


## The back button of Android (or gesture): puts back the dish in hand, closes the menu or opens
## it. Without this, Godot would quit the game (project setting application/config/quit_on_go_back).
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or game == null:
		return
	if _menu_open:
		_menu_open = false
		refresh()
	elif game.state.bag.held != null and not _overlay.visible:
		_after(game.cancel_held())
	else:
		_open_menu()


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
