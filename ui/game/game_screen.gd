class_name GameScreen
extends Control
## The game screen: runs one Game and shows it as a board.
##
## The views only read the state and emit signals for what the player wants to do. This
## screen calls the matching action of Game, reports a refusal, then refreshes every view:
## simple and always in sync (the whole screen is cheap to rebuild).
##
## The map fills the screen; the rest floats over it:
## - at the top, the bar of counters;
## - at the bottom, the icons of the app, the bag and the history, the end-of-turn button (with
##   the cards of the turn) and the hand;
## - over the map, a button to take a dish by the courier, the snack bar of the messages and
##   help bubbles pointing at what to use next;
## - in the middle, the window of the app (offers and orders), of the bag or of the history;
## - over everything, the windows of the other phases (profile, end of night, shop, end of run).
##
## On a phone held upright the map is drawn turned to fill the width (CityView), the hand sits
## under the buttons, and the top bar keeps to one line (narrow).

const MAIN_MENU := "res://ui/main.tscn"
## The windows over the map, opened by the icons at the bottom.
enum Pane { NONE, APP, BAG, HISTORY }
## The two screens of the app.
enum AppTab { OFFERS, ORDERS }
## The pedals sound a little different at each crossroads.
const PEDAL_PITCH_SPREAD := 0.08
## Seeds tried in a row before giving up when no city can be drawn.
const MAX_SEED_ATTEMPTS := 100
const EDGE := 10
## Width of the columns on each side of the hand, when the screen is wider than tall.
const SIDE_COLUMN := 200
## The cards are a little smaller on a narrow screen.
const NARROW_CARD_SCALE := 0.9
## The map may go a little under the hand: the cards stand on its edge.
const HAND_OVERLAP := 24.0
const APP_SIZE := Vector2(340, 500)
const HISTORY_SIZE := Vector2(380, 440)
## Seconds without any action before a help already seen shows again.
const IDLE_HELP_SECONDS := 8.0

## Seed of the run; a random one when negative. Set it before adding the screen to the tree.
var run_seed: int = -1
## Narrow screen (a phone held upright): one-line top bar, stacked cards in the windows.
## Chosen from the size of the screen in _ready(); the tests set it.
var narrow: bool = false
## Taller than wide: the buttons go above the hand instead of beside it. Set like narrow.
var portrait: bool = false
var game: Game
## The window open over the map.
var pane := Pane.NONE

var _city: CityView
var _hud: HudBar
var _hud_box: MarginContainer
var _take_box: VBoxContainer
var _bottom: MarginContainer
var _fan: HandFan
var _end_button: EndTurnButton
var _app_button: IconButton
var _bag_button: IconButton
var _history_button: IconButton
var _offers: OffersView
var _orders: OrdersView
var _app_tabs: TabContainer
var _app_rate: Label
var _bag: BagView
var _bag_detail: Label
var _feed: FeedView
var _help: HelpBubble
var _toast: Toast
var _pane_layer: Control
var _pane_center: CenterContainer
var _panes: Dictionary[Pane, Control] = {}
var _overlay: Control
var _overlay_center: CenterContainer
## Last night whose accounts the player has seen (the window of the end of the night).
var _night_report_seen: int = 0
var _menu_open: bool = false
## The bag was opened by taking a dish: it closes once the dish is stowed.
var _bag_opened_by_take := false
## Help that applies now ("" when none).
var _help_key: String = ""
## Helps already shown once in this session (kept when a new run starts).
static var helps_seen: Dictionary[String, bool] = {}
## Counts the seconds without any action of the player, to show a help again.
var _idle_timer: Timer
## History entries already shown as animations.
var _events_shown: int = 0
## Seconds the courier's ride lasts after the last move (what happens at the end waits for it).
var _ride_seconds: float = 0.0
## Kind of the window shown, to animate only a new one ("" when none).
var _dialog_kind: String = ""
## Phase at the last action, for the sound of the end of the run.
var _sound_phase := GameState.Phase.CHOOSE_PROFILE
## start() already ran (the tests call it before _ready()).
var _built: bool = false


func _ready() -> void:
	if not _built:
		# Already done by the main menu; needed when this scene is launched alone (F6).
		Device.apply_scale(get_window())
		var area := get_viewport_rect().size
		narrow = narrow or Device.is_narrow(area)
		portrait = portrait or area.y > area.x
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
	for view in _views():
		view.game = game
	_events_shown = game.state.history.size()
	refresh()


func _views() -> Array:
	return [_hud, _city, _fan, _end_button, _offers, _orders, _bag, _feed]


# --- Layout ---------------------------------------------------------------------------------

func _build() -> void:
	var background := ColorRect.new()
	background.color = UiStyle.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	# Room for the notch and the rounded corners of a phone: left, top, right, bottom.
	var safe := Device.safe_margins(get_viewport()) if is_inside_tree() else PackedFloat32Array([0, 0, 0, 0])

	_city = CityView.new()
	_city.set_anchors_preset(Control.PRESET_FULL_RECT)
	_city.crossroads_clicked.connect(_on_crossroads_clicked)
	_city.rode_past.connect(func(_crossroads: Vector2i) -> void: Sfx.play(Sfx.Sound.PEDAL, PEDAL_PITCH_SPREAD))
	add_child(_city)

	# By the courier at a restaurant: a button to take each dish waiting there.
	_take_box = UiStyle.vbox(6)
	add_child(_take_box)

	_hud = HudBar.new(narrow)
	_hud.menu_pressed.connect(_open_menu)
	_hud.info_pressed.connect(_show_info)
	_hud_box = _margins(MarginContainer.new(), EDGE, safe)
	_hud_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hud_box.add_child(_hud)
	add_child(_hud_box)

	_build_bottom(safe)

	_toast = Toast.new()
	_help = HelpBubble.new()
	# The help waits for the messages to go, not to cover them.
	_toast.cleared.connect(_update_help)
	_idle_timer = Timer.new()
	_idle_timer.one_shot = true
	_idle_timer.timeout.connect(_update_help.bind(true))
	add_child(_idle_timer)
	add_child(_help)
	_build_panes()
	add_child(_toast)
	_build_overlay()
	resized.connect(_layout)


## The icons, the end-of-turn button and the hand. On a screen taller than wide, the buttons are
## above the hand; otherwise, on each side of it.
func _build_bottom(safe: PackedFloat32Array) -> void:
	_app_button = IconButton.new(IconButton.Icon.PHONE)
	_app_button.tooltip_text = UiText.t("ICON_APP")
	_app_button.pressed.connect(toggle_pane.bind(Pane.APP))
	_bag_button = IconButton.new(IconButton.Icon.BAG)
	_bag_button.tooltip_text = UiText.t("ICON_BAG")
	_bag_button.pressed.connect(toggle_pane.bind(Pane.BAG))
	_history_button = IconButton.new(IconButton.Icon.HISTORY)
	_history_button.tooltip_text = UiText.t("ICON_HISTORY")
	_history_button.pressed.connect(toggle_pane.bind(Pane.HISTORY))
	var icons := UiStyle.hbox(12)
	icons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for button in [_app_button, _bag_button, _history_button]:
		icons.add_child(button)
	_end_button = EndTurnButton.new()
	_end_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_end_button.pressed.connect(_on_end_turn)
	_fan = HandFan.new()
	_fan.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if narrow:
		_fan.card_size = HandFan.CARD_SIZE * NARROW_CARD_SCALE
	_fan.card_clicked.connect(func(index: int) -> void: _after(_sound_if_done(game.play_card(index), Sfx.Sound.CARD)))

	_bottom = _margins(MarginContainer.new(), EDGE, safe)
	_bottom.add_theme_constant_override("margin_top", 0)
	_bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	if portrait:
		var column := UiStyle.vbox(6)
		var row := UiStyle.hbox(12)
		icons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(icons)
		row.add_child(_end_button)
		column.add_child(row)
		column.add_child(_fan)
		_bottom.add_child(column)
	else:
		var row := UiStyle.hbox(12)
		var left := UiStyle.vbox(0)
		left.custom_minimum_size.x = SIDE_COLUMN
		left.alignment = BoxContainer.ALIGNMENT_CENTER
		left.add_child(icons)
		row.add_child(left)
		row.add_child(_fan)
		var right := UiStyle.vbox(0)
		right.custom_minimum_size.x = SIDE_COLUMN
		right.alignment = BoxContainer.ALIGNMENT_CENTER
		_end_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		right.add_child(_end_button)
		row.add_child(right)
		_bottom.add_child(row)
	add_child(_bottom)


## The windows of the app, the bag and the history, over the map (dimmed); touching outside
## closes them.
func _build_panes() -> void:
	_offers = OffersView.new()
	_offers.accept_pressed.connect(func(id: int) -> void: _after(game.accept_offer(id)))
	_offers.offer_hovered.connect(_highlight)
	_orders = OrdersView.new()
	_orders.take_pressed.connect(_take)
	_orders.order_hovered.connect(_highlight)
	_bag = BagView.new()
	_bag.column_clicked.connect(func(column: int) -> void: _after(_sound_if_done(game.drop_held(column), Sfx.Sound.DROP)))
	_bag.dish_clicked.connect(func(id: int) -> void: _after(_sound_if_done(game.lift(id), Sfx.Sound.TAKE)))
	_bag.rotate_pressed.connect(func() -> void: _after(game.rotate_held()))
	_bag.set_aside_pressed.connect(func() -> void: _after(game.set_held_aside()))
	_bag.cancel_pressed.connect(func() -> void: _after(game.cancel_held()))
	_bag.aside_dish_clicked.connect(func(id: int) -> void: _after(game.take_from_aside(id)))
	_feed = FeedView.new()
	_feed.line_added.connect(func(line: UiText.Line) -> void: _toast.show_line(line))
	_feed.custom_minimum_size = HISTORY_SIZE

	_pane_layer = Control.new()
	_pane_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pane_layer.visible = false
	var dim := ColorRect.new()
	dim.color = Color(UiStyle.INK, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent) -> void:
		var click := event as InputEventMouseButton
		if click != null and click.pressed:
			close_pane())
	_pane_layer.add_child(dim)
	_pane_center = CenterContainer.new()
	_pane_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pane_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pane_layer.add_child(_pane_center)
	add_child(_pane_layer)

	_panes[Pane.APP] = _phone_window()
	var bag_window := _window(UiText.t("BAG_TITLE"), _bag)
	_bag_detail = bag_window.find_child("Detail", true, false) as Label
	_panes[Pane.BAG] = bag_window
	_panes[Pane.HISTORY] = _window(UiText.t("FEED_TITLE"), _feed)


## The app, drawn as a phone: its two screens are the offers and the orders in progress.
func _phone_window() -> Control:
	var bezel := PanelContainer.new()
	var style := UiStyle.box(UiStyle.INK, UiStyle.INK, 0, 34, 10)
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 18
	bezel.add_theme_stylebox_override("panel", style)
	var screen := PanelContainer.new()
	screen.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.BACKGROUND, UiStyle.BACKGROUND, 0, 22, 12))
	bezel.add_child(screen)
	var column := UiStyle.vbox(8)
	screen.add_child(column)
	column.add_child(_window_header(UiStyle.label(UiText.t("APP_NAME"), UiStyle.BIG_FONT_SIZE, UiStyle.ACCENT, true)))
	_app_rate = UiStyle.label("", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	_app_rate.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_app_rate)
	_app_tabs = TabContainer.new()
	_app_tabs.custom_minimum_size = APP_SIZE
	_app_tabs.add_child(_offers)
	_app_tabs.add_child(_orders)
	column.add_child(_app_tabs)
	return bezel


## A framed window with a title, a detail on the right and a close button.
func _window(title: String, content: Control) -> Control:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "Modal"
	var column := UiStyle.vbox(10)
	panel.add_child(column)
	var header := _window_header(UiStyle.label(title, UiStyle.BIG_FONT_SIZE, UiStyle.INK, true))
	var detail := UiStyle.label("", UiStyle.SMALL_FONT_SIZE, UiStyle.MUTED)
	detail.name = "Detail"
	header.add_child(detail)
	header.move_child(detail, 1)
	column.add_child(header)
	column.add_child(content)
	return panel


func _window_header(title: Label) -> HBoxContainer:
	var header := UiStyle.hbox(8)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := UiStyle.button("✕", close_pane, "SmallButton")
	close.tooltip_text = UiText.t("PANE_CLOSE")
	header.add_child(close)
	return header


## The windows of the other phases (profile, end of night, shop, end of run). They scroll when
## they are taller than the screen.
func _build_overlay() -> void:
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
	# The snack bar stays above the windows, to explain a greyed out button there too.
	move_child(_toast, -1)


func _margins(box: MarginContainer, value: int, safe: PackedFloat32Array) -> MarginContainer:
	var sides := ["left", "top", "right", "bottom"]
	for i in sides.size():
		box.add_theme_constant_override("margin_" + sides[i], value + int(safe[i]))
	return box


## Places what floats over the map and keeps the map clear of the top bar and of the buttons.
func _layout() -> void:
	if game == null:
		return
	var area := size
	var top := _hud_box.get_combined_minimum_size().y
	var bottom := _bottom.get_combined_minimum_size().y
	_bottom.offset_top = -bottom
	_city.insets = Vector4(0, top, 0, bottom - HAND_OVERLAP)
	_city.queue_redraw()
	# The messages sit at the bottom of the map. When a window is open: at the bottom of the
	# screen on a phone held upright, in the free column on the left otherwise.
	if pane == Pane.NONE and not _overlay.visible:
		_toast.place(area.y - bottom - 8, area.x)
	elif portrait:
		_toast.place(area.y - EDGE, area.x)
	else:
		var window_width := maxf(_pane_center.get_combined_minimum_size().x, _overlay_center.get_combined_minimum_size().x)
		_toast.place_in(Rect2(0, 0, (area.x - window_width) / 2, area.y - EDGE))
	# The take buttons above the courier, kept on the map.
	_take_box.reset_size()
	var courier := _city.point_of(game.state.courier_position)
	var at := courier - Vector2(_take_box.size.x / 2, _take_box.size.y + _city.spacing() * 0.45)
	_take_box.position = at.clamp(Vector2(EDGE, top), (area - _take_box.size - Vector2(EDGE, bottom)).max(Vector2(EDGE, top)))
	_app_tabs.custom_minimum_size = Vector2(minf(APP_SIZE.x, area.x - 64), minf(APP_SIZE.y, area.y - 220))
	_feed.custom_minimum_size = Vector2(minf(HISTORY_SIZE.x, area.x - 72), minf(HISTORY_SIZE.y, area.y - 200))


# --- Refresh --------------------------------------------------------------------------------

## Shows the current state everywhere. Nothing to show when no run could start (see _start_run()).
func refresh() -> void:
	if game == null:
		return
	var state := game.state
	# The bag opened by "take" closes once the dish is stowed.
	if _bag_opened_by_take and state.bag.held == null and state.bag.aside_items().is_empty():
		_bag_opened_by_take = false
		if pane == Pane.BAG:
			_show_pane(Pane.NONE)
	_city.highlighted = []
	for view in _views():
		view.refresh()
	_bag_detail.text = _bag.summary()
	_app_rate.text = _offers.summary()
	_app_tabs.set_tab_title(AppTab.OFFERS, UiText.t("APP_TAB_OFFERS") % state.offers.size())
	_app_tabs.set_tab_title(AppTab.ORDERS, UiText.t("APP_TAB_ORDERS") % [state.orders.size(), state.config.max_active_orders])
	_refresh_icons()
	_refresh_take_buttons()
	_refresh_overlay()
	if is_inside_tree():
		_layout.call_deferred()
		_update_help.call_deferred()
		_restart_idle()


func _refresh_icons() -> void:
	var state := game.state
	var acceptable := 0
	for offer in state.offers:
		if game.offer_problem(offer.id) == Game.Problem.NONE:
			acceptable += 1
	_app_button.badge = str(acceptable) if acceptable > 0 else ""
	_app_button.lit = pane == Pane.APP
	_bag_button.badge = "!" if state.bag.held != null or not state.bag.aside_items().is_empty() else ""
	_bag_button.lit = pane == Pane.BAG
	_history_button.lit = pane == Pane.HISTORY


func _refresh_take_buttons() -> void:
	UiStyle.clear(_take_box)
	if game.state.phase != GameState.Phase.PLAYING:
		return
	for order in game.state.orders:
		if game.take_dish_problem(order.id) == Game.Problem.NONE:
			_take_box.add_child(UiStyle.button(UiText.take_label(order), _take.bind(order.id), "YesButton"))


func _can_accept_an_offer() -> bool:
	for offer in game.state.offers:
		if game.offer_problem(offer.id) == Game.Problem.NONE:
			return true
	return false


# --- Windows over the map --------------------------------------------------------------------

## Opens a window over the map, or closes it when it is the one open.
func toggle_pane(which: Pane) -> void:
	if which == pane:
		close_pane()
	else:
		open_pane(which)


func open_pane(which: Pane) -> void:
	_bag_opened_by_take = false
	_show_pane(which)
	refresh()


func close_pane() -> void:
	open_pane(Pane.NONE)


## Puts this window over the map (or none), without refreshing the views.
func _show_pane(which: Pane) -> void:
	pane = which
	for child in _pane_center.get_children():
		_pane_center.remove_child(child)
	_pane_layer.visible = which != Pane.NONE
	if which != Pane.NONE:
		_help.hide()
		if which == Pane.APP:
			# The offers when there is one to take, otherwise the orders in progress.
			_app_tabs.current_tab = AppTab.OFFERS if _can_accept_an_offer() or game.state.orders.is_empty() else AppTab.ORDERS
		_pane_center.add_child(_panes[which])
		Motion.appear(_panes[which])


## The profile, the event of the night and the equipment, in a bubble under the (i) of the
## narrow top bar.
func _show_info() -> void:
	var button := _hud.info_button
	_help.point_at(UiText.night_info(game.state), button.get_global_rect().get_center() + Vector2(0, button.size.y / 2),
			HelpBubble.Placement.BELOW)


## Points a help bubble at what to use next. Each help shows by itself only the first time it
## applies (in the session); after that, only when the player does nothing for a while (idle).
## Nothing while a window is open: the bag and the app explain themselves.
func _update_help(idle: bool = false) -> void:
	if game == null:
		return
	var state := game.state
	var key := ""
	var text := ""
	var target := Vector2.ZERO
	var touch := Device.touch_screen()
	if state.phase != GameState.Phase.PLAYING or pane != Pane.NONE or _overlay.visible:
		pass
	elif state.bag.held != null or not state.bag.aside_items().is_empty():
		key = "HELP_BAG"
		target = _top_of(_bag_button)
	elif _take_box.get_child_count() > 0:
		key = "HELP_TAKE"
		target = _take_box.position + Vector2(_take_box.size.x / 2, 0)
	elif state.orders.is_empty() and _can_accept_an_offer():
		key = "HELP_ACCEPT"
		target = _top_of(_app_button)
	elif state.steps > 0:
		key = "HELP_MOVE_TOUCH" if touch else "HELP_MOVE"
		target = _city.point_of(state.courier_position) - Vector2(0, _city.spacing() * 0.35)
	elif _can_play_a_card():
		key = "HELP_PLAY_CARDS_TOUCH" if touch else "HELP_PLAY_CARDS"
		text = UiText.t(key) % state.max_paid_cards()
		target = _top_of(_fan)
	else:
		key = "HELP_END_TURN"
		target = _top_of(_end_button)
	if key != _help_key:
		_help_key = key
		_help.hide()
	if key == "" or _help.visible:
		return
	# The help waits for the messages to go (Toast.cleared calls this again).
	if _toast.text() != "" and is_inside_tree():
		return
	if helps_seen.has(key) and not idle:
		return
	helps_seen[key] = true
	_help.point_at(text if text != "" else UiText.t(key), target, HelpBubble.Placement.ABOVE)


## The player did something: the help waits again for a pause before coming back.
func _restart_idle() -> void:
	if is_inside_tree():
		_idle_timer.start(IDLE_HELP_SECONDS)


func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventKey or event is InputEventScreenTouch) and event.is_pressed():
		_restart_idle()


func _top_of(control: Control) -> Vector2:
	var rect := control.get_global_rect()
	return Vector2(rect.get_center().x, rect.position.y)


func _can_play_a_card() -> bool:
	for index in game.state.piles.hand.size():
		if game.card_problem(index) == Game.Problem.NONE:
			return true
	return false


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
					shop.buy_pressed.connect(func(index: int) -> void: _after(_sound_if_done(game.buy(index), Sfx.Sound.BUY)))
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
		dialog.narrow = narrow
		if dialog.game == null:
			dialog.setup(game)
		if is_inside_tree():
			dialog.custom_minimum_size.x = minf(dialog.custom_minimum_size.x, size.x - 24)
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

## After every action: a refusal goes to the history and pops up, what happened is animated, then
## everything is shown again.
func _after(problem: Game.Problem) -> void:
	if problem != Game.Problem.NONE:
		_feed.add_problem(problem)
		_toast.show_line(UiText.Line.new(UiText.t("SENDER_REFUSED"), UiText.problem(problem), true))
		Sfx.play(Sfx.Sound.REFUSE)
	_show_events()
	_ride_seconds = 0.0
	refresh()


## Takes a dish (from the button by the courier or from the app), and opens the bag to stow it.
func _take(order_id: int) -> void:
	var problem := _sound_if_done(game.take_dish(order_id), Sfx.Sound.TAKE)
	if problem == Game.Problem.NONE and pane != Pane.BAG:
		open_pane(Pane.BAG)
		_bag_opened_by_take = true
	_after(problem)


## Animates the events of the history since the last action: money that rises from the client's
## door, a bag that shakes...
func _show_events() -> void:
	var state := game.state
	for index in range(_events_shown, state.history.size()):
		var event := state.history[index]
		match event.kind:
			GameEvent.Kind.DELIVERED:
				var delivery := event.delivery
				var good := delivery.outcome == Delivery.Outcome.PERFECT
				_city.float_text(event.order.client, UiText.delivery_float(delivery), UiStyle.OK if good else UiStyle.BAD,
						_ride_seconds)
				_play_later(Sfx.Sound.DELIVER if good else Sfx.Sound.BAD, _ride_seconds)
			GameEvent.Kind.CANCELLED:
				_city.float_text(event.order.client, UiText.rating_float(event.rating_tenths), UiStyle.BAD)
				Sfx.play(Sfx.Sound.BAD)
			GameEvent.Kind.CARD_RATING_COST:
				_city.float_text(state.courier_position, UiText.rating_float(event.rating_tenths), UiStyle.BAD)
			GameEvent.Kind.SHAKE:
				if not event.braced:
					_bag.shake()
					Sfx.play(Sfx.Sound.SHAKE)
			GameEvent.Kind.CRUSHED:
				_bag.shake()
				Sfx.play(Sfx.Sound.BAD)
			GameEvent.Kind.NIGHT_ENDED:
				if state.phase not in [GameState.Phase.WON, GameState.Phase.LOST]:
					_play_later(Sfx.Sound.NIGHT_END, _ride_seconds)
	_events_shown = state.history.size()
	if state.phase != _sound_phase and state.phase in [GameState.Phase.WON, GameState.Phase.LOST]:
		_play_later(Sfx.Sound.WIN if state.phase == GameState.Phase.WON else Sfx.Sound.LOSE, _ride_seconds)
	_sound_phase = state.phase


## Plays a sound once the courier's ride is over.
func _play_later(sound: Sfx.Sound, delay: float) -> void:
	if delay <= 0.0 or not is_inside_tree():
		Sfx.play(sound)
		return
	get_tree().create_timer(delay).timeout.connect(func() -> void: Sfx.play(sound))


## The sound of an action, when it was done.
func _sound_if_done(problem: Game.Problem, sound: Sfx.Sound) -> Game.Problem:
	if problem == Game.Problem.NONE:
		Sfx.play(sound)
	return problem


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


## The back button of Android (or gesture): closes the menu, puts back the dish in hand, closes
## the window open over the map, or opens the menu (also over the windows of the other phases).
## Without this, Godot would quit the game (project setting application/config/quit_on_go_back).
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST or game == null:
		return
	if _menu_open:
		_menu_open = false
		refresh()
	elif game.state.bag.held != null and not _overlay.visible:
		_after(game.cancel_held())
	elif pane != Pane.NONE and not _overlay.visible:
		close_pane()
	else:
		_open_menu()


## Keyboard shortcuts: R turns the dish in hand, Escape puts it back or closes the window open
## over the map.
func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or game == null or _overlay.visible:
		return
	if key.keycode == KEY_R and game.state.bag.held != null:
		_after(game.rotate_held())
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and game.state.bag.held != null:
		_after(game.cancel_held())
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_ESCAPE and pane != Pane.NONE:
		close_pane()
		get_viewport().set_input_as_handled()
