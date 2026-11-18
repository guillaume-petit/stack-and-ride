extends TestCase
## End of the turn (design doc §4, §7.4).

var f: GameFixture


func before_each() -> void:
	f = GameFixture.start()
	f.state.config = f.state.config.duplicate()


func test_the_next_turn_starts() -> void:
	f.give_cards([&"ped2"])
	assert_eq(f.game.end_turn(), Game.Problem.NONE)
	assert_eq([f.state.night, f.state.turn], [1, 2])
	assert_eq(f.state.piles.hand.size(), 4, "hand completed to 4")
	assert_eq(f.state.piles.hand[0], &"ped2", "cards not played stay in hand")
	assert_eq(f.state.offers.size(), 2, "the app fills up")


func test_turn_counters_are_reset() -> void:
	var loose := f.carry(f.add_order(&"soda", GameFixture.CLIENT_1))
	f.give_cards([&"wrong", &"strap"])
	f.game.play_card(0)
	f.game.play_card(0)
	f.state.perfect_deliveries_this_turn = 2
	f.game.end_turn()
	assert_eq(f.state.steps, 0, "steps not used are lost")
	assert_eq(f.state.paid_cards_played, 0)
	assert_false(f.state.crossing_works)
	assert_eq(f.state.perfect_deliveries_this_turn, 0)
	assert_false(f.state.bag.braced, "the strap only lasts one turn")
	f.give_cards([&"sprint"])
	f.game.play_card(0)
	assert_true(loose.damaged)


func test_no_end_of_turn_with_a_dish_aside() -> void:
	var order := f.add_order(&"pizza", GameFixture.CLIENT_1)
	f.state.courier_position = GameFixture.RESTAURANT
	f.game.take_dish(order.id)
	f.game.set_held_aside()
	assert_eq(f.game.end_turn(), Game.Problem.SORTING)
	assert_eq(f.state.turn, 1)
	f.game.take_from_aside(order.id)
	assert_eq(f.game.end_turn(), Game.Problem.SORTING, "a dish taken from aside does not go back by itself")


func test_a_dish_in_hand_goes_back_by_itself() -> void:
	var waiting := f.add_order(&"pizza", GameFixture.CLIENT_1)
	var carried := f.add_order(&"burger", GameFixture.CLIENT_2)
	f.carry(carried, 0)
	f.game.lift(carried.id)
	assert_eq(f.game.end_turn(), Game.Problem.NONE)
	assert_eq(f.state.bag.to_text(), PackedStringArray(["....", "....", "22.."]), "back in its place")
	f.state.courier_position = GameFixture.RESTAURANT
	f.game.take_dish(waiting.id)
	assert_eq(f.game.end_turn(), Game.Problem.NONE)
	assert_false(waiting.picked_up, "back at the restaurant")
	assert_eq(f.state.turn, 3)


func test_ignored_offers_cost_5_points_each() -> void:
	f.add_offer(&"pizza", GameFixture.CLIENT_1)
	f.add_offer(&"pizza", GameFixture.CLIENT_2)
	f.game.end_turn()
	assert_eq(f.state.acceptance, 90)
	var ignored := f.events(GameEvent.Kind.OFFERS_IGNORED)
	assert_eq(ignored.size(), 1)
	assert_eq(ignored[0].value, 2)
	f.state.offers.clear()
	f.game.end_turn()
	assert_eq(f.state.acceptance, 90, "nothing to ignore")


func test_every_order_loses_a_turn() -> void:
	var waiting := f.add_order(&"pizza", GameFixture.CLIENT_1, 3)
	var carried := f.add_order(&"soda", GameFixture.CLIENT_2, 0)
	f.carry(carried)
	f.game.end_turn()
	assert_eq([waiting.deadline, carried.deadline], [2, -1])


func test_client_cancels_below_minus_2() -> void:
	var patient := f.add_order(&"pizza", GameFixture.CLIENT_1, -1)
	var angry := f.add_order(&"pizza", GameFixture.CLIENT_2, -2)
	f.carry(angry, 0)
	f.carry(f.add_order(&"burger", GameFixture.CLIENT_3), 0)
	f.game.end_turn()
	assert_eq(f.state.orders.size(), 2)
	assert_true(f.state.orders.has(patient), "-2 is still waiting")
	assert_false(f.state.orders.has(angry))
	assert_eq(f.state.rating_tenths, 45)
	assert_eq(f.state.bag.to_text(), PackedStringArray(["....", "....", "33.."]), "the burger fell")
	var cancelled := f.events(GameEvent.Kind.CANCELLED)
	assert_eq(cancelled.size(), 1)
	assert_eq([cancelled[0].order_id, cancelled[0].rating_tenths], [angry.id, -5])


func test_darling_loses_more_on_cancellation() -> void:
	f = GameFixture.start(&"darling")
	f.add_order(&"pizza", GameFixture.CLIENT_1, -2)
	f.game.end_turn()
	assert_eq(f.state.rating_tenths, 44)


func test_run_is_lost_below_4_stars() -> void:
	f.state.rating_tenths = 44
	f.add_order(&"pizza", GameFixture.CLIENT_1, -2)
	f.game.end_turn()
	assert_eq(f.state.phase, GameState.Phase.LOST)
	assert_eq(f.state.loss_reason, GameState.LossReason.RATING)
	assert_eq(f.game.end_turn(), Game.Problem.WRONG_PHASE)
	assert_eq(f.game.play_card(0), Game.Problem.WRONG_PHASE)


func test_exactly_4_stars_is_enough() -> void:
	f.state.rating_tenths = 40
	f.game.end_turn()
	assert_eq(f.state.phase, GameState.Phase.PLAYING)


func test_the_night_ends_after_the_10th_turn() -> void:
	f.state.wallet = 30
	f.state.turn = 10
	f.game.end_turn()
	assert_eq(f.state.phase, GameState.Phase.CHOOSING_REWARD)
	assert_eq([f.state.night, f.state.turn], [1, 10])
	assert_eq(f.state.wallet, 5, "rent of night 1: 25 €")
	assert_eq(f.events(GameEvent.Kind.NIGHT_ENDED).size(), 1)


func test_a_refused_end_of_turn_changes_nothing() -> void:
	var aside := f.add_order(&"burger", GameFixture.CLIENT_1)
	var in_hand := f.add_order(&"pizza", GameFixture.CLIENT_2)
	f.state.courier_position = GameFixture.RESTAURANT
	f.game.take_dish(aside.id)
	f.game.set_held_aside()
	f.game.take_dish(in_hand.id)
	assert_eq(f.game.end_turn(), Game.Problem.SORTING)
	assert_eq(f.state.bag.held.order_id, in_hand.id, "the dish stays in hand")
	assert_true(in_hand.picked_up)
