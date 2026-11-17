class_name GameConfig
extends Resource
## Every tunable number of the game, in one place (design doc §2, §3, §9).
##
## The values live in data/config/game_config.tres: change them there, not in the code.
## New numbers are added here as the rules are ported (bag, offers, shop...).

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
