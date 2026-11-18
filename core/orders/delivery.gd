class_name Delivery
extends RefCounted
## The result of one delivery: what it pays and what it does to the rating (design doc §7.3).
##
## evaluate() has no side effect: Game applies the result to the wallet and the rating.

## The cases, checked in this order.
enum Outcome { LATE, DAMAGED, PERFECT }

var order_id: int
var outcome: Outcome
## Pay of the order (halved when late).
var pay: int = 0
var tip: int = 0
## Compteur de primes and Roi du groupé.
var bonus: int = 0
## Rating change, in tenths of a star.
var rating_tenths: int = 0


func total() -> int:
	return pay + tip + bonus


## damaged: the dish was damaged on the way. perfect_this_turn: perfect deliveries already
## made this turn (Roi du groupé).
static func evaluate(order: Order, damaged: bool, perfect_this_turn: int, config: GameConfig,
		effects: EffectData) -> Delivery:
	var result := Delivery.new()
	result.order_id = order.id
	var vip := order.modifiers.vip
	if order.is_late():
		result.outcome = Outcome.LATE
		result.pay = ceili(order.pay / float(config.late_pay_divisor))
		result.rating_tenths = (config.late_vip_rating_tenths if vip else config.late_rating_tenths) \
				- effects.problem_extra_cost_tenths
	elif damaged:
		result.outcome = Outcome.DAMAGED
		result.pay = order.pay
		result.rating_tenths = (config.damaged_vip_rating_tenths if vip else config.damaged_rating_tenths) \
				- effects.problem_extra_cost_tenths
	else:
		result.outcome = Outcome.PERFECT
		result.pay = order.pay
		result.tip = order.deadline * config.tip_per_turn_left * effects.tip_multiplier \
				* (config.vip_tip_multiplier if vip else 1)
		result.bonus = effects.perfect_bonus + effects.streak_bonus * perfect_this_turn
		result.rating_tenths = config.perfect_vip_rating_tenths if vip else config.perfect_rating_tenths
	return result
