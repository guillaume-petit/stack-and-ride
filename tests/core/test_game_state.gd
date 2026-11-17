extends TestCase
## A new run (design doc §2).

var content: GameContent


func before_each() -> void:
	content = GameContent.load_from()


func test_new_run_starts_with_the_design_values() -> void:
	var state := GameState.new_run(content, 1)
	assert_eq([state.night, state.turn], [1, 1])
	assert_eq(state.rating(), 5.0)
	assert_eq(state.acceptance, 100)
	assert_eq(state.wallet, 0)
	assert_eq([state.bag.columns, state.bag.rows], [4, 3])
	assert_true(state.bag.is_empty())
	assert_eq(state.event, &"calm")
	assert_eq(state.profile, &"")
	assert_eq(state.equipment, [])
	assert_eq(state.rent_tonight(), 25)


func test_courier_starts_at_the_base() -> void:
	var state := GameState.new_run(content, 2)
	assert_eq(state.courier_position, state.city.base)


func test_deck_is_a_copy_of_the_starting_deck() -> void:
	var state := GameState.new_run(content, 3)
	assert_eq(state.deck, content.config.starting_deck)
	state.deck.append(&"scooter")
	assert_eq(content.config.starting_deck.size(), 10, "the config must not change")


func test_same_seed_gives_the_same_run() -> void:
	var a := GameState.new_run(content, 77)
	var b := GameState.new_run(content, 77)
	assert_eq(a.city.snapshot(), b.city.snapshot())
	assert_eq(a.rng.get_state(), b.rng.get_state())


func test_rent_follows_the_night() -> void:
	var state := GameState.new_run(content, 4)
	state.night = 6
	assert_eq(state.rent_tonight(), 95)
