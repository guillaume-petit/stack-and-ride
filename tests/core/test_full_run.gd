extends TestCase
## Whole runs played with random legal actions: they must reach the end without engine errors,
## and the same seeds must give the same run. Random play loses on night 1, so the "generous"
## runs cannot lose on rating and get money for the rent, to go through every night, reward
## and shop.

const MAX_ACTIONS := 20000


func test_random_runs_reach_the_end() -> void:
	var content := GameContent.load_from()
	for seed in range(1, 6):
		var game := _play(content, seed)
		assert_true(game.state.phase in [GameState.Phase.WON, GameState.Phase.LOST],
				"seed %d stopped at night %d, turn %d" % [seed, game.state.night, game.state.turn])


func test_generous_runs_go_through_the_six_nights() -> void:
	var content := GameContent.load_from()
	for seed in range(1, 6):
		var game := _play(content, seed, true)
		assert_eq(game.state.phase, GameState.Phase.WON, "seed %d" % seed)
		assert_eq(game.state.night_summaries.size(), 6)


func test_same_seed_same_run() -> void:
	var content := GameContent.load_from()
	var a := _play(content, 11, true)
	var b := _play(content, 11, true)
	assert_eq(_fingerprint(a), _fingerprint(b))


func _fingerprint(game: Game) -> Array:
	var s := game.state
	return [s.phase, s.night, s.turn, s.wallet, s.rating_tenths, s.acceptance, s.deck, s.equipment,
			s.history.size(), s.total_earnings, s.city.snapshot()]


## Plays a run with actions drawn by a second random source (actions may be refused).
func _play(content: GameContent, seed: int, generous: bool = false) -> Game:
	var game := Game.new_run(content, seed)
	if generous:
		game.state.config = game.state.config.duplicate()
		game.state.config.min_rating_tenths = 0
	var dice := GameRng.new(seed * 31)
	var profiles := content.profile_ids()
	game.choose_profile(profiles[dice.range_int(0, profiles.size() - 1)])
	var s := game.state
	for i in MAX_ACTIONS:
		match s.phase:
			GameState.Phase.CHOOSING_REWARD:
				game.choose_reward(dice.range_int(0, s.reward_choices.size() - 1))
			GameState.Phase.SHOPPING:
				if dice.chance(0.5):
					game.buy(dice.range_int(0, s.shop.items.size() - 1))
				else:
					game.start_next_night()
			GameState.Phase.PLAYING:
				if generous:
					s.wallet = maxi(s.wallet, s.rent_tonight() + 20)
				_play_action(game, dice)
			_:
				break
	return game


func _play_action(game: Game, dice: GameRng) -> void:
	var s := game.state
	if s.bag.held != null:
		if game.drop_held(dice.range_int(0, s.bag.columns - 1)) != Game.Problem.NONE and dice.chance(0.3):
			game.cancel_held()
		return
	match dice.range_int(0, 6):
		0:
			if not s.offers.is_empty():
				game.accept_offer(dice.pick(s.offers).id)
		1:
			if not s.piles.hand.is_empty():
				game.play_card(dice.range_int(0, s.piles.hand.size() - 1))
		2, 3:
			var targets := game.paths().reachable_within(s.steps)
			if not targets.is_empty():
				game.move_to(dice.pick(targets))
		4:
			for order in s.orders:
				if not order.picked_up and order.restaurant == s.courier_position:
					game.take_dish(order.id)
					return
		5:
			if not s.bag.items().is_empty():
				game.lift(dice.pick(s.bag.items()).order_id)
		6:
			game.end_turn()
