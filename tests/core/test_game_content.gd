extends TestCase
## The content files under data/ (design doc §2, §8, §11, §12).

var content: GameContent


func before_each() -> void:
	content = GameContent.load_from()


func test_content_loads_without_problems() -> void:
	assert_eq(content.validate(), PackedStringArray())


func test_content_counts_match_the_design() -> void:
	assert_eq(content.dishes.size(), 8, "dishes")
	assert_eq(content.restaurants.size(), 5, "restaurants")
	assert_eq(content.cards.size(), 11, "cards")
	assert_eq(content.equipment.size(), 10, "equipment")
	assert_eq(content.upgrades.size(), 4, "upgrades")
	assert_eq(content.profiles.size(), 4, "profiles")
	assert_eq(content.events.size(), 6, "events")


func test_dish_shapes_and_properties() -> void:
	var pizza: DishData = content.dishes[&"pizza"]
	assert_eq(pizza.cell_count(), 4)
	assert_eq(pizza.temperature, DishData.Temperature.HOT)
	assert_false(pizza.fragile)
	var sushi: DishData = content.dishes[&"sushi"]
	assert_eq(sushi.cells, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)])
	assert_eq(sushi.temperature, DishData.Temperature.COLD)
	assert_true(sushi.fragile)
	var soda: DishData = content.dishes[&"soda"]
	assert_eq(soda.temperature, DishData.Temperature.NEUTRAL)
	assert_true(soda.fragile)
	assert_eq(content.dishes[&"family"].cell_count(), 6)


func test_restaurant_dish_lists_keep_their_weights() -> void:
	assert_eq(content.restaurants[&"burger"].dishes, [&"burger", &"burger", &"soda", &"family"])
	assert_eq(content.restaurants[&"glacier"].dishes, [&"glace", &"glace", &"poke"])


func test_restaurant_ids_are_sorted() -> void:
	assert_eq(content.restaurant_ids(), [&"burger", &"glacier", &"pizza", &"sushi", &"tacos"])


func test_starting_values() -> void:
	var config := content.config
	assert_eq(config.starting_rating_tenths, 50)
	assert_eq(config.starting_acceptance, 100)
	assert_eq(config.starting_wallet, 0)
	assert_eq([config.bag_columns, config.bag_rows], [4, 3])
	assert_eq([config.nights, config.turns_per_night], [6, 10])
	assert_eq(config.max_active_orders, 4)
	assert_eq(config.rent_per_night, [45, 60, 80, 100, 120, 140])


func test_starting_deck() -> void:
	var counts := {}
	for card_id in content.config.starting_deck:
		counts[card_id] = counts.get(card_id, 0) + 1
	assert_eq(counts, {&"ped2": 3, &"ped3": 2, &"orange": 2, &"sprint": 1, &"call": 1, &"coffee": 1})


func test_card_properties() -> void:
	var sprint: CardData = content.cards[&"sprint"]
	assert_eq(sprint.steps, 5)
	assert_true(sprint.shakes and sprint.adds_fatigue)
	assert_eq(content.cards[&"orange"].steps_bonus_if_not_first, 2)
	assert_eq(content.cards[&"wrong"].rating_cost_tenths, 1)
	assert_true(content.cards[&"wrong"].crosses_works)
	var free_cards: Array[StringName] = []
	for card: CardData in content.cards.values():
		if card.free:
			free_cards.append(card.id)
	# Array.sort() orders StringNames by internal address, not alphabetically.
	free_cards.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	assert_eq(free_cards, [&"coffee", &"strap"])


func test_shop_prices() -> void:
	assert_eq(content.cards[&"scooter"].shop_price, 12)
	assert_eq(content.cards[&"ped2"].shop_price, 0, "basic cards are not sold")
	assert_eq(content.equipment[&"battery"].shop_price, 30)
	assert_eq(content.upgrades[&"tall"].shop_price, 24)
	assert_false(content.upgrades[&"resto"].sold_in_shop(), "new partner is a free reward only")


func test_profiles() -> void:
	assert_eq(content.profiles[&"mule"].bag_columns, 5)
	assert_eq(content.profiles[&"sprinter"].bag_columns, 3)
	assert_eq(content.profiles[&"sprinter"].extra_cards, [&"sprint"])
	assert_eq(content.profiles[&"darling"].bag_columns, 0, "keeps the default bag")


func test_calm_is_the_only_event_never_drawn() -> void:
	for event: EventData in content.events.values():
		assert_eq(event.drawable, event.id != &"calm", String(event.id))


func test_every_content_has_french_texts() -> void:
	var french := load("res://i18n/fr.po") as Translation
	assert_true(french != null, "fr.po should load")
	for item in content.all_content():
		var keys := [item.name_key()]
		if item.has_description():
			keys.append(item.description_key())
		for key: String in keys:
			assert_ne(String(french.get_message(key)), "", "missing translation %s" % key)


func test_validate_reports_broken_references() -> void:
	var restaurant := RestaurantData.new()
	restaurant.id = &"broken"
	restaurant.dishes = [&"caviar"]
	content.restaurants[restaurant.id] = restaurant
	content.config = content.config.duplicate()
	content.config.starting_deck = [&"teleport"]
	var problems := content.validate()
	assert_true(problems.has("restaurant broken: unknown dish caviar"), str(problems))
	assert_true(problems.has("starting deck: unknown card teleport"), str(problems))


func test_validate_reports_an_impossible_city() -> void:
	content.config = content.config.duplicate()
	content.config.base_cell = Vector2i(-1, 2)
	assert_true(_problems_contain(content.validate(), "outside the city"))


func _problems_contain(problems: PackedStringArray, text: String) -> bool:
	for problem in problems:
		if problem.contains(text):
			return true
	return false


func test_config_script_defaults_match_the_data_file() -> void:
	var defaults := GameConfig.new()
	for property in defaults.get_property_list():
		if property["usage"] & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var name: String = property["name"]
			assert_eq(content.config.get(name), defaults.get(name), name)


func test_upgrades() -> void:
	assert_eq(content.upgrades[&"wide"].extra_columns, 1)
	assert_eq(content.upgrades[&"tall"].extra_rows, 1)
	assert_eq(content.upgrades[&"trim"].removes_card, &"ped2")
	assert_true(content.upgrades[&"resto"].opens_restaurant)
	assert_eq([content.config.max_bag_columns, content.config.max_bag_rows], [6, 5])


func test_validate_reports_unknown_cards_of_upgrades_and_fatigue() -> void:
	var upgrade := UpgradeData.new()
	upgrade.id = &"broken"
	upgrade.removes_card = &"teleport"
	content.upgrades[upgrade.id] = upgrade
	content.config = content.config.duplicate()
	content.config.fatigue_card = &"nap"
	var problems := content.validate()
	assert_true(problems.has("upgrade broken: unknown card teleport"), str(problems))
	assert_true(problems.has("fatigue card: unknown card nap"), str(problems))


func test_validate_needs_an_event_for_the_next_nights() -> void:
	for id in content.event_ids():
		if id != &"calm":
			content.events.erase(id)
	assert_true(content.validate().has("no event can be drawn for the next nights"))
