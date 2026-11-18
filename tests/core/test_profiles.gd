extends TestCase
## The four profiles, each through the game rules (design doc §11).


func test_mule_has_a_wide_bag_but_slows_down_when_loaded() -> void:
	var f := GameFixture.start(&"mule")
	assert_eq(f.state.bag.columns, 5)
	for i in 3:
		f.carry(f.add_order(&"soda", GameFixture.CLIENT_1), i)
	f.give_cards([&"ped3"])
	f.game.play_card(0)
	assert_eq(f.state.steps, 2)


func test_sprinter_has_a_narrow_bag_an_extra_sprint_and_never_shakes() -> void:
	var f := GameFixture.start(&"sprinter")
	assert_eq(f.state.bag.columns, 3)
	assert_eq(f.state.deck.count(&"sprint"), 2)
	var loose := f.carry(f.add_order(&"soda", GameFixture.CLIENT_1))
	f.give_cards([&"scooter"])
	f.game.play_card(0)
	assert_false(loose.damaged)


func test_sprinter_still_shakes_on_paved_streets() -> void:
	var f := GameFixture.start(&"sprinter", ["B~+"] as Array[String])
	var loose := f.carry(f.add_order(&"soda", Vector2i(1, 0)))
	f.state.steps = 1
	f.game.move_to(Vector2i(1, 0))
	assert_true(f.state.history.any(func(e: GameEvent) -> bool: return e.kind == GameEvent.Kind.SHAKE))
	assert_eq(f.state.orders, [], "delivered after the shake")
	assert_true(f.events(GameEvent.Kind.DELIVERED)[0].delivery.outcome == Delivery.Outcome.DAMAGED)
	assert_true(loose.damaged)


func test_darling_doubles_tips_and_pays_more_for_problems() -> void:
	var f := GameFixture.start(&"darling")
	f.carry(f.add_order(&"pizza", GameFixture.CLIENT_1, 3, 12))
	f.state.steps = 3
	f.state.rating_tenths = 45
	f.game.move_to(GameFixture.CLIENT_1)
	assert_eq(f.state.wallet, 18, "12 € + 3 × 2 €")
	f.add_order(&"pizza", GameFixture.CLIENT_2, -2)
	f.game.end_turn()
	assert_eq(f.state.rating_tenths, 40, "4.6 - 0.6 for the cancellation")


func test_combo_king_earns_more_with_each_perfect_delivery_of_the_turn() -> void:
	var f := GameFixture.start(&"combo")
	f.carry(f.add_order(&"soda", GameFixture.CLIENT_1, 0, 5), 0)
	f.carry(f.add_order(&"soda", GameFixture.CLIENT_2, 0, 5), 1)
	f.carry(f.add_order(&"soda", GameFixture.CLIENT_3, 1, 5), 2)
	f.state.steps = 3
	f.game.move_to(GameFixture.CLIENT_1)
	f.state.steps = 2
	f.game.move_to(GameFixture.CLIENT_2)
	assert_eq(f.state.wallet, 13)
	f.game.end_turn()
	f.state.steps = 3
	f.game.move_to(GameFixture.CLIENT_3)
	assert_eq(f.state.wallet, 18, "a new turn starts the count again")
