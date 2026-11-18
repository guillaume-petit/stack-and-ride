extends TestCase
## Deliveries during the game: when they happen and what they change (design doc §6.7, §7).
## A delivery only happens where the courier stops, and the steps left are lost.

var f: GameFixture


func before_each() -> void:
	f = GameFixture.start()


func test_arriving_at_the_client_delivers() -> void:
	var order := f.add_order(&"pizza", GameFixture.CLIENT_1, 3, 12)
	f.carry(order)
	f.state.steps = 5
	f.state.rating_tenths = 45
	assert_eq(f.game.move_to(GameFixture.CLIENT_1), Game.Problem.NONE)
	assert_eq(f.state.orders, [])
	assert_true(f.state.bag.is_empty())
	assert_eq(f.state.wallet, 15, "12 € + 3 € of tip")
	assert_eq([f.state.night_earnings, f.state.total_earnings], [15, 15])
	assert_eq(f.state.rating_tenths, 46)
	assert_eq(f.state.steps, 0, "the steps left are lost")
	assert_eq(f.state.perfect_deliveries_this_turn, 1)
	var delivered := f.events(GameEvent.Kind.DELIVERED)
	assert_eq(delivered.size(), 1)
	assert_eq([delivered[0].order_id, delivered[0].delivery.total()], [order.id, 15])


func test_rating_never_goes_over_5() -> void:
	f.carry(f.add_order(&"pizza", GameFixture.CLIENT_1))
	f.state.steps = 3
	f.game.move_to(GameFixture.CLIENT_1)
	assert_eq(f.state.rating_tenths, 50)


func test_passing_by_does_not_deliver() -> void:
	f = GameFixture.start(GameFixture.NEUTRAL_PROFILE, ["B-C-+"] as Array[String])
	var order := f.add_order(&"soda", Vector2i(1, 0))
	f.carry(order)
	f.state.steps = 3
	f.game.move_to(Vector2i(2, 0))
	assert_eq(f.state.orders, [order])
	assert_eq(f.state.steps, 1)
	f.game.move_to(Vector2i(1, 0))
	assert_eq(f.state.orders, [], "stopping there delivers")


func test_a_waiting_order_is_not_delivered() -> void:
	var order := f.add_order(&"pizza", GameFixture.CLIENT_1)
	f.state.steps = 3
	f.game.move_to(GameFixture.CLIENT_1)
	assert_eq(f.state.orders, [order])
	assert_eq(f.state.steps, 0, "3 steps spent riding")


func test_dropping_the_dish_at_the_client_delivers() -> void:
	var order := f.add_order(&"pizza", GameFixture.CLIENT_1)
	order.picked_up = true
	f.state.bag.take_from_restaurant(BagItem.new(order.id, order.dish))
	f.state.courier_position = GameFixture.CLIENT_1
	f.state.steps = 2
	assert_eq(f.game.drop_held(0), Game.Problem.NONE)
	assert_eq(f.state.orders, [])
	assert_eq(f.state.steps, 0)


func test_a_dish_in_hand_or_aside_is_not_delivered() -> void:
	var order := f.add_order(&"pizza", GameFixture.CLIENT_1)
	order.picked_up = true
	f.state.bag.take_from_restaurant(BagItem.new(order.id, order.dish))
	f.state.courier_position = GameFixture.CLIENT_1
	f.give_cards([&"strap", &"strap"])
	f.game.play_card(0)
	assert_eq(f.state.orders, [order], "in hand")
	f.game.set_held_aside()
	f.game.play_card(0)
	assert_eq(f.state.orders, [order], "aside")


func test_fifth_floor_needs_a_step() -> void:
	var order := f.add_order(&"pizza", GameFixture.CLIENT_1, 3, 12)
	order.modifiers.fifth_floor = true
	f.carry(order)
	f.state.steps = 3
	f.game.move_to(Vector2i(2, 0))
	f.game.move_to(GameFixture.CLIENT_1)
	assert_eq(f.state.orders, [order], "no step left to climb")
	assert_eq(f.events(GameEvent.Kind.FIFTH_FLOOR_WAIT).size(), 1)
	f.give_cards([&"strap"])
	f.game.play_card(0)
	assert_eq(f.events(GameEvent.Kind.FIFTH_FLOOR_WAIT).size(), 1, "reported once")
	f.give_cards([&"ped2"])
	f.game.play_card(0)
	assert_eq(f.state.orders, [], "a card played on the spot delivers")
	assert_eq(f.state.steps, 0, "the card's steps are lost with the delivery")
	assert_eq(f.state.wallet, 15)


func test_fifth_floor_with_steps_left_delivers_on_arrival() -> void:
	var order := f.add_order(&"pizza", GameFixture.CLIENT_1)
	order.modifiers.fifth_floor = true
	f.carry(order)
	f.state.steps = 4
	f.game.move_to(GameFixture.CLIENT_1)
	assert_eq(f.state.orders, [])
	assert_eq(f.state.steps, 0)


func test_damaged_dish_is_delivered_without_tip() -> void:
	var order := f.add_order(&"pizza", GameFixture.CLIENT_1, 3, 12)
	f.carry(order).damaged = true
	f.state.steps = 3
	f.game.move_to(GameFixture.CLIENT_1)
	assert_eq(f.state.wallet, 12)
	assert_eq(f.state.rating_tenths, 48)


func test_cup_holder_dish_is_delivered() -> void:
	f.equip(&"cupholder")
	var order := f.add_order(&"soda", GameFixture.CLIENT_1)
	f.carry(order)
	assert_eq(f.state.bag.location_of(order.id), Bag.Location.CUP_HOLDER)
	f.state.steps = 3
	f.game.move_to(GameFixture.CLIENT_1)
	assert_eq(f.state.orders, [])


func test_combo_counts_the_perfect_deliveries_of_the_turn() -> void:
	f = GameFixture.start(&"combo")
	f.carry(f.add_order(&"soda", GameFixture.CLIENT_1, 0, 5), 0)
	f.carry(f.add_order(&"soda", GameFixture.CLIENT_2, 0, 5), 1)
	f.state.steps = 3
	f.game.move_to(GameFixture.CLIENT_1)
	assert_eq(f.state.wallet, 5)
	f.state.steps = 2
	f.game.move_to(GameFixture.CLIENT_2)
	assert_eq(f.state.wallet, 13, "5 € + 3 € for the first perfect delivery of the turn")


func test_dishes_above_fall_and_crush_a_fragile_dish() -> void:
	f.equip(&"separator")
	var pizza := f.add_order(&"pizza", GameFixture.CLIENT_1)
	var soda := f.add_order(&"soda", GameFixture.CLIENT_2)
	var sushi := f.add_order(&"sushi", GameFixture.CLIENT_3)
	f.carry(pizza, 0)
	f.carry(soda, 2)
	f.carry(sushi, 0)
	assert_eq(f.state.bag.to_text(), PackedStringArray(["333.", "11..", "112."]))
	f.state.steps = 3
	f.game.move_to(GameFixture.CLIENT_1)
	assert_eq(f.state.bag.to_text(), PackedStringArray(["....", "333.", "..2."]))
	assert_true(f.state.bag.find(soda.id).damaged)
	var crushed := f.events(GameEvent.Kind.CRUSHED)
	assert_eq(crushed.size(), 1)
	assert_eq(crushed[0].order_ids, [soda.id])
