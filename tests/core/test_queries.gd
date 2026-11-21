extends TestCase
## The questions the interface asks before offering an action (offer_problem(), move_problem()...):
## they give the same answer as the action itself and change nothing.

var f: GameFixture


func before_each() -> void:
	f = GameFixture.start()


func test_offer_problem() -> void:
	var offer := f.add_offer(&"pizza", GameFixture.CLIENT_1)
	assert_eq(f.game.offer_problem(offer.id), Game.Problem.NONE)
	assert_eq(f.state.offers.size(), 1, "asking changes nothing")
	assert_eq(f.game.offer_problem(999), Game.Problem.NO_SUCH_OFFER)
	for client in [GameFixture.CLIENT_2, GameFixture.CLIENT_3, GameFixture.CLIENT_4, GameFixture.CLIENT_2]:
		f.add_order(&"soda", client)
	assert_eq(f.game.offer_problem(offer.id), Game.Problem.TOO_MANY_ORDERS)
	assert_eq(f.game.accept_offer(offer.id), Game.Problem.TOO_MANY_ORDERS)


func test_move_problem() -> void:
	f.state.steps = 2
	assert_eq(f.game.move_problem(Vector2i(2, 0)), Game.Problem.NONE)
	assert_eq(f.state.steps, 2, "asking changes nothing")
	assert_eq(f.state.courier_position, GameFixture.BASE)
	assert_eq(f.game.move_problem(GameFixture.CLIENT_1), Game.Problem.TOO_FAR)
	assert_eq(f.game.move_problem(GameFixture.BASE), Game.Problem.SAME_PLACE)
	var order := f.add_order(&"pizza", GameFixture.CLIENT_1)
	f.state.courier_position = GameFixture.RESTAURANT
	f.game.take_dish(order.id)
	assert_eq(f.game.move_problem(GameFixture.BASE), Game.Problem.SORTING)


func test_take_dish_problem() -> void:
	var first := f.add_order(&"pizza", GameFixture.CLIENT_1)
	var second := f.add_order(&"pizza", GameFixture.CLIENT_2)
	assert_eq(f.game.take_dish_problem(first.id), Game.Problem.NOT_AT_RESTAURANT)
	f.state.courier_position = GameFixture.RESTAURANT
	assert_eq(f.game.take_dish_problem(first.id), Game.Problem.NONE)
	assert_false(first.picked_up, "asking changes nothing")
	f.game.take_dish(first.id)
	assert_eq(f.game.take_dish_problem(first.id), Game.Problem.ALREADY_PICKED_UP)
	assert_eq(f.game.take_dish_problem(second.id), Game.Problem.HAND_BUSY)
	assert_eq(f.game.take_dish(second.id), Game.Problem.HAND_BUSY)
	assert_false(second.picked_up)
	assert_eq(f.game.take_dish_problem(999), Game.Problem.NO_SUCH_ORDER)


func test_end_turn_problem() -> void:
	assert_eq(f.game.end_turn_problem(), Game.Problem.NONE)
	var order := f.add_order(&"pizza", GameFixture.CLIENT_1)
	f.state.courier_position = GameFixture.RESTAURANT
	f.game.take_dish(order.id)
	assert_eq(f.game.end_turn_problem(), Game.Problem.NONE, "a dish from the restaurant goes back by itself")
	f.game.set_held_aside()
	assert_eq(f.game.end_turn_problem(), Game.Problem.NONE, "set aside here: it can go back to the restaurant")
	f.state.bag.leave_stop()
	assert_eq(f.game.end_turn_problem(), Game.Problem.SORTING, "carried since an earlier stop")
	assert_eq(f.state.turn, 1, "asking changes nothing")


func test_buy_problem() -> void:
	assert_eq(f.game.buy_problem(0), Game.Problem.WRONG_PHASE)
	f.open_shop()
	f.state.wallet = 0
	assert_eq(f.game.buy_problem(0), Game.Problem.NOT_ENOUGH_MONEY)
	assert_eq(f.game.buy_problem(99), Game.Problem.NO_SUCH_REWARD)
	f.state.wallet = 1000
	assert_eq(f.game.buy_problem(0), Game.Problem.NONE)
	assert_false(f.state.shop.items[0].sold, "asking changes nothing")
	f.game.buy(0)
	assert_eq(f.game.buy_problem(0), Game.Problem.ALREADY_BOUGHT)


func test_order_events_keep_the_order() -> void:
	var order := f.add_order(&"soda", GameFixture.CLIENT_1, 5)
	f.carry(order)
	f.state.courier_position = GameFixture.CLIENT_1
	f.game.end_turn()
	f.state.steps = 1
	f.state.courier_position = Vector2i(2, 0)
	f.game.move_to(GameFixture.CLIENT_1)
	var delivered := f.events(GameEvent.Kind.DELIVERED)
	assert_eq(delivered.size(), 1)
	assert_true(delivered[0].order == order, "the delivered order is kept for the feed")
	var late := f.add_order(&"soda", GameFixture.CLIENT_2, -2)
	f.game.end_turn()
	var cancelled := f.events(GameEvent.Kind.CANCELLED)
	assert_eq(cancelled.size(), 1)
	assert_true(cancelled[0].order == late)


func test_reachable() -> void:
	assert_true(f.game.reachable().is_empty(), "no step, nowhere to go")
	f.state.steps = 2
	var reachable := f.game.reachable()
	assert_true(Vector2i(2, 0) in reachable)
	assert_false(GameFixture.BASE in reachable, "not where the courier already is")
	for crossroads in reachable:
		assert_eq(f.game.move_problem(crossroads), Game.Problem.NONE)
	var order := f.add_order(&"pizza", GameFixture.CLIENT_1)
	f.state.courier_position = GameFixture.RESTAURANT
	f.game.take_dish(order.id)
	assert_true(f.game.reachable().is_empty(), "a dish in hand: no ride")


func test_take_from_aside_problem() -> void:
	var order := f.add_order(&"pizza", GameFixture.CLIENT_1)
	assert_eq(f.game.take_from_aside_problem(order.id), Game.Problem.NOT_ASIDE)
	f.state.courier_position = GameFixture.RESTAURANT
	f.game.take_dish(order.id)
	assert_eq(f.game.take_from_aside_problem(order.id), Game.Problem.HAND_BUSY)
	f.game.set_held_aside()
	assert_eq(f.game.take_from_aside_problem(order.id), Game.Problem.NONE)
	assert_eq(f.state.bag.location_of(order.id), Bag.Location.ASIDE, "asking changes nothing")


## The feed may show a night start later: the event of that night stays with it.
func test_night_started_keeps_its_event() -> void:
	f.open_shop()
	f.game.start_next_night()
	var started := f.events(GameEvent.Kind.NIGHT_STARTED)
	assert_eq(started.size(), 1)
	assert_eq(started[0].source, f.state.event)
	assert_true(started[0].source != &"", "an event was drawn for the night")
