extends TestCase
## Result of a delivery: pay, tip, bonus and rating (design doc §7.3).

var content: GameContent
var config: GameConfig
var neutral: EffectData


func before_each() -> void:
	content = GameContent.load_from()
	config = content.config
	neutral = EffectData.new()


func _order(deadline: int, pay: int, vip: bool = false) -> Order:
	var order := Order.new()
	order.id = 7
	order.deadline = deadline
	order.pay = pay
	order.modifiers = OrderModifiers.new()
	order.modifiers.vip = vip
	return order


func _profile(id: StringName) -> EffectData:
	return content.profiles[id].effects


func test_perfect_delivery_pays_a_tip_per_turn_left() -> void:
	var result := Delivery.evaluate(_order(3, 12), false, 0, config, neutral)
	assert_eq(result.outcome, Delivery.Outcome.PERFECT)
	assert_eq(result.order_id, 7)
	assert_eq([result.pay, result.tip, result.bonus, result.total()], [12, 3, 0, 15])
	assert_eq(result.rating_tenths, 1)


func test_deadline_zero_is_still_on_time() -> void:
	var result := Delivery.evaluate(_order(0, 12), false, 0, config, neutral)
	assert_eq(result.outcome, Delivery.Outcome.PERFECT)
	assert_eq(result.tip, 0)


func test_vip_doubles_the_tip_and_the_rating() -> void:
	var result := Delivery.evaluate(_order(3, 12, true), false, 0, config, neutral)
	assert_eq([result.tip, result.rating_tenths], [6, 2])


func test_late_delivery_pays_half_rounded_up() -> void:
	var result := Delivery.evaluate(_order(-1, 11), false, 0, config, neutral)
	assert_eq(result.outcome, Delivery.Outcome.LATE)
	assert_eq([result.pay, result.tip, result.bonus], [6, 0, 0])
	assert_eq(result.rating_tenths, -3)
	assert_eq(Delivery.evaluate(_order(-1, 11, true), false, 0, config, neutral).rating_tenths, -5)


func test_late_comes_before_damaged() -> void:
	var result := Delivery.evaluate(_order(-2, 10), true, 0, config, neutral)
	assert_eq(result.outcome, Delivery.Outcome.LATE)


func test_damaged_delivery_pays_without_tip() -> void:
	var result := Delivery.evaluate(_order(3, 12), true, 0, config, neutral)
	assert_eq(result.outcome, Delivery.Outcome.DAMAGED)
	assert_eq([result.pay, result.tip, result.rating_tenths], [12, 0, config.damaged_rating_tenths])
	assert_eq(Delivery.evaluate(_order(3, 12, true), true, 0, config, neutral).rating_tenths, -5)


func test_darling_doubles_tips_and_suffers_more() -> void:
	var darling := _profile(&"darling")
	assert_eq(Delivery.evaluate(_order(3, 12, true), false, 0, config, darling).tip, 12, "3 × 2 (VIP) × 2")
	assert_eq(Delivery.evaluate(_order(3, 12), false, 0, config, darling).rating_tenths, 1)
	assert_eq(Delivery.evaluate(_order(-1, 12), false, 0, config, darling).rating_tenths, -4)
	assert_eq(Delivery.evaluate(_order(2, 12, true), true, 0, config, darling).rating_tenths, -6)


func test_bonus_counter() -> void:
	var bonus: EffectData = content.equipment[&"bonus"].effects
	assert_eq(Delivery.evaluate(_order(1, 10), false, 0, config, bonus).bonus, 2)
	assert_eq(Delivery.evaluate(_order(1, 10), true, 0, config, bonus).bonus, 0, "perfect only")


func test_combo_rewards_perfect_deliveries_of_the_same_turn() -> void:
	var combo := _profile(&"combo")
	assert_eq(Delivery.evaluate(_order(1, 10), false, 0, config, combo).bonus, 0)
	assert_eq(Delivery.evaluate(_order(1, 10), false, 2, config, combo).bonus, 6)
	var with_bonus := EffectData.combine([combo, content.equipment[&"bonus"].effects] as Array[EffectData])
	assert_eq(Delivery.evaluate(_order(1, 10), false, 1, config, with_bonus).bonus, 5)
