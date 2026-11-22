extends TestCase
## Phones: the size of the interface, the narrow version of the game screen (a phone held
## upright), the map turned to fill it, and the controls made for a finger (a first touch shows,
## a second one acts).

var screen: GameScreen


func before_each() -> void:
	if screen != null:
		screen.free()
	screen = (load("res://ui/game/game_screen.tscn") as PackedScene).instantiate()
	screen.run_seed = 3
	screen.narrow = true
	screen.portrait = true
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

func test_a_phone_held_upright_gets_a_bigger_and_narrow_interface() -> void:
	# A 6.5" phone held upright: 1080 × 2400 pixels at 420 dpi.
	var screen_size := Vector2(1080, 2400)
	var factor := Device.scale_for(screen_size, 420)
	assert_true(factor > 2.5 and factor < 3.1, "factor %f" % factor)
	var visible := screen_size / (1080.0 / 1280.0 * factor)
	assert_true(Device.is_narrow(visible), "narrow at %s" % visible)


func test_a_computer_keeps_the_normal_size_and_a_tablet_is_not_narrow() -> void:
	assert_eq(Device.scale_for(Vector2(1920, 1080), 96), 1.0)
	assert_false(Device.is_narrow(Vector2(1280, 720)))
	# A 10" tablet held upright: 1200 × 1920 at 224 dpi.
	var factor := Device.scale_for(Vector2(1200, 1920), 224)
	assert_false(Device.is_narrow(Vector2(1200, 1920) / (1200.0 / 1280.0 * factor)))


func test_an_unknown_density_changes_nothing() -> void:
	assert_eq(Device.scale_for(Vector2(2400, 1080), 0), 1.0)
	assert_eq(Device.scale_for(Vector2.ZERO, 420), 1.0)


func test_a_touch_is_recognised() -> void:
	assert_true(Device.is_touch(_touch(Vector2.ZERO)))
	var click := InputEventMouseButton.new()
	click.device = 0
	assert_false(Device.is_touch(click))


# --- The map turned -------------------------------------------------------------------------

## Gives the map a size of its own (it normally fills the screen, by its anchors).
func _map(area: Vector2) -> CityView:
	var city := screen._city
	city.set_anchors_preset(Control.PRESET_TOP_LEFT)
	city.size = area
	return city


func test_the_map_turns_when_that_makes_it_bigger() -> void:
	assert_true(_map(Vector2(450, 800)).turned(), "upright screen")
	assert_false(_map(Vector2(1200, 600)).turned(), "wide screen")


func test_every_crossroads_is_found_where_it_is_drawn() -> void:
	var map := screen.game.state.city
	for area: Vector2 in [Vector2(450, 800), Vector2(1200, 600)]:
		var city := _map(area)
		for y in map.rows:
			for x in map.columns:
				var crossroads := Vector2i(x, y)
				var point := city._point(crossroads)
				assert_eq(city._crossroads_at(point + Vector2(4, -3)), crossroads, "%s on %s" % [crossroads, area])
				assert_true(Rect2(Vector2.ZERO, area).has_point(point), "%s inside the view" % crossroads)


func test_the_insets_keep_the_map_clear() -> void:
	var city := _map(Vector2(450, 800))
	city.insets = Vector4(0, 100, 0, 250)
	var map := screen.game.state.city
	for crossroads in [Vector2i.ZERO, Vector2i(map.columns - 1, map.rows - 1)]:
		var point := city._point(crossroads)
		assert_true(point.y > 100 and point.y < 550, "%s between the bars" % crossroads)


# --- Narrow version -------------------------------------------------------------------------

func test_the_narrow_top_bar_keeps_the_profile_behind_the_info_button() -> void:
	assert_true(screen._hud.info_button != null)
	var profile: ProfileData = screen.game.state.content.profiles[&"combo"]
	assert_true(HudBar.info_text(screen.game.state).contains(UiText.name_of(profile)))
	screen._show_info()
	assert_true(screen._help.text().contains(UiText.name_of(profile)), "shown in a bubble")


func test_a_refusal_pops_up() -> void:
	screen._city.crossroads_clicked.emit(Vector2i(0, 0))
	assert_eq(screen._toast.text(), UiText.problem(Game.Problem.TOO_FAR))


func test_a_whole_run_on_a_phone() -> void:
	var bot := Bot.new(screen.game)
	var state := screen.game.state
	var steps := 0
	while bot.play_step() and steps < Bot.MAX_TURNS_PER_RUN:
		steps += 1
		if state.phase == GameState.Phase.SHOPPING:
			screen._night_report_seen = state.night
		screen.refresh()
		screen._update_help()
	assert_true(state.phase in [GameState.Phase.WON, GameState.Phase.LOST], "the run is over")
	screen.free()
	screen = null


# --- A finger on the map and in the bag ------------------------------------------------------

func test_a_first_touch_on_the_map_shows_the_path_and_a_second_one_rides() -> void:
	var state := screen.game.state
	state.steps = 2
	screen.refresh()
	var city := _map(Vector2(600, 500))
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
	screen.refresh()
	screen._take(order.id)
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
