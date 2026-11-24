extends TestCase
## Saving and loading a run (RunSave): the run played again from its seed and its actions must be
## exactly the one that was saved, and a damaged or outdated save must be rejected.

const TEST_PATH := "user://test_run_save.json"

var content: GameContent
## Same content, but a run cannot be lost: random play goes through every night, reward and shop.
var generous: GameContent


func before_each() -> void:
	if content == null:
		content = GameContent.load_from()
		generous = GameContent.load_from()
		generous.config = generous.config.duplicate()
		generous.config.min_rating_tenths = 0
		var free: Array[int] = []
		free.resize(generous.config.rent_per_night.size())
		free.fill(0)
		generous.config.rent_per_night = free
	RunSave.erase(TEST_PATH)


func test_whole_runs_of_the_bot_come_back_the_same() -> void:
	for profile in content.profile_ids():
		var game := Bot.play_run(content, 7, profile)
		var loaded := _through_json(game)
		assert_true(loaded != null, "%s: loaded" % profile)
		if loaded != null:
			assert_eq(_fingerprint(loaded), _fingerprint(game), profile)


func test_runs_stopped_anywhere_come_back_the_same() -> void:
	# Random actions, stopped after a different number each time: in the middle of a turn, with a
	# dish in hand or set aside, at the reward, in the shop...
	for seed in range(1, 13):
		var game := _random_run(seed, seed * 37)
		var loaded := _through_json(game, generous)
		assert_true(loaded != null, "seed %d: loaded" % seed)
		if loaded != null:
			assert_eq(_fingerprint(loaded), _fingerprint(game), "seed %d" % seed)


func test_only_accepted_actions_are_saved() -> void:
	var game := Game.new_run(content, 5)
	assert_eq(game.end_turn(), Game.Problem.WRONG_PHASE)
	assert_eq(game.choose_profile(&"nobody"), Game.Problem.UNKNOWN_PROFILE)
	assert_eq(game.state.actions.size(), 0)
	game.choose_profile(&"mule")
	assert_eq(game.state.actions, [["choose_profile", "mule"]])


func test_a_save_goes_through_a_file() -> void:
	var game := _random_run(3, 400)
	assert_true(RunSave.save_game(game, TEST_PATH))
	assert_true(RunSave.has_save(TEST_PATH))
	assert_false(FileAccess.file_exists(TEST_PATH + ".tmp"), "no temporary file left")
	var loaded := RunSave.load_game(generous, TEST_PATH)
	assert_true(loaded != null)
	if loaded != null:
		assert_eq(_fingerprint(loaded), _fingerprint(game))
	# Saved again over the previous one.
	game.end_turn()
	assert_true(RunSave.save_game(game, TEST_PATH))
	assert_eq(_fingerprint(RunSave.load_game(generous, TEST_PATH)), _fingerprint(game))
	assert_null(RunSave.load_game(content, TEST_PATH), "not the same rules")
	RunSave.erase(TEST_PATH)
	assert_false(RunSave.has_save(TEST_PATH))
	assert_null(RunSave.load_game(generous, TEST_PATH))


func test_a_damaged_file_is_rejected() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	assert_null(RunSave.load_game(content, TEST_PATH))
	RunSave.erase(TEST_PATH)


func test_damaged_data_is_rejected() -> void:
	var game := Bot.play_run(content, 4, &"mule")
	var good := RunSave.to_data(game)
	var cases: Dictionary[String, Callable] = {
		"other format": func(data: Dictionary) -> void: data["format"] = RunSave.FORMAT + 1,
		"no seed": func(data: Dictionary) -> void: data.erase("seed"),
		"actions not a list": func(data: Dictionary) -> void: data["actions"] = "end_turn",
		"unknown action": func(data: Dictionary) -> void: data["actions"].append(["fly", null]),
		"wrong argument": func(data: Dictionary) -> void: data["actions"][0] = ["choose_profile", 3],
		"bad target": func(data: Dictionary) -> void: data["actions"].append(["move_to", [1]]),
		"unknown problem": func(data: Dictionary) -> void: data["actions"].append(["end_turn", null, "OOPS"]),
		"refused action": func(data: Dictionary) -> void: data["actions"].insert(1, ["choose_profile", "mule"]),
		"other counters": func(data: Dictionary) -> void: data["check"]["wallet"] += 1,
	}
	for name in cases:
		var data := good.duplicate(true)
		cases[name].call(data)
		assert_null(RunSave.from_data(content, data), name)
	assert_true(RunSave.from_data(content, good) != null, "the good data still loads")


func test_a_run_changed_by_new_rules_is_rejected() -> void:
	var game := Bot.play_run(content, 9, &"combo")
	var data := RunSave.to_data(game)
	var changed := GameContent.load_from()
	changed.config = changed.config.duplicate()
	changed.config.accept_acceptance += 1
	assert_null(RunSave.from_data(changed, data))


## Saved, written as JSON, read back and played again.
func _through_json(game: Game, rules: GameContent = content) -> Game:
	var text := JSON.stringify(RunSave.to_data(game))
	return RunSave.from_data(rules, JSON.parse_string(text))


func _fingerprint(game: Game) -> Array:
	var s := game.state
	var orders: Array = []
	for order in s.orders:
		orders.append([order.id, order.dish.id, order.client, order.deadline, order.pay, order.picked_up])
	var offers: Array = []
	for offer in s.offers:
		offers.append([offer.id, offer.restaurant, offer.parts.size()])
	return [s.phase, s.night, s.turn, s.wallet, s.rating_tenths, s.acceptance, s.profile, s.event,
			s.next_event, s.deck, s.equipment, s.piles.hand, s.piles.draw_pile, s.piles.discard_pile,
			s.courier_position, s.steps, s.paid_cards_played, s.history.size(), s.total_earnings,
			s.city.snapshot(), s.bag.to_text(), s.bag.aside_items().size(), orders, offers, s.actions,
			s.rng._rng.state]


## A run played with random actions (some refused), stopped after this many attempts.
func _random_run(seed: int, attempts: int) -> Game:
	var game := Game.new_run(generous, seed)
	var dice := GameRng.new(seed * 101)
	var profiles := generous.profile_ids()
	game.choose_profile(profiles[dice.range_int(0, profiles.size() - 1)])
	var s := game.state
	for i in attempts:
		match s.phase:
			GameState.Phase.CHOOSING_REWARD:
				game.choose_reward(dice.range_int(0, s.reward_choices.size() - 1))
			GameState.Phase.SHOPPING:
				if dice.chance(0.6):
					game.buy(dice.range_int(0, s.shop.items.size() - 1))
				else:
					game.start_next_night()
			GameState.Phase.PLAYING:
				_random_action(game, dice)
			_:
				break
	return game


func _random_action(game: Game, dice: GameRng) -> void:
	var s := game.state
	if s.bag.held != null:
		match dice.range_int(0, 4):
			0:
				game.rotate_held()
			1:
				game.set_held_aside()
			2:
				game.cancel_held()
			_:
				game.drop_held(dice.range_int(0, s.bag.columns - 1))
		return
	match dice.range_int(0, 8):
		0:
			if not s.offers.is_empty():
				game.accept_offer(dice.pick(s.offers).id)
		1, 2:
			if not s.piles.hand.is_empty():
				game.play_card(dice.range_int(0, s.piles.hand.size() - 1))
		3, 4:
			var targets := game.reachable()
			if not targets.is_empty():
				game.move_to(dice.pick(targets))
		5:
			for order in s.orders:
				game.take_dish(order.id)
		6:
			if not s.bag.items().is_empty():
				game.lift(dice.pick(s.bag.items()).order_id)
			elif not s.bag.aside_items().is_empty():
				game.take_from_aside(dice.pick(s.bag.aside_items()).order_id)
		_:
			game.end_turn()
