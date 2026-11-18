extends TestCase
## Moving through the city and taking dishes at the restaurant (design doc §3, §6.6, §6.8, §7.1).

var f: GameFixture


func before_each() -> void:
	f = GameFixture.start()


func test_moving_spends_one_step_per_street() -> void:
	f.state.steps = 3
	assert_eq(f.game.move_to(Vector2i(2, 0)), Game.Problem.NONE)
	assert_eq(f.state.courier_position, Vector2i(2, 0))
	assert_eq(f.state.steps, 1)


func test_moving_needs_enough_steps() -> void:
	f.state.steps = 1
	assert_eq(f.game.move_to(Vector2i(2, 0)), Game.Problem.TOO_FAR)
	assert_eq(f.state.courier_position, GameFixture.BASE)
	assert_eq(f.state.steps, 1)
	assert_eq(f.game.move_to(GameFixture.BASE), Game.Problem.SAME_PLACE)


func test_no_move_with_a_dish_in_hand_or_aside() -> void:
	f.state.steps = 3
	var order := f.add_order(&"pizza", GameFixture.CLIENT_1)
	f.state.courier_position = GameFixture.RESTAURANT
	f.game.take_dish(order.id)
	assert_eq(f.game.move_to(GameFixture.BASE), Game.Problem.SORTING)
	f.game.set_held_aside()
	assert_eq(f.game.move_to(GameFixture.BASE), Game.Problem.SORTING)


func test_road_works_force_a_detour_unless_wrong_way() -> void:
	f.state.courier_position = Vector2i(3, 1)
	f.state.steps = 3
	assert_eq(f.game.paths().distance_to(GameFixture.CLIENT_4), 3, "around the works")
	f.give_cards([&"wrong"])
	f.game.play_card(0)
	assert_eq(f.game.paths().distance_to(GameFixture.CLIENT_4), 1)
	assert_eq(f.game.move_to(GameFixture.CLIENT_4), Game.Problem.NONE)
	assert_eq(f.state.steps, 5)


func test_a_paved_street_shakes_the_bag_once_per_ride() -> void:
	f = GameFixture.start(GameFixture.NEUTRAL_PROFILE, ["B~+~+-C"] as Array[String])
	var loose := f.carry(f.add_order(&"soda", Vector2i(3, 0)))
	f.state.steps = 4
	f.game.move_to(Vector2i(2, 0))
	assert_true(loose.damaged)
	var shakes := f.events(GameEvent.Kind.SHAKE)
	assert_eq(shakes.size(), 1, "two paved streets, one shake")
	assert_eq(shakes[0].source, &"paved")
	f.game.move_to(Vector2i(1, 0))
	assert_eq(f.events(GameEvent.Kind.SHAKE).size(), 2, "a new ride shakes again")


func test_normal_streets_do_not_shake() -> void:
	f.state.steps = 2
	f.game.move_to(Vector2i(2, 0))
	assert_eq(f.events(GameEvent.Kind.SHAKE), [])


func test_suspension_fork_ignores_paved_streets() -> void:
	f = GameFixture.start(GameFixture.NEUTRAL_PROFILE, ["B~+~+"] as Array[String])
	f.equip(&"shocks")
	f.state.steps = 2
	f.game.move_to(Vector2i(2, 0))
	assert_eq(f.events(GameEvent.Kind.SHAKE), [])


func test_taking_a_dish_needs_to_be_at_its_restaurant() -> void:
	var order := f.add_order(&"pizza", GameFixture.CLIENT_1)
	assert_eq(f.game.take_dish(order.id), Game.Problem.NOT_AT_RESTAURANT)
	f.state.courier_position = GameFixture.RESTAURANT
	assert_eq(f.game.take_dish(order.id), Game.Problem.NONE)
	assert_true(order.picked_up)
	assert_eq(f.state.bag.held.order_id, order.id)
	assert_eq(f.game.take_dish(order.id), Game.Problem.ALREADY_PICKED_UP)
	assert_eq(f.game.take_dish(99), Game.Problem.NO_SUCH_ORDER)


func test_one_dish_in_hand_at_a_time() -> void:
	var first := f.add_order(&"pizza", GameFixture.CLIENT_1)
	var second := f.add_order(&"soda", GameFixture.CLIENT_2)
	f.state.courier_position = GameFixture.RESTAURANT
	f.game.take_dish(first.id)
	assert_eq(f.game.take_dish(second.id), Game.Problem.HAND_BUSY)
	assert_false(second.picked_up)


func test_cancelling_a_dish_from_the_restaurant_puts_it_back() -> void:
	var order := f.add_order(&"pizza", GameFixture.CLIENT_1)
	f.state.courier_position = GameFixture.RESTAURANT
	f.game.take_dish(order.id)
	assert_eq(f.game.cancel_held(), Game.Problem.NONE)
	assert_false(order.picked_up)
	assert_eq(f.state.bag.location_of(order.id), Bag.Location.NONE)
	assert_eq(f.game.cancel_held(), Game.Problem.NOTHING_HELD)


func test_soda_goes_to_the_cup_holder() -> void:
	f.equip(&"cupholder")
	var order := f.add_order(&"soda", GameFixture.CLIENT_1)
	f.state.courier_position = GameFixture.RESTAURANT
	f.game.take_dish(order.id)
	assert_eq(f.state.bag.location_of(order.id), Bag.Location.CUP_HOLDER)
	assert_false(f.state.bag.is_sorting())


func test_bag_actions_go_through_the_game() -> void:
	var pizza := f.add_order(&"pizza", GameFixture.CLIENT_1)
	var burger := f.add_order(&"burger", GameFixture.CLIENT_2)
	f.state.courier_position = GameFixture.RESTAURANT
	f.game.take_dish(pizza.id)
	assert_eq(f.game.drop_held(0), Game.Problem.NONE)
	assert_eq(f.state.bag.location_of(pizza.id), Bag.Location.BAG)
	f.game.take_dish(burger.id)
	assert_eq(f.game.rotate_held(), Game.Problem.NONE)
	assert_eq(f.game.set_held_aside(), Game.Problem.NONE)
	assert_eq(f.game.take_from_aside(pizza.id), Game.Problem.NOT_ASIDE)
	assert_eq(f.game.take_from_aside(burger.id), Game.Problem.NONE)
	assert_eq(f.game.drop_held(0), Game.Problem.NO_ROOM, "the vertical burger is 2 rows high")
	assert_eq(f.game.lift(pizza.id), Game.Problem.HAND_BUSY)
	assert_eq(f.game.drop_held(2), Game.Problem.NONE)
	assert_eq(f.game.lift(pizza.id), Game.Problem.NONE)
	assert_eq(f.game.drop_held(0), Game.Problem.NONE)
	assert_eq(f.game.lift(42), Game.Problem.NOT_IN_BAG)
	assert_eq(f.game.rotate_held(), Game.Problem.NOTHING_HELD)
