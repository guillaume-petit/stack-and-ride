extends TestCase
## The texts of the interface: every key it uses exists in French, and the messages built from
## the state come out right.

const UI_ROOT := "res://ui"

var french: Translation


func before_each() -> void:
	french = load("res://i18n/fr.po") as Translation


func _has(key: String) -> bool:
	return String(french.get_message(key)) != ""


## Every key written in the code of the interface. A key is a string literal in capitals with
## at least one underscore that does not end with one (those are prefixes completed in code,
## checked by the tests below).
func test_every_key_written_in_the_interface_exists() -> void:
	var regex := RegEx.create_from_string("\"([A-Z][A-Z0-9]*_[A-Z0-9_]*[A-Z0-9])\"")
	var count := 0
	for path in _scripts(UI_ROOT):
		var source := FileAccess.get_file_as_string(path)
		for found in regex.search_all(source):
			count += 1
			assert_true(_has(found.get_string(1)), "%s: missing translation %s" % [path, found.get_string(1)])
	assert_true(count > 100, "the scan found the keys (%d)" % count)


func test_every_refusal_has_a_text() -> void:
	for value: int in Game.Problem.values():
		if value != Game.Problem.NONE:
			assert_true(_has(UiText.problem_key(value)), "missing %s" % UiText.problem_key(value))


func test_keys_completed_in_code_exist() -> void:
	var keys: Array[String] = []
	for name: String in DishData.Temperature.keys():
		keys.append("TEMPERATURE_" + name)
	for name: String in Bag.Origin.keys():
		keys.append("BAG_CANCEL_" + name)
	for name: String in Reward.Kind.keys():
		keys.append("REWARD_KIND_" + name)
	for name: String in ["WON", "RENT", "RATING"]:
		keys.append("RUN_END_TITLE_" + name)
		keys.append("RUN_END_TEXT_" + name)
	assert_eq(GameState.LossReason.keys(), ["NONE", "RATING", "RENT"], "a new loss reason needs its texts")
	for i in Settings.UI_SIZES.size():
		keys.append("OPTIONS_SIZE_%d" % i)
	for page in HowToPlayDialog.PAGES:
		keys.append("HOWTO_%s_TITLE" % page)
		keys.append("HOWTO_%s_TEXT" % page)
	var content := GameContent.load_from()
	for restaurant: RestaurantData in content.restaurants.values():
		keys.append(UiText.short_name_key(restaurant))
	for key in keys:
		assert_true(_has(key), "missing translation %s" % key)


func test_numbers_in_french() -> void:
	assert_eq(UiText.stars(47), "4,7")
	assert_eq(UiText.stars(50), "5,0")
	assert_eq(UiText.stars_change(1), "+0,1")
	assert_eq(UiText.stars_change(-3), "−0,3")
	assert_eq(UiText.stars_change(-15), "−1,5")
	assert_eq(UiText.star_bar(44), "★★★★☆")
	assert_eq(UiText.euros(12), "12 €")
	assert_eq(UiText.euros(-45), "−45 €")


func test_translations_are_active() -> void:
	assert_eq(UiText.t("MENU_NEW_RUN"), "Nouvelle partie")


func test_delivery_messages() -> void:
	var f := GameFixture.start()
	var order := f.add_order(&"pizza", GameFixture.CLIENT_1, 2, 10)
	f.carry(order)
	f.state.steps = 3
	f.game.move_to(GameFixture.CLIENT_1)
	var event: GameEvent = f.events(GameEvent.Kind.DELIVERED)[0]
	var line := UiText.event_line(event, f.state)
	assert_eq(line.sender, "Livraison")
	assert_false(line.bad)
	assert_true(line.text.begins_with("Livré au n° 1 : 10 € + 2 € de pourboire."), line.text)
	assert_true(line.text.ends_with("+0,1 ★"), line.text)


func test_shake_and_cancel_messages() -> void:
	var f := GameFixture.start()
	var order := f.add_order(&"soda", GameFixture.CLIENT_2, -2)
	f.carry(order)
	f.give_cards([&"sprint"])
	f.game.play_card(0)
	var shake := UiText.event_line(f.events(GameEvent.Kind.SHAKE)[0], f.state)
	assert_eq(shake.text, "Sprint : #%d Soda abîmé(s)." % order.id)
	assert_true(shake.bad)
	f.game.end_turn()
	var cancelled := UiText.event_line(f.events(GameEvent.Kind.CANCELLED)[0], f.state)
	assert_eq(cancelled.text, "Le client du n° 2 a annulé sa commande. −0,5 ★")


func test_returned_to_restaurant_message() -> void:
	var f := GameFixture.start()
	f.state.courier_position = GameFixture.RESTAURANT
	f.state.bag = Bag.new(1, 1)
	var pizza := f.add_order(&"pizza", GameFixture.CLIENT_1)
	f.game.take_dish(pizza.id)
	f.game.set_held_aside()
	f.game.end_turn()
	var line := UiText.event_line(f.events(GameEvent.Kind.RETURNED_TO_RESTAURANT)[0], f.state)
	assert_eq(line.text, "#%d Pizza ne rentrait pas dans le sac : rendu à Pizzeria Nonna en fin de tour. La course reste à livrer." % pizza.id)


## Every kind of event of a whole run gets a message without error (a wrong number of values
## in a text would report an engine error and fail the test).
func test_every_event_of_a_run_has_a_message() -> void:
	var content := GameContent.load_from()
	var kinds := {}
	for seed in [1, 2, 3]:
		var game := Bot.play_run(content, seed, &"darling")
		for event in game.state.history:
			var line := UiText.event_line(event, game.state)
			assert_true(line != null and line.text != "", "message for %s" % GameEvent.Kind.keys()[event.kind])
			kinds[event.kind] = true
	assert_true(kinds.size() >= 6, "the runs covered several kinds of events (%d)" % kinds.size())


func _scripts(folder: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(folder)
	for sub in dir.get_directories():
		out.append_array(_scripts(folder.path_join(sub)))
	for file in dir.get_files():
		if file.ends_with(".gd"):
			out.append(folder.path_join(file))
	return out
