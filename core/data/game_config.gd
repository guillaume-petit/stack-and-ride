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
@export var city_width: int = 8
@export var city_height: int = 8
@export var base_cell: Vector2i = Vector2i(3, 4)
@export var restaurant_count: int = 3
@export var client_count: int = 12
@export var works_count: int = 7
@export var paved_count: int = 6
## The city is drawn again until every cell but road works is reachable, at most this many times.
@export var city_generation_attempts: int = 200
## Same, when the "works" event moves the road works.
@export var works_relocation_attempts: int = 100


func rent_for_night(night: int) -> int:
	return rent_per_night[clampi(night, 1, rent_per_night.size()) - 1]
