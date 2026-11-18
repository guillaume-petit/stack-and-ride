extends TestCase
## Number of offers, deadline and pay of a dish (design doc §5.1, §5.3).

var content: GameContent
var config: GameConfig
var calm: EffectData


func before_each() -> void:
	content = GameContent.load_from()
	config = content.config
	calm = EffectData.new()


func _event(id: StringName) -> EffectData:
	return content.events[id].effects


func test_offers_per_turn() -> void:
	assert_eq(OfferMaker.offers_per_turn(config, calm, 1), 2)
	assert_eq(OfferMaker.offers_per_turn(config, calm, 2), 2)
	assert_eq(OfferMaker.offers_per_turn(config, calm, 3), 3)
	assert_eq(OfferMaker.offers_per_turn(config, calm, 6), 3)
	assert_eq(OfferMaker.offers_per_turn(config, _event(&"rain"), 2), 3, "+1 on rainy nights")
	assert_eq(OfferMaker.offers_per_turn(config, _event(&"match"), 4), 4, "+1 on match nights")


func test_deadline_grows_every_3_steps() -> void:
	assert_eq(OfferMaker.deadline(config, calm, 0, false, false), 3)
	assert_eq(OfferMaker.deadline(config, calm, 1, false, false), 4)
	assert_eq(OfferMaker.deadline(config, calm, 3, false, false), 4)
	assert_eq(OfferMaker.deadline(config, calm, 4, false, false), 5)
	assert_eq(OfferMaker.deadline(config, calm, 9, false, false), 6)


func test_urgent_deadline_is_shorter_but_at_least_2() -> void:
	assert_eq(OfferMaker.deadline(config, calm, 9, true, false), 4)
	assert_eq(OfferMaker.deadline(config, calm, 0, true, false), 2, "3 - 2 = 1, raised to 2")


func test_strike_adds_2_turns() -> void:
	assert_eq(OfferMaker.deadline(config, _event(&"strike"), 4, false, false), 7)
	assert_eq(OfferMaker.deadline(config, _event(&"strike"), 0, true, false), 4, "after the urgent minimum")


func test_heatwave_shortens_cold_dishes_only() -> void:
	var heat := _event(&"heat")
	assert_eq(OfferMaker.deadline(config, heat, 4, false, true), 4)
	assert_eq(OfferMaker.deadline(config, heat, 4, false, false), 5)
	assert_eq(OfferMaker.deadline(config, heat, 0, true, true), 2, "never below 2")


func test_pay_from_cells_and_distance() -> void:
	# Pizza (4 cells), 3 steps: 4 × 3 + 2 + ceil(3 / 2) = 16.
	assert_eq(OfferMaker.pay(config, calm, 4, 3, 100, false, false, false), 16)
	assert_eq(OfferMaker.pay(config, calm, 1, 0, 100, false, false, false), 5)


func test_acceptance_lowers_the_pay() -> void:
	assert_eq(OfferMaker.acceptance_multiplier(config, 100), 1.0)
	assert_eq(OfferMaker.acceptance_multiplier(config, 0), 0.6)
	# 16 × 0.8 = 12.8, rounded to 13.
	assert_eq(OfferMaker.pay(config, calm, 4, 3, 50, false, false, false), 13)


func test_pay_multipliers() -> void:
	assert_eq(OfferMaker.pay(config, calm, 4, 3, 100, true, false, false), 32, "urgent × 2")
	assert_eq(OfferMaker.pay(config, calm, 4, 3, 100, false, true, false), 21, "grouped: 16 × 1.3 = 20.8")
	assert_eq(OfferMaker.pay(config, _event(&"rain"), 4, 3, 100, false, false, false), 21, "rain × 1.3")
	assert_eq(OfferMaker.pay(config, _event(&"heat"), 2, 4, 100, false, false, true), 15, "heat, cold: 10 × 1.5")
	assert_eq(OfferMaker.pay(config, _event(&"heat"), 2, 4, 100, false, false, false), 10, "heat, hot dish")
	assert_eq(OfferMaker.pay(config, calm, 4, 3, 100, true, true, false), 42, "16 × 2 × 1.3 = 41.6")
