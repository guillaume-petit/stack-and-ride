class_name GameConfig
extends Resource
## Every tunable number of the game, in one place (design doc §2 to §10).
##
## The values live in data/config/game_config.tres: change them there, not in the code.

@export_group("Run")
@export var nights: int = 6
@export var turns_per_night: int = 10
## Rent paid at the end of each night, one entry per night.
@export var rent_per_night: Array[int] = [25, 35, 48, 62, 78, 95]

@export_group("Starting values")
## Ratings are stored in tenths of a star (50 = 5.0) to avoid float rounding issues.
@export var starting_rating_tenths: int = 50
@export var max_rating_tenths: int = 50
## Below this rating the run is lost.
@export var min_rating_tenths: int = 40
@export var starting_acceptance: int = 100
@export var max_acceptance: int = 100
@export var starting_wallet: int = 0
@export var bag_columns: int = 4
@export var bag_rows: int = 3
@export var starting_deck: Array[StringName] = []
@export var hand_size: int = 4
@export var max_active_orders: int = 4
@export var max_paid_cards_per_turn: int = 2

## Steps added by a card that gives steps never bring it below this.
@export var min_card_steps: int = 1
## Card put in the discard pile by cards that tire the courier (Sprint).
@export var fatigue_card: StringName = &"fatigue"

@export_group("Offers")
## Offers in the app at the start of each turn, then offers_per_turn_late from late_offers_night.
@export var offers_per_turn: int = 2
@export var offers_per_turn_late: int = 3
@export var late_offers_night: int = 3
## Attempts to draw the missing offers each turn (an offer fails when no client is free).
@export var offer_attempts: int = 6
@export var group_chance: float = 0.22
## Dishes (and clients) of a grouped order.
@export var group_size: int = 2
## The next client of a grouped order is drawn among this many free clients nearest to the first.
@export var group_nearest_clients: int = 3
@export var urgent_chance: float = 0.22
@export var fifth_floor_chance: float = 0.2
@export var vip_chance: float = 0.18
## VIP clients only come from this acceptance rate.
@export var vip_min_acceptance: int = 70
## Deadline = ceil(distance / deadline_steps_per_turn) + deadline_base.
@export var deadline_steps_per_turn: int = 3
@export var deadline_base: int = 3
@export var urgent_deadline: int = -2
## Urgent orders and the heatwave never bring a deadline below this.
@export var min_deadline: int = 2
## Pay = cells × pay_per_cell + pay_base + ceil(distance / pay_steps_per_euro), then multiplied.
@export var pay_per_cell: int = 3
@export var pay_base: int = 2
@export var pay_steps_per_euro: int = 2
## Acceptance multiplier = acceptance_pay_floor + (1 − floor) × acceptance / 100.
@export var acceptance_pay_floor: float = 0.6
@export var urgent_pay_multiplier: float = 2.0
@export var group_pay_multiplier: float = 1.3
@export var accept_acceptance: int = 5
@export var refuse_acceptance: int = -10
## Per offer still in the app at the end of the turn.
@export var ignore_acceptance: int = -5

@export_group("Deliveries")
## Steps to climb to a 5th floor client.
@export var fifth_floor_steps: int = 1
## A late delivery pays its pay divided by this, rounded up.
@export var late_pay_divisor: int = 2
## Rating changes in tenths of a star.
@export var late_rating_tenths: int = -3
@export var late_vip_rating_tenths: int = -5
@export var damaged_rating_tenths: int = -2
@export var damaged_vip_rating_tenths: int = -5
@export var perfect_rating_tenths: int = 1
@export var perfect_vip_rating_tenths: int = 2
@export var vip_tip_multiplier: int = 2
## Tip of a perfect delivery for each turn of deadline left.
@export var tip_per_turn_left: int = 1
## The client cancels when the deadline goes below this at the end of a turn.
@export var cancel_below_deadline: int = -2
@export var cancel_rating_tenths: int = -5

@export_group("End of night")
## Per accepted order not delivered.
@export var undelivered_rating_tenths: int = -2
## Free rewards to choose from.
@export var reward_choices: int = 3
@export var max_bag_columns: int = 6
@export var max_bag_rows: int = 5

@export_group("Shop")
@export var shop_equipment: int = 2
@export var shop_bag_upgrades: int = 1
@export var shop_cards: int = 3

@export_group("City")
## Number of crossroads across and down (the blocks lie between them).
@export var city_columns: int = 7
@export var city_rows: int = 6
## Crossroads of the base.
@export var base_cell: Vector2i = Vector2i(3, 3)
@export var restaurant_count: int = 3
@export var client_count: int = 12

## Street segments closed by road works.
@export var works_count: int = 7
## Paved street segments.
@export var paved_count: int = 6
## The city is drawn again until every crossroads is reachable, at most this many times.
@export var city_generation_attempts: int = 200
## Same, when the "works" event moves the road works.
@export var works_relocation_attempts: int = 100


## Rent of a night (1 to nights). A night out of range is a bug in the caller: it is
## reported and the closest night is used.
func rent_for_night(night: int) -> int:
	if night < 1 or night > rent_per_night.size():
		push_error("rent_for_night: no night %d" % night)
	return rent_per_night[clampi(night, 1, rent_per_night.size()) - 1]


## Problems that make the city impossible to draw, one line each (empty when it is fine).
## Checked by GameContent.validate() and before drawing a city, in every build.
func city_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	if city_columns < 1 or city_rows < 1:
		problems.append("the city needs at least one crossroads")
		return problems
	var crossroads := city_columns * city_rows
	var streets := (city_columns - 1) * city_rows + city_columns * (city_rows - 1)
	if base_cell.x < 0 or base_cell.y < 0 or base_cell.x >= city_columns or base_cell.y >= city_rows:
		problems.append("base_cell %s is outside the city" % base_cell)
	if 1 + restaurant_count + client_count > crossroads:
		problems.append("not enough crossroads (%d) for the base, %d restaurants and %d clients"
				% [crossroads, restaurant_count, client_count])
	if works_count + paved_count > streets:
		problems.append("not enough streets (%d) for %d works and %d paved streets"
				% [streets, works_count, paved_count])
	return problems
