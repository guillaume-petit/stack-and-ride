extends TestCase
## The game screen, without drawing: it builds the right window for each phase, sends the
## player's actions to the core and points the help at what to use next. A whole run played by
## the bot is shown step by step, so that every view meets real states (an error in a view fails
## the test).

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
	screen._fan.card_clicked.emit(0)
	assert_eq(state.steps, 3)


func test_a_refused_action_is_reported_in_the_feed() -> void:
	screen.game.choose_profile(&"combo")
	screen.refresh()
	var lines := screen._feed._list.get_child_count()
	screen._city.crossroads_clicked.emit(Vector2i(0, 0))
	assert_eq(screen._feed._list.get_child_count(), lines + 1, "no step: the ride is refused")


func test_a_dish_from_this_restaurant_can_be_given_back_from_aside() -> void:
	screen.game.choose_profile(&"combo")
	var state := screen.game.state
	var order := Order.new()
	order.id = state.next_order_id
	state.next_order_id += 1
	order.dish = state.content.dishes[&"pizza"]
	order.restaurant = state.city.crossroads_with(City.Place.RESTAURANT)[0]
	order.client = state.city.crossroads_with(City.Place.CLIENT)[0]
	order.deadline = 5
	order.modifiers = OrderModifiers.new()
	state.orders.append(order)
	state.courier_position = order.restaurant
	screen.game.take_dish(order.id)
	screen._bag.set_aside_pressed.emit()
	screen.close_pane()
	screen._update_help()
	assert_eq(screen._help_key, "HELP_BAG", "the help points at the bag")
	screen._bag.aside_dish_clicked.emit(order.id)
	assert_eq(screen._bag._cancel_button.text, UiText.t("BAG_CANCEL_RESTAURANT"))
	screen._bag.cancel_pressed.emit()
	assert_false(order.picked_up, "back at the restaurant")


func test_the_help_follows_the_turn() -> void:
	screen.game.choose_profile(&"combo")
	screen.refresh()
	screen._update_help()
	assert_eq(screen._help_key, "HELP_ACCEPT", "first, the app")
	var state := screen.game.state
	screen._offers.accept_pressed.emit(state.offers[0].id)
	screen._update_help()
	assert_eq(screen._help_key, "HELP_PLAY_CARDS", "then the cards")
	state.steps = 2
	screen.refresh()
	screen._update_help()
	assert_true(screen._help_key in ["HELP_MOVE", "HELP_MOVE_TOUCH"], "then the map")


func test_a_help_that_faded_does_not_come_back() -> void:
	screen.game.choose_profile(&"combo")
	screen.refresh()
	screen._update_help()
	assert_eq(screen._help.text(), UiText.t("HELP_ACCEPT"))
	screen._help.hide()
	screen.refresh()
	screen._update_help()
	assert_eq(screen._help.text(), "", "same help: not shown again")


func test_the_back_button_opens_the_menu_over_a_phase_window() -> void:
	assert_true(_dialog() is ProfileDialog)
	screen._notification(Control.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_true(screen._menu_open, "the menu to leave the run")
	screen._notification(Control.NOTIFICATION_WM_GO_BACK_REQUEST)
	assert_false(screen._menu_open, "pressed again: closed")


func test_the_icons_open_their_windows() -> void:
	screen.game.choose_profile(&"combo")
	screen.refresh()
	screen._app_button.pressed.emit()
	assert_eq(screen.pane, GameScreen.Pane.APP)
	assert_true(screen._pane_layer.visible)
	assert_eq(screen._app_button.badge, str(screen.game.state.offers.size()), "offers to accept")
	screen._bag_button.pressed.emit()
	assert_eq(screen.pane, GameScreen.Pane.BAG, "one window at a time")
	screen._bag_button.pressed.emit()
	assert_eq(screen.pane, GameScreen.Pane.NONE, "pressed again: closed")
	assert_false(screen._pane_layer.visible)


func test_taking_a_dish_opens_the_bag_until_it_is_stowed() -> void:
	screen.game.choose_profile(&"combo")
	var state := screen.game.state
	screen._offers.accept_pressed.emit(state.offers[0].id)
	var order := state.orders[0]
	state.courier_position = order.restaurant
	screen.refresh()
	assert_true(screen._take_box.get_child_count() > 0, "a take button by the courier")
	screen._take(order.id)
	assert_eq(screen.pane, GameScreen.Pane.BAG)
	assert_eq(screen._bag_button.badge, "!")
	screen._bag.column_clicked.emit(0)
	assert_true(state.bag.held == null, "the dish is in the bag")
	assert_eq(screen.pane, GameScreen.Pane.NONE, "the bag closed by itself")


func test_the_end_turn_button_shows_the_cards_of_the_turn() -> void:
	screen.game.choose_profile(&"combo")
	var state := screen.game.state
	state.piles.hand = [&"ped2"] as Array[StringName]
	screen.refresh()
	assert_eq(screen._end_button.tooltip_text, UiText.t("TURN_CARDS_TOOLTIP") % [0, state.max_paid_cards()])
	screen._fan.card_clicked.emit(0)
	assert_eq(screen._end_button.tooltip_text, UiText.t("TURN_CARDS_TOOLTIP") % [1, state.max_paid_cards()])
	screen._end_button.pressed.emit()
	assert_eq(state.turn, 2, "next turn")


func test_the_menu_asks_before_leaving() -> void:
	screen.game.choose_profile(&"combo")
	screen._open_menu()
	assert_true(screen._overlay.visible)
	assert_true(_dialog() != null)


func test_a_whole_run_played_by_the_bot() -> void:
	screen.game.choose_profile(&"sprinter")
	screen.refresh()
	# The bag open during the whole run: it is refreshed too.
	screen.open_pane(GameScreen.Pane.BAG)
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
