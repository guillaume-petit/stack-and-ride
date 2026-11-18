class_name EffectData
extends Resource
## What a piece of equipment, a profile or an event changes in the rules (design doc §8.4, §11, §12).
##
## Every field is neutral by default, so a .tres file only lists what it changes. The rules
## never look at equipment, profile or event ids: they read the combination of every active
## effect (see combine() and GameState.effects).

@export_group("Cards")
## Added to the steps of every card that gives steps (Vélo électrique +1, pluie −1).
@export var card_steps: int = 0
## Extra non-free cards per turn (Batterie longue durée).
@export var extra_paid_cards: int = 0
## Cards never shake the bag (Le sprinteur).
@export var cards_never_shake: bool = false
## From this many dishes in the bag, cards give heavy_bag_steps more steps; 0 = never (La mule).
@export var heavy_bag_dishes: int = 0
@export var heavy_bag_steps: int = 0
## Cards cost no rating (Gilet fluo and the Contresens).
@export var no_card_rating_cost: bool = false

@export_group("Bag")
## Hot and cold dishes may touch (Séparateur isotherme).
@export var hot_and_cold_may_touch: bool = false
## Shakes only damage fragile dishes (Sangles).
@export var only_fragile_shaken: bool = false
## Sodas go in a cup holder (Porte-gobelet).
@export var cup_holder: bool = false
## Paved streets no longer shake the bag (Fourche suspendue).
@export var paved_streets_dont_shake: bool = false

@export_group("Offers")
## Extra offers each turn (pluie, match).
@export var extra_offers: int = 0
## Chance of a grouped order; negative keeps the config value (match).
@export var group_chance: float = -1.0
## Chance of a VIP client; negative keeps the config value (Badge Superlivreur).
@export var vip_chance: float = -1.0
## VIP clients come whatever the acceptance rate (Badge Superlivreur).
@export var vip_ignores_acceptance: bool = false
## Turns added to the deadline of every offer (grève).
@export var offer_deadline: int = 0
## Turns added to the deadline of every accepted order (Sac isotherme pro).
@export var accept_deadline: int = 0
## Pay multiplier of every offer (pluie).
@export var pay_multiplier: float = 1.0
## Pay multiplier of cold dishes (canicule).
@export var cold_pay_multiplier: float = 1.0
## Turns added to the deadline of cold dishes, never below the minimum deadline (canicule).
@export var cold_deadline: int = 0

@export_group("Deliveries")
## Tips are multiplied by this (Le chouchou).
@export var tip_multiplier: int = 1
## Each problem (late, damaged, cancelled) costs this many more tenths of a star (Le chouchou).
@export var problem_extra_cost_tenths: int = 0
## Euros added to each perfect delivery (Compteur de primes).
@export var perfect_bonus: int = 0
## Euros added to a perfect delivery for each perfect delivery already made this turn (Le roi du groupé).
@export var streak_bonus: int = 0

@export_group("Night")
## The road works move at the start of the night (Nuit de travaux).
@export var relocates_works: bool = false


## All the effects together: numbers are added, multipliers multiplied, flags combined with
## "or", chances and thresholds keep the highest value. Null entries are skipped.
static func combine(sources: Array[EffectData]) -> EffectData:
	var out := EffectData.new()
	for e in sources:
		if e == null:
			continue
		out.card_steps += e.card_steps
		out.extra_paid_cards += e.extra_paid_cards
		out.cards_never_shake = out.cards_never_shake or e.cards_never_shake
		out.heavy_bag_dishes = maxi(out.heavy_bag_dishes, e.heavy_bag_dishes)
		out.heavy_bag_steps += e.heavy_bag_steps
		out.no_card_rating_cost = out.no_card_rating_cost or e.no_card_rating_cost
		out.hot_and_cold_may_touch = out.hot_and_cold_may_touch or e.hot_and_cold_may_touch
		out.only_fragile_shaken = out.only_fragile_shaken or e.only_fragile_shaken
		out.cup_holder = out.cup_holder or e.cup_holder
		out.paved_streets_dont_shake = out.paved_streets_dont_shake or e.paved_streets_dont_shake
		out.extra_offers += e.extra_offers
		out.group_chance = maxf(out.group_chance, e.group_chance)
		out.vip_chance = maxf(out.vip_chance, e.vip_chance)
		out.vip_ignores_acceptance = out.vip_ignores_acceptance or e.vip_ignores_acceptance
		out.offer_deadline += e.offer_deadline
		out.accept_deadline += e.accept_deadline
		out.pay_multiplier *= e.pay_multiplier
		out.cold_pay_multiplier *= e.cold_pay_multiplier
		out.cold_deadline += e.cold_deadline
		out.tip_multiplier *= e.tip_multiplier
		out.problem_extra_cost_tenths += e.problem_extra_cost_tenths
		out.perfect_bonus += e.perfect_bonus
		out.streak_bonus += e.streak_bonus
		out.relocates_works = out.relocates_works or e.relocates_works
	return out
