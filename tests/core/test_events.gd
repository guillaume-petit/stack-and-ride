extends TestCase
## The evening events (design doc §12).

var f: GameFixture


func before_each() -> void:
	f = GameFixture.start()


## Ends night 1 and starts night 2 with this event.
func _night_with(event: StringName) -> void:
	f.open_shop()
	f.state.next_event = event
	f.game.start_next_night()


func test_the_first_night_is_calm() -> void:
	assert_eq(f.state.event, &"calm")
	assert_eq(f.state.effects.extra_offers, 0)


func test_rain_brings_more_offers_better_pay_and_fewer_steps() -> void:
	_night_with(&"rain")
	assert_eq(f.state.offers.size(), 3)
	assert_eq(f.game.card_steps(&"ped3"), 2)
	assert_eq(f.state.effects.pay_multiplier, 1.3)


func test_match_brings_more_offers() -> void:
	_night_with(&"match")
	assert_eq(OfferMaker.offers_per_turn(f.state.config, f.state.effects, f.state.night), 3)
	assert_eq(f.state.effects.group_chance, 0.5)


func test_strike_gives_more_time() -> void:
	_night_with(&"strike")
	for offer in f.state.offers:
		for part in offer.parts:
			var distance := f.state.city.distance(offer.restaurant, part.client)
			var calm := OfferMaker.deadline(f.state.config, EffectData.new(), distance, offer.modifiers.urgent, false)
			assert_eq(part.deadline, calm + 2)


func test_heatwave_changes_cold_dishes() -> void:
	f = GameFixture.start(GameFixture.NEUTRAL_PROFILE, GameFixture.CITY, &"glacier")
	_night_with(&"heat")
	assert_eq(f.state.effects.cold_pay_multiplier, 1.5)
	assert_eq(f.state.effects.cold_deadline, -1)


func test_works_move_and_the_city_stays_connected() -> void:
	var content := GameContent.load_from()
	var game := Game.new_run(content, 5)
	game.choose_profile(&"darling")
	var before := game.state.city.streets_of(City.Street.WORKS)
	var paved := game.state.city.streets_of(City.Street.PAVED)
	game.state.turn = content.config.turns_per_night
	game.state.wallet = 100
	game.end_turn()
	game.choose_reward(0)
	game.state.next_event = &"works"
	game.start_next_night()
	var after := game.state.city.streets_of(City.Street.WORKS)
	assert_eq(after.size(), before.size())
	assert_ne(after, before)
	assert_eq(game.state.city.streets_of(City.Street.PAVED), paved, "paved streets stay")
	assert_true(game.state.city.is_fully_connected())
	assert_eq(game.state.history.filter(func(e: GameEvent) -> bool:
			return e.kind == GameEvent.Kind.WORKS_MOVED).size(), 1)


func test_the_event_lasts_one_night() -> void:
	_night_with(&"rain")
	f.state.wallet = 100
	f.state.turn = f.state.config.turns_per_night
	f.game.end_turn()
	f.game.choose_reward(0)
	f.state.next_event = &"strike"
	f.game.start_next_night()
	assert_eq(f.state.event, &"strike")
	assert_eq(f.state.effects.pay_multiplier, 1.0)
