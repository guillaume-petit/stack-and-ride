extends TestCase
## Effects of the equipment, profiles and events, stored in the data files (design doc §8.4, §11, §12).

var content: GameContent


func before_each() -> void:
	content = GameContent.load_from()


func test_no_effect_is_neutral() -> void:
	var none: Array[EffectData] = []
	var effects := EffectData.combine(none)
	assert_eq(effects.card_steps, 0)
	assert_eq(effects.pay_multiplier, 1.0)
	assert_eq(effects.tip_multiplier, 1)
	assert_eq(effects.group_chance, -1.0, "keeps the config value")
	assert_false(effects.cup_holder)


func test_effects_add_up() -> void:
	var ebike: EffectData = content.equipment[&"ebike"].effects
	var rain: EffectData = content.events[&"rain"].effects
	var both := EffectData.combine([ebike, rain] as Array[EffectData])
	assert_eq(both.card_steps, 0, "+1 and -1")
	assert_eq(both.extra_offers, 1)
	assert_eq(both.pay_multiplier, 1.3)


func test_multipliers_multiply_and_flags_combine() -> void:
	var a := EffectData.new()
	a.pay_multiplier = 1.5
	a.cup_holder = true
	var b := EffectData.new()
	b.pay_multiplier = 2.0
	b.vip_chance = 0.3
	var both := EffectData.combine([a, null, b] as Array[EffectData])
	assert_eq(both.pay_multiplier, 3.0)
	assert_true(both.cup_holder)
	assert_eq(both.vip_chance, 0.3, "the highest chance wins over 'unchanged'")


func test_every_equipment_profile_and_event_has_effects() -> void:
	for item: EquipmentData in content.equipment.values():
		assert_true(item.effects != null, String(item.id))
	for item: ProfileData in content.profiles.values():
		assert_true(item.effects != null, String(item.id))
	for item: EventData in content.events.values():
		assert_eq(item.effects != null, item.id != &"calm", String(item.id))


func test_equipment_effects_match_the_design() -> void:
	var e := content.equipment
	assert_true(e[&"separator"].effects.hot_and_cold_may_touch)
	assert_true(e[&"cupholder"].effects.cup_holder)
	assert_true(e[&"straps"].effects.only_fragile_shaken)
	assert_true(e[&"shocks"].effects.paved_streets_dont_shake)
	assert_eq(e[&"battery"].effects.extra_paid_cards, 1)
	assert_eq(e[&"ebike"].effects.card_steps, 1)
	assert_eq(e[&"thermos"].effects.accept_deadline, 1)
	assert_true(e[&"gilet"].effects.no_card_rating_cost)
	assert_eq(e[&"badge"].effects.vip_chance, 0.3)
	assert_true(e[&"badge"].effects.vip_ignores_acceptance)
	assert_eq(e[&"bonus"].effects.perfect_bonus, 2)


func test_profile_effects_match_the_design() -> void:
	var p := content.profiles
	assert_eq([p[&"mule"].effects.heavy_bag_dishes, p[&"mule"].effects.heavy_bag_steps], [4, -1])
	assert_true(p[&"sprinter"].effects.cards_never_shake)
	assert_eq(p[&"darling"].effects.tip_multiplier, 2)
	assert_eq(p[&"darling"].effects.problem_extra_cost_tenths, 1)
	assert_eq(p[&"combo"].effects.streak_bonus, 3)


func test_event_effects_match_the_design() -> void:
	var ev := content.events
	assert_eq([ev[&"rain"].effects.extra_offers, ev[&"rain"].effects.card_steps], [1, -1])
	assert_eq(ev[&"rain"].effects.pay_multiplier, 1.3)
	assert_eq(ev[&"match"].effects.extra_offers, 1)
	assert_eq(ev[&"match"].effects.group_chance, 0.5)
	assert_eq(ev[&"strike"].effects.offer_deadline, 2)
	assert_true(ev[&"works"].effects.relocates_works)
	assert_eq(ev[&"heat"].effects.cold_pay_multiplier, 1.5)
	assert_eq(ev[&"heat"].effects.cold_deadline, -1)


func test_state_combines_profile_equipment_and_event() -> void:
	var state := GameState.new_run(content, 1)
	state.profile = &"mule"
	state.equipment = [&"ebike", &"separator"] as Array[StringName]
	state.event = &"rain"
	state.refresh_effects()
	assert_eq(state.effects.card_steps, 0)
	assert_eq(state.effects.heavy_bag_dishes, 4)
	assert_true(state.bag.hot_and_cold_may_touch, "the bag gets its equipment")
	assert_false(state.bag.has_cup_holder)
