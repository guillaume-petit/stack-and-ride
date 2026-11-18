extends TestCase
## The offers of the app: drawing them, accepting and refusing (design doc §5).

var f: GameFixture


func before_each() -> void:
	f = GameFixture.start()
	f.state.config = f.state.config.duplicate()


func _draw_offers(count: int) -> Array[Offer]:
	var out: Array[Offer] = []
	for i in count:
		f.state.offers.clear()
		var offer := OfferMaker.make(f.state)
		if offer != null:
			out.append(offer)
	return out


func test_the_app_fills_up_at_the_start_of_each_turn() -> void:
	f.add_offer(&"pizza", GameFixture.CLIENT_1)
	f.game.end_turn()
	assert_eq(f.state.offers.size(), 2)
	for offer in f.state.offers:
		assert_true(offer.id > 1, "new offers get new ids")


func test_offer_content_follows_the_restaurant_and_the_formulas() -> void:
	for offer in _draw_offers(30):
		assert_eq(offer.restaurant, GameFixture.RESTAURANT)
		assert_eq(offer.restaurant_kind, &"pizza")
		for part in offer.parts:
			assert_true(part.dish.id in [&"pizza", &"soda"], "dish of the pizzeria menu")
			var distance := f.state.city.distance(offer.restaurant, part.client)
			var cold := part.dish.temperature == DishData.Temperature.COLD
			assert_eq(part.deadline, OfferMaker.deadline(f.state.config, f.state.effects, distance,
					offer.modifiers.urgent, cold))
			assert_eq(part.pay, OfferMaker.pay(f.state.config, f.state.effects, part.dish.cell_count(),
					distance, f.state.acceptance, offer.modifiers.urgent, offer.modifiers.grouped, cold))


func test_only_free_clients_get_offers() -> void:
	f.add_order(&"pizza", GameFixture.CLIENT_1)
	f.add_offer(&"pizza", GameFixture.CLIENT_2)
	f.add_order(&"pizza", GameFixture.CLIENT_3)
	assert_eq(OfferMaker.free_clients(f.state), [GameFixture.CLIENT_4])
	f.state.config.group_chance = 0.0
	var offer := OfferMaker.make(f.state)
	assert_eq(offer.clients(), [GameFixture.CLIENT_4])
	f.state.offers.append(offer)
	assert_null(OfferMaker.make(f.state), "no free client left")


func test_the_app_stops_when_no_client_is_free() -> void:
	for client in [GameFixture.CLIENT_1, GameFixture.CLIENT_2, GameFixture.CLIENT_3]:
		f.add_order(&"soda", client)
	f.state.config.group_chance = 0.0
	f.game.end_turn()
	assert_eq(f.state.offers.size(), 1)


func test_grouped_order_goes_to_a_near_client() -> void:
	f.state.config.group_chance = 1.0
	f.state.config.group_nearest_clients = 1
	# Nearest client (Manhattan distance), ties broken by reading order.
	var nearest := {
		GameFixture.CLIENT_1: GameFixture.CLIENT_2,
		GameFixture.CLIENT_2: GameFixture.CLIENT_1,
		GameFixture.CLIENT_3: GameFixture.CLIENT_2,
		GameFixture.CLIENT_4: GameFixture.CLIENT_1,
	}
	for offer in _draw_offers(20):
		assert_true(offer.modifiers.grouped)
		assert_eq(offer.parts.size(), 2)
		assert_eq(offer.parts[1].client, nearest[offer.parts[0].client])


func test_grouped_order_without_a_second_free_client_is_a_simple_one() -> void:
	f.state.config.group_chance = 1.0
	for client in [GameFixture.CLIENT_1, GameFixture.CLIENT_2, GameFixture.CLIENT_3]:
		f.add_order(&"soda", client)
	var offer := OfferMaker.make(f.state)
	assert_eq(offer.parts.size(), 1)
	assert_false(offer.modifiers.grouped)
	var part := offer.parts[0]
	var distance := f.state.city.distance(offer.restaurant, part.client)
	assert_eq(part.pay, OfferMaker.pay(f.state.config, f.state.effects, part.dish.cell_count(),
			distance, 100, offer.modifiers.urgent, false, false), "no grouped bonus")


func test_match_night_groups_more_orders() -> void:
	f.set_event(&"match")
	var grouped := 0
	for offer in _draw_offers(200):
		if offer.modifiers.grouped:
			grouped += 1
	assert_true(grouped > 70 and grouped < 130, "about half grouped, got %d / 200" % grouped)


func test_vip_needs_70_percent_of_acceptance() -> void:
	f.state.config.vip_chance = 1.0
	f.state.acceptance = 69
	for offer in _draw_offers(10):
		assert_false(offer.modifiers.vip)
	f.state.acceptance = 70
	for offer in _draw_offers(10):
		assert_true(offer.modifiers.vip)


func test_badge_brings_vip_whatever_the_acceptance() -> void:
	f.state.acceptance = 0
	f.equip(&"badge")
	var vip := 0
	for offer in _draw_offers(200):
		if offer.modifiers.vip:
			vip += 1
	assert_true(vip > 35 and vip < 85, "about 30 %%, got %d / 200" % vip)


func test_modifier_chances() -> void:
	f.state.config.urgent_chance = 1.0
	f.state.config.fifth_floor_chance = 0.0
	for offer in _draw_offers(5):
		assert_true(offer.modifiers.urgent)
		assert_false(offer.modifiers.fifth_floor)


func test_accepting_turns_each_dish_into_an_order() -> void:
	f.state.acceptance = 90
	var offer := f.add_offer(&"pizza", GameFixture.CLIENT_1, 6, 15)
	offer.modifiers.vip = true
	assert_eq(f.game.accept_offer(offer.id), Game.Problem.NONE)
	assert_eq(f.state.offers, [])
	assert_eq(f.state.acceptance, 95)
	assert_eq(f.state.orders.size(), 1)
	var order := f.state.orders[0]
	assert_eq([order.dish.id, order.client, order.restaurant], [&"pizza", GameFixture.CLIENT_1, GameFixture.RESTAURANT])
	assert_eq([order.deadline, order.pay], [6, 15])
	assert_true(order.modifiers.vip)
	assert_false(order.picked_up)


func test_acceptance_never_goes_over_100() -> void:
	var offer := f.add_offer(&"pizza", GameFixture.CLIENT_1)
	f.game.accept_offer(offer.id)
	assert_eq(f.state.acceptance, 100)


func test_thermos_adds_a_turn_to_accepted_orders() -> void:
	f.equip(&"thermos")
	var offer := f.add_offer(&"pizza", GameFixture.CLIENT_1, 4)
	f.game.accept_offer(offer.id)
	assert_eq(f.state.orders[0].deadline, 5)


func test_no_more_than_4_orders() -> void:
	for client in [GameFixture.CLIENT_1, GameFixture.CLIENT_2, GameFixture.CLIENT_3]:
		f.add_order(&"soda", client)
	var offer := f.add_offer(&"pizza", GameFixture.CLIENT_4)
	var second := Offer.Part.new()
	second.dish = f.content.dishes[&"soda"]
	second.client = GameFixture.CLIENT_4
	offer.parts.append(second)
	f.state.acceptance = 50
	assert_eq(f.game.accept_offer(offer.id), Game.Problem.TOO_MANY_ORDERS)
	assert_eq(f.state.orders.size(), 3, "nothing changes")
	assert_eq(f.state.acceptance, 50)
	offer.parts.pop_back()
	assert_eq(f.game.accept_offer(offer.id), Game.Problem.NONE, "the 4th order fits")


func test_refusing_costs_10_points() -> void:
	var offer := f.add_offer(&"pizza", GameFixture.CLIENT_1)
	assert_eq(f.game.refuse_offer(offer.id), Game.Problem.NONE)
	assert_eq(f.state.acceptance, 90)
	assert_eq(f.state.offers, [])
	assert_eq(f.state.orders, [])
	f.state.acceptance = 5
	f.game.refuse_offer(f.add_offer(&"pizza", GameFixture.CLIENT_1).id)
	assert_eq(f.state.acceptance, 0, "never below 0")


func test_unknown_offer() -> void:
	assert_eq(f.game.accept_offer(42), Game.Problem.NO_SUCH_OFFER)
	assert_eq(f.game.refuse_offer(42), Game.Problem.NO_SUCH_OFFER)
