extends TestCase
## Phones: the size of the interface, the compact layout of the game screen and the controls
## made for a finger (a first touch shows, a second one acts).

var screen: GameScreen


func before_each() -> void:
	if screen != null:
		screen.free()
	screen = (load("res://ui/game/game_screen.tscn") as PackedScene).instantiate()
	screen.run_seed = 3
	screen.compact = true
	screen.start()
	screen.game.choose_profile(&"combo")
	screen.refresh()


## A touch as Godot hands it to the interface: a mouse click from the emulation device.
static func _touch(position: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.device = InputEvent.DEVICE_ID_EMULATION
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = position
	return event


# --- Size of the interface ------------------------------------------------------------------

func test_a_phone_gets_a_bigger_interface() -> void:
	# A 6.5" phone in landscape: 2400 × 1080 pixels at 420 dpi.
	var factor := Device.scale_for(Vector2(2400, 1080), 420)
	assert_true(factor > 1.4 and factor < 1.8, "factor %f" % factor)
	var visible := Vector2(2400, 1080) / (1080.0 / 720.0 * factor)
	assert_true(Device.is_compact(visible), "compact layout at %s" % visible)


func test_a_computer_or_a_tablet_keeps_the_normal_size() -> void:
	assert_eq(Device.scale_for(Vector2(1920, 1080), 96), 1.0)
	# A 10" tablet: 1920 × 1200 at 224 dpi.
	assert_eq(Device.scale_for(Vector2(1920, 1200), 224), 1.0)
	assert_false(Device.is_compact(Vector2(1280, 720)))
	assert_false(Device.is_compact(Vector2(1280, 800)))


func test_an_unknown_density_changes_nothing() -> void:
	assert_eq(Device.scale_for(Vector2(2400, 1080), 0), 1.0)
	assert_eq(Device.scale_for(Vector2.ZERO, 420), 1.0)


func test_a_touch_is_recognised() -> void:
	assert_true(Device.is_touch(_touch(Vector2.ZERO)))
	var click := InputEventMouseButton.new()
	click.device = 0
	assert_false(Device.is_touch(click))


# --- Compact layout -------------------------------------------------------------------------

func test_the_compact_layout_has_one_tab_per_panel() -> void:
	assert_true(screen._tabs != null)
	assert_eq(screen._tabs.get_tab_count(), GameScreen.Tab.size())
	assert_eq(screen._tabs.get_tab_title(GameScreen.Tab.OFFERS),
			UiText.t("TAB_OFFERS") % screen.game.state.offers.size())
	assert_eq(screen._opened_tab, GameScreen.Tab.OFFERS, "a new turn opens the offers")


func test_the_bag_opens_when_a_dish_is_taken_and_closes_when_it_is_stowed() -> void:
	var state := screen.game.state
	var offer := state.offers[0]
	screen._offers.accept_pressed.emit(offer.id)
	var order := state.orders[0]
	state.courier_position = order.restaurant
	screen.refresh()
	screen._orders.take_pressed.emit(order.id)
	assert_eq(screen._opened_tab, GameScreen.Tab.BAG)
	screen._bag.column_clicked.emit(0)
	assert_true(state.bag.held == null, "the dish is in the bag")
	var expected := GameScreen.Tab.ORDERS if screen._can_take_a_dish() else GameScreen.Tab.CARDS
	assert_eq(screen._opened_tab, expected)


func test_a_refusal_pops_up() -> void:
	screen._city.crossroads_clicked.emit(Vector2i(0, 0))
	assert_eq(screen._toast.text(), UiText.problem(Game.Problem.TOO_FAR))


func test_a_whole_run_in_the_compact_layout() -> void:
	var bot := Bot.new(screen.game)
	var state := screen.game.state
	var steps := 0
	while bot.play_step() and steps < Bot.MAX_TURNS_PER_RUN:
		steps += 1
		if state.phase == GameState.Phase.SHOPPING:
			screen._night_report_seen = state.night
		screen.refresh()
	assert_true(state.phase in [GameState.Phase.WON, GameState.Phase.LOST], "the run is over")
	screen.free()
	screen = null


# --- A finger on the map and in the bag ------------------------------------------------------

func test_a_first_touch_on_the_map_shows_the_path_and_a_second_one_rides() -> void:
	var state := screen.game.state
	state.steps = 2
	screen.refresh()
	var city := screen._city
	city.size = Vector2(600, 500)
	var target: Vector2i = screen.game.reachable()[0]
	var clicked: Array[Vector2i] = []
	city.crossroads_clicked.connect(func(crossroads: Vector2i) -> void: clicked.append(crossroads))
	city._gui_input(_touch(city._point(target)))
	assert_eq(city._hovered, target, "the path is shown")
	assert_true(clicked.is_empty(), "not yet")
	city._gui_input(_touch(city._point(target) + Vector2(3, -2)))
	assert_eq(clicked, [target] as Array[Vector2i])


func test_a_first_touch_on_the_bag_shows_where_the_dish_falls_and_a_second_one_drops_it() -> void:
	var state := screen.game.state
	screen._offers.accept_pressed.emit(state.offers[0].id)
	var order := state.orders[0]
	state.courier_position = order.restaurant
	screen.game.take_dish(order.id)
	screen.refresh()
	var grid := screen._bag._grid
	grid.size = Vector2(300, 260)
	var dropped: Array[int] = []
	grid.column_clicked.connect(func(column: int) -> void: dropped.append(column))
	var middle := grid._cell_rect(Vector2i(1, 0)).get_center()
	grid._gui_input(_touch(middle))
	assert_eq(grid.hover_column(), 1, "the landing place is shown")
	assert_true(dropped.is_empty(), "not yet")
	grid._gui_input(_touch(middle))
	assert_eq(dropped, [1] as Array[int])
