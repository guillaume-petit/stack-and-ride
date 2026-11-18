extends TestCase
## Playing cards (design doc §4, §8.3).

var f: GameFixture


func before_each() -> void:
	f = GameFixture.start()


func test_a_card_gives_its_steps_and_goes_to_the_discard_pile() -> void:
	f.give_cards([&"ped2", &"ped3"])
	assert_eq(f.game.play_card(1), Game.Problem.NONE)
	assert_eq(f.state.steps, 3)
	assert_eq(f.state.piles.hand, [&"ped2"])
	assert_eq(f.state.piles.discard_pile, [&"ped3"])
	assert_eq(f.state.paid_cards_played, 1)
	f.game.play_card(0)
	assert_eq(f.state.steps, 5, "steps add up")


func test_at_most_2_non_free_cards_per_turn() -> void:
	f.give_cards([&"ped2", &"ped2", &"ped2", &"coffee"])
	f.state.piles.draw_pile = [] as Array[StringName]
	f.game.play_card(0)
	f.game.play_card(0)
	assert_eq(f.game.card_problem(0), Game.Problem.CARD_LIMIT)
	assert_eq(f.game.play_card(0), Game.Problem.CARD_LIMIT)
	assert_eq(f.state.steps, 4, "nothing changes")
	assert_eq(f.game.play_card(1), Game.Problem.NONE, "free cards do not count")
	assert_eq(f.state.paid_cards_played, 2)


func test_battery_allows_a_third_card() -> void:
	f.equip(&"battery")
	f.give_cards([&"ped2", &"ped2", &"ped2", &"ped2"])
	for i in 3:
		assert_eq(f.game.play_card(0), Game.Problem.NONE)
	assert_eq(f.game.play_card(0), Game.Problem.CARD_LIMIT)


func test_orange_light_gives_more_after_a_non_free_card() -> void:
	f.give_cards([&"orange", &"orange", &"coffee"])
	f.state.piles.draw_pile = [] as Array[StringName]
	assert_eq(f.game.card_steps(&"orange"), 2)
	f.game.play_card(2)
	assert_eq(f.game.card_steps(&"orange"), 2, "a free card does not count")
	f.game.play_card(0)
	assert_eq(f.state.steps, 2)
	assert_eq(f.game.card_steps(&"orange"), 4)
	f.game.play_card(0)
	assert_eq(f.state.steps, 6)


func test_ebike_and_rain_change_the_steps() -> void:
	f.equip(&"ebike")
	assert_eq(f.game.card_steps(&"ped2"), 3)
	f.set_event(&"rain")
	assert_eq(f.game.card_steps(&"ped2"), 2)
	assert_eq(f.game.card_steps(&"kebab"), 0, "cards without steps stay at 0")


func test_a_card_gives_at_least_one_step() -> void:
	f.set_event(&"rain")
	f.state.effects.card_steps = -5
	assert_eq(f.game.card_steps(&"ped2"), 1)


func test_mule_loses_a_step_with_3_dishes_in_the_bag() -> void:
	f = GameFixture.start(&"mule")
	f.carry(f.add_order(&"soda", GameFixture.CLIENT_1), 0)
	f.carry(f.add_order(&"soda", GameFixture.CLIENT_2), 1)
	assert_eq(f.game.card_steps(&"ped3"), 3, "2 dishes")
	f.carry(f.add_order(&"soda", GameFixture.CLIENT_3), 2)
	assert_eq(f.game.card_steps(&"ped3"), 2, "3 dishes")


func test_drawing_cards() -> void:
	f.give_cards([&"kebab", &"coffee"])
	f.state.piles.draw_pile = [&"a", &"b", &"c", &"d", &"e"] as Array[StringName]
	f.game.play_card(0)
	assert_eq(f.state.piles.hand, [&"coffee", &"e", &"d", &"c"], "Pause kebab draws 3")
	f.game.play_card(0)
	assert_eq(f.state.piles.hand, [&"e", &"d", &"c", &"b", &"a"], "Café serré draws 2")
	assert_eq(f.state.paid_cards_played, 1)


func test_phone_call_gives_a_turn_to_every_order() -> void:
	var waiting := f.add_order(&"pizza", GameFixture.CLIENT_1, 3)
	var carried := f.add_order(&"soda", GameFixture.CLIENT_2, -1)
	f.carry(carried)
	f.give_cards([&"call"])
	f.game.play_card(0)
	assert_eq([waiting.deadline, carried.deadline], [4, 0])
	assert_eq(f.events(GameEvent.Kind.DEADLINES_EXTENDED).size(), 1)
	assert_eq(f.state.steps, 0)


func test_strap_braces_the_bag_for_free() -> void:
	f.give_cards([&"strap"])
	f.game.play_card(0)
	assert_true(f.state.bag.braced)
	assert_eq(f.state.paid_cards_played, 0)


func test_wrong_way_crosses_works_and_costs_a_tenth() -> void:
	f.give_cards([&"wrong"])
	f.game.play_card(0)
	assert_eq(f.state.steps, 3)
	assert_true(f.state.crossing_works)
	assert_eq(f.state.rating_tenths, 49)
	var reports := f.events(GameEvent.Kind.CARD_RATING_COST)
	assert_eq(reports.size(), 1)
	assert_eq([reports[0].source, reports[0].rating_tenths], [&"wrong", -1])


func test_gilet_makes_the_wrong_way_free() -> void:
	f.equip(&"gilet")
	f.give_cards([&"wrong"])
	f.game.play_card(0)
	assert_eq(f.state.rating_tenths, 50)
	assert_eq(f.events(GameEvent.Kind.CARD_RATING_COST), [])


func test_fatigue_does_nothing_but_counts_and_leaves_the_game() -> void:
	f.give_cards([&"fatigue"])
	f.game.play_card(0)
	assert_eq(f.state.steps, 0)
	assert_eq(f.state.paid_cards_played, 1)
	assert_eq(f.state.piles.discard_pile, [], "removed from the game")


func test_sprint_shakes_and_tires() -> void:
	var loose := f.carry(f.add_order(&"soda", GameFixture.CLIENT_1))
	f.give_cards([&"sprint"])
	f.game.play_card(0)
	assert_eq(f.state.steps, 5)
	assert_eq(f.state.piles.discard_pile, [&"sprint", &"fatigue"])
	assert_true(loose.damaged)
	var shakes := f.events(GameEvent.Kind.SHAKE)
	assert_eq(shakes.size(), 1)
	assert_eq([shakes[0].source, shakes[0].order_ids], [&"sprint", [loose.order_id]])


func test_scooter_shakes_without_tiring() -> void:
	var loose := f.carry(f.add_order(&"soda", GameFixture.CLIENT_1))
	f.give_cards([&"scooter"])
	f.game.play_card(0)
	assert_eq(f.state.steps, 6)
	assert_eq(f.state.piles.discard_pile, [&"scooter"])
	assert_true(loose.damaged)


func test_strap_cancels_the_sprint_shake() -> void:
	var loose := f.carry(f.add_order(&"soda", GameFixture.CLIENT_1))
	f.give_cards([&"strap", &"sprint"])
	f.game.play_card(0)
	f.game.play_card(0)
	assert_false(loose.damaged)
	assert_true(f.events(GameEvent.Kind.SHAKE)[0].braced)


func test_sprinter_cards_never_shake() -> void:
	f = GameFixture.start(&"sprinter")
	var loose := f.carry(f.add_order(&"soda", GameFixture.CLIENT_1))
	f.give_cards([&"sprint"])
	f.game.play_card(0)
	assert_false(loose.damaged)
	assert_eq(f.events(GameEvent.Kind.SHAKE), [])
	assert_eq(f.state.piles.discard_pile, [&"sprint", &"fatigue"], "still tired")


func test_unknown_card_index() -> void:
	f.give_cards([&"ped2"])
	assert_eq(f.game.play_card(1), Game.Problem.NO_SUCH_CARD)
	assert_eq(f.game.play_card(-1), Game.Problem.NO_SUCH_CARD)
