extends TestCase
## End of the night and start of the next one (design doc §9).

var f: GameFixture


func before_each() -> void:
	f = GameFixture.start()


func test_undelivered_orders_cost_rating_then_the_rent_is_paid() -> void:
	f.state.rating_tenths = 48
	f.state.night_earnings = 40
	f.add_order(&"pizza", GameFixture.CLIENT_1)
	f.carry(f.add_order(&"soda", GameFixture.CLIENT_2))
	var rent := f.state.rent_tonight()
	f.finish_night(rent + 5)
	assert_eq(f.state.rating_tenths, 44)
	assert_eq(f.state.wallet, 5)
	var summary: NightSummary = f.state.night_summaries.back()
	assert_eq([summary.night, summary.event, summary.earnings], [1, &"calm", 40])
	assert_eq([summary.undelivered, summary.rating_before, summary.rating_after], [2, 48, 44])
	assert_eq([summary.rent, summary.rent_paid, summary.shortfall, summary.wallet], [rent, true, 0, 5])
	assert_eq(f.state.orders, [])
	assert_true(f.state.bag.is_empty())
	assert_eq(f.state.courier_position, GameFixture.BASE)


func test_unpaid_rent_loses_the_run() -> void:
	f.finish_night(f.state.rent_tonight() - 5)
	assert_eq(f.state.phase, GameState.Phase.LOST)
	assert_eq(f.state.loss_reason, GameState.LossReason.RENT)
	assert_eq(f.state.wallet, 0)
	assert_eq(f.state.night_summaries[0].shortfall, 5)
	assert_false(f.state.night_summaries[0].rent_paid)


func test_rent_is_checked_before_the_rating() -> void:
	f.state.rating_tenths = 40
	f.add_order(&"pizza", GameFixture.CLIENT_1)
	f.finish_night(0)
	assert_eq(f.state.loss_reason, GameState.LossReason.RENT)


func test_rating_below_4_after_the_penalties_loses() -> void:
	f.state.rating_tenths = 41
	f.add_order(&"pizza", GameFixture.CLIENT_1)
	f.finish_night(f.state.rent_tonight() + 75)
	assert_eq(f.state.phase, GameState.Phase.LOST)
	assert_eq(f.state.loss_reason, GameState.LossReason.RATING)
	assert_eq(f.state.wallet, 75, "the rent was paid")


func test_the_6th_night_wins() -> void:
	f.state.night = 6
	f.finish_night(f.state.rent_tonight())
	assert_eq(f.state.phase, GameState.Phase.WON)
	assert_eq(f.state.wallet, 0)


func test_a_paid_night_offers_3_different_rewards_without_equipment() -> void:
	for seed in range(1, 21):
		f = GameFixture.start(GameFixture.NEUTRAL_PROFILE, GameFixture.CITY, &"pizza", seed)
		f.finish_night()
		assert_eq(f.state.phase, GameState.Phase.CHOOSING_REWARD)
		var choices := f.state.reward_choices
		assert_eq(choices.size(), 3)
		for i in choices.size():
			assert_ne(choices[i].kind, Reward.Kind.EQUIPMENT)
			for j in range(i + 1, choices.size()):
				assert_false(choices[i].equals(choices[j]), "different rewards")


func test_the_next_event_is_never_calm() -> void:
	var seen := {}
	for seed in range(1, 41):
		f = GameFixture.start(GameFixture.NEUTRAL_PROFILE, GameFixture.CITY, &"pizza", seed)
		f.finish_night()
		assert_ne(f.state.next_event, &"calm")
		seen[f.state.next_event] = true
	assert_eq(seen.size(), 5, "every other event can be drawn")


func test_the_next_night_starts_with_the_announced_event() -> void:
	f.open_shop()
	var event := f.state.next_event
	assert_eq(f.game.start_next_night(), Game.Problem.NONE)
	assert_eq(f.state.phase, GameState.Phase.PLAYING)
	assert_eq([f.state.night, f.state.turn], [2, 1])
	assert_eq(f.state.event, event)
	assert_eq(f.state.next_event, &"")
	assert_null(f.state.shop)
	assert_eq(f.state.piles.hand.size(), 4)
	assert_eq(f.state.night_earnings, 0)


func test_rent_of_tomorrow() -> void:
	assert_eq(f.state.rent_tomorrow(), f.state.config.rent_for_night(2))
	f.state.night = 6
	assert_eq(f.state.rent_tomorrow(), 0)


func test_night_actions_are_refused_between_nights() -> void:
	f.finish_night()
	assert_eq(f.game.end_turn(), Game.Problem.WRONG_PHASE)
	assert_eq(f.game.start_next_night(), Game.Problem.WRONG_PHASE, "pick a reward first")
	assert_eq(f.game.buy(0), Game.Problem.WRONG_PHASE)
