extends TestCase
## Rewards: free choice at the end of a night and what each one does (design doc §8.5, §9).

var f: GameFixture


func before_each() -> void:
	f = GameFixture.start()


func _upgrade(id: StringName) -> Reward:
	return Reward.new(Reward.Kind.UPGRADE, id)


func test_free_pool_has_the_sold_cards_and_the_upgrades() -> void:
	var cards := 0
	var upgrades: Array[StringName] = []
	for reward in Reward.free_pool(f.content):
		if reward.kind == Reward.Kind.CARD:
			cards += 1
			assert_true(f.content.cards[reward.id].shop_price > 0, String(reward.id))
		else:
			upgrades.append(reward.id)
	assert_eq(cards, 8)
	assert_eq(upgrades, [&"resto", &"tall", &"trim", &"wide"])


func test_card_reward_goes_to_the_deck() -> void:
	Reward.new(Reward.Kind.CARD, &"scooter").apply(f.state)
	assert_eq(f.state.deck.count(&"scooter"), 1)


func test_wider_bag_up_to_6_columns() -> void:
	var wide := _upgrade(&"wide")
	assert_true(wide.is_available(f.state))
	wide.apply(f.state)
	assert_eq([f.state.bag.columns, f.state.bag.rows], [5, 3])
	wide.apply(f.state)
	assert_false(wide.is_available(f.state), "6 columns")


func test_taller_bag_up_to_5_rows() -> void:
	var tall := _upgrade(&"tall")
	tall.apply(f.state)
	assert_eq(f.state.bag.rows, 4)
	tall.apply(f.state)
	assert_false(tall.is_available(f.state), "5 rows")


func test_trim_removes_one_pedal_card() -> void:
	var trim := _upgrade(&"trim")
	trim.apply(f.state)
	assert_eq(f.state.deck.count(&"ped2"), 2)
	assert_eq(f.state.deck.size(), 9)
	trim.apply(f.state)
	trim.apply(f.state)
	assert_false(trim.is_available(f.state), "no Pédaler left")


func test_new_partner_opens_a_missing_restaurant_type() -> void:
	var resto := _upgrade(&"resto")
	assert_eq(Reward.missing_restaurant_kinds(f.state), [&"burger", &"glacier", &"sushi", &"tacos"])
	resto.apply(f.state)
	var restaurants := f.state.city.crossroads_with(City.Place.RESTAURANT)
	assert_eq(restaurants.size(), 2)
	assert_eq(Reward.missing_restaurant_kinds(f.state).size(), 3)
	for kind in [&"burger", &"glacier", &"sushi", &"tacos"]:
		f.content.restaurants.erase(kind)
	assert_false(resto.is_available(f.state), "every type is in the city")


func test_equipment_reward_applies_its_effects() -> void:
	var separator := Reward.new(Reward.Kind.EQUIPMENT, &"separator")
	assert_true(separator.is_available(f.state))
	separator.apply(f.state)
	assert_eq(f.state.equipment, [&"separator"])
	assert_true(f.state.bag.hot_and_cold_may_touch)
	assert_false(separator.is_available(f.state), "once per run")


func test_choosing_a_reward_opens_the_shop() -> void:
	f.finish_night()
	f.state.reward_choices = [Reward.new(Reward.Kind.CARD, &"kebab")] as Array[Reward]
	assert_eq(f.game.choose_reward(1), Game.Problem.NO_SUCH_REWARD)
	assert_eq(f.game.choose_reward(0), Game.Problem.NONE)
	assert_eq(f.state.deck.count(&"kebab"), 1)
	assert_eq(f.state.reward_choices, [])
	assert_eq(f.state.phase, GameState.Phase.SHOPPING)
	assert_true(f.state.shop != null)
	assert_eq(f.game.choose_reward(0), Game.Problem.WRONG_PHASE)
