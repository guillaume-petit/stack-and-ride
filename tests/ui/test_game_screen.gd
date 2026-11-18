extends TestCase
## The game screen, without drawing: it builds the right window for each phase and sends the
## player's actions to the core. A whole run played by the bot is shown step by step, so that
## every view meets real states (an error in a view fails the test).

var screen: GameScreen


func before_each() -> void:
	if screen != null:
		screen.free()
	screen = (load("res://ui/game/game_screen.tscn") as PackedScene).instantiate()
	screen.run_seed = 3
	screen.start()


func _dialog() -> Dialog:
	var center: Node = screen._overlay_center
	for child in center.get_children():
		if child is Dialog and not child.is_queued_for_deletion():
			return child
	return null


func test_the_run_starts_with_the_choice_of_the_profile() -> void:
	assert_true(screen._overlay.visible)
	var dialog := _dialog()
	assert_true(dialog is ProfileDialog, "profile window")
	(dialog as ProfileDialog).profile_chosen.emit(&"mule")
	assert_eq(screen.game.state.phase, GameState.Phase.PLAYING)
	assert_eq(screen.game.state.profile, &"mule")
	assert_false(screen._overlay.visible, "no window while playing")


func test_actions_from_the_views_reach_the_core() -> void:
	screen.game.choose_profile(&"combo")
	screen.refresh()
	var state := screen.game.state
	var offer := state.offers[0]
	screen._offers.accept_pressed.emit(offer.id)
	assert_true(state.find_offer(offer.id) == null, "offer accepted")
	assert_eq(state.orders.size(), offer.parts.size())
	state.piles.hand = [&"ped3"] as Array[StringName]
	screen._hand.card_clicked.emit(0)
	assert_eq(state.steps, 3)


func test_a_refused_action_is_reported_in_the_feed() -> void:
	screen.game.choose_profile(&"combo")
	screen.refresh()
	var lines := screen._feed._list.get_child_count()
	screen._city.crossroads_clicked.emit(Vector2i(0, 0))
	assert_eq(screen._feed._list.get_child_count(), lines + 1, "no step: the ride is refused")


func test_the_menu_asks_before_leaving() -> void:
	screen.game.choose_profile(&"combo")
	screen._open_menu()
	assert_true(screen._overlay.visible)
	assert_true(_dialog() != null)


func test_a_whole_run_played_by_the_bot() -> void:
	screen.game.choose_profile(&"sprinter")
	screen.refresh()
	var bot := Bot.new(screen.game)
	var state := screen.game.state
	var steps := 0
	while bot.play_step() and steps < Bot.MAX_TURNS_PER_RUN:
		steps += 1
		screen.refresh()
		match state.phase:
			GameState.Phase.PLAYING:
				assert_false(screen._overlay.visible, "no window while playing")
			GameState.Phase.CHOOSING_REWARD:
				assert_true(_dialog() is NightDialog, "end of night window")
			GameState.Phase.SHOPPING:
				assert_true(_dialog() is NightDialog, "the accounts first")
				screen._night_report_seen = state.night
				screen.refresh()
				assert_true(_dialog() is ShopDialog, "then the shop")
	assert_true(state.phase in [GameState.Phase.WON, GameState.Phase.LOST], "the run is over")
	assert_true(_dialog() is RunEndDialog, "end of run window")
	screen.free()
	screen = null
