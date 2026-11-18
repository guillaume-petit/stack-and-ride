extends TestCase
## Start of a run: profile choice and start of the first night (design doc §2, §9, §11).

var content: GameContent


func before_each() -> void:
	content = GameContent.load_from()


func test_a_new_run_waits_for_the_profile() -> void:
	var game := Game.new_run(content, 1)
	assert_eq(game.state.phase, GameState.Phase.CHOOSE_PROFILE)
	assert_eq(game.end_turn(), Game.Problem.WRONG_PHASE)
	assert_eq(game.play_card(0), Game.Problem.WRONG_PHASE)


func test_unknown_profile_is_refused() -> void:
	var game := Game.new_run(content, 1)
	assert_eq(game.choose_profile(&"astronaut"), Game.Problem.UNKNOWN_PROFILE)
	assert_eq(game.state.phase, GameState.Phase.CHOOSE_PROFILE)


func test_choosing_a_profile_starts_the_first_night() -> void:
	var game := Game.new_run(content, 1)
	assert_eq(game.choose_profile(&"darling"), Game.Problem.NONE)
	var state := game.state
	assert_eq(state.phase, GameState.Phase.PLAYING)
	assert_eq(state.profile, &"darling")
	assert_eq([state.night, state.turn], [1, 1])
	assert_eq(state.event, &"calm")
	assert_eq(state.courier_position, state.city.base)
	assert_eq(state.piles.hand.size(), 4, "hand of 4 cards")
	assert_eq(state.piles.hand.size() + state.piles.draw_pile.size(), 10)
	assert_eq(state.offers.size(), 2, "2 offers on night 1")
	assert_eq(state.steps, 0)
	assert_eq(state.history[0].kind, GameEvent.Kind.NIGHT_STARTED)
	assert_eq(game.choose_profile(&"mule"), Game.Problem.WRONG_PHASE, "only once")


func test_profile_sets_the_bag_width() -> void:
	var mule := Game.new_run(content, 1)
	mule.choose_profile(&"mule")
	assert_eq([mule.state.bag.columns, mule.state.bag.rows], [5, 3])
	var sprinter := Game.new_run(content, 1)
	sprinter.choose_profile(&"sprinter")
	assert_eq(sprinter.state.bag.columns, 3)
	var darling := Game.new_run(content, 1)
	darling.choose_profile(&"darling")
	assert_eq(darling.state.bag.columns, 4, "default width")


func test_sprinter_gets_an_extra_sprint() -> void:
	var game := Game.new_run(content, 1)
	game.choose_profile(&"sprinter")
	assert_eq(game.state.deck.size(), 11)
	assert_eq(game.state.deck.count(&"sprint"), 2)
	assert_eq(content.config.starting_deck.size(), 10, "the config is not changed")


func test_profile_effects_apply() -> void:
	var game := Game.new_run(content, 1)
	game.choose_profile(&"combo")
	assert_eq(game.state.effects.streak_bonus, 3)


func test_same_seed_and_profile_give_the_same_start() -> void:
	var a := Game.new_run(content, 9)
	var b := Game.new_run(content, 9)
	a.choose_profile(&"mule")
	b.choose_profile(&"mule")
	assert_eq(a.state.piles.hand, b.state.piles.hand)
	assert_eq(a.state.offers[0].clients(), b.state.offers[0].clients())
	assert_eq(a.state.rng.get_state(), b.state.rng.get_state())
