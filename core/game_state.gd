class_name GameState
extends RefCounted
## Everything that describes a run in progress. The UI reads it; only core rules change it.
##
## It holds the starting values (design doc §2), the city and the bag. The orders, offers
## and card piles are added with the rules that use them.

var content: GameContent
var config: GameConfig
## Single source of randomness for the whole run.
var rng: GameRng

## Current night (1 to config.nights) and turn (1 to config.turns_per_night).
var night: int = 1
var turn: int = 1
## Rating in tenths of a star (45 = 4.5 stars).
var rating_tenths: int
## Acceptance rate, in percent.
var acceptance: int
## Money in the wallet, in euros.
var wallet: int
## The delivery bag; its size grows with the rewards (§8.5).
var bag: Bag
## Permanent deck (card ids). The draw pile, hand and discard pile are built from it each night.
var deck: Array[StringName] = []
## Profile id, or &"" before the player picks one.
var profile: StringName = &""
## Event of the current night; night 1 is always calm.
var event: StringName = &"calm"
## Equipment ids owned.
var equipment: Array[StringName] = []

var city: City
## Crossroads where the courier stands.
var courier_position: Vector2i


## Starts a new run: the city is drawn from the seed and every value is reset.
## Returns null, with an error, if no valid city can be drawn (see City.generate()).
static func new_run(p_content: GameContent, seed: int) -> GameState:
	var state := GameState.new()
	state.content = p_content
	state.config = p_content.config
	state.rng = GameRng.new(seed)
	state.rating_tenths = state.config.starting_rating_tenths
	state.acceptance = state.config.starting_acceptance
	state.wallet = state.config.starting_wallet
	state.bag = Bag.new(state.config.bag_columns, state.config.bag_rows)
	state.deck = state.config.starting_deck.duplicate()
	state.city = City.generate(state.config, p_content.restaurant_ids(), state.rng)
	if state.city == null:
		push_error("GameState.new_run: no valid city for seed %d" % seed)
		return null
	state.courier_position = state.city.base
	return state


## Rating in stars, for display (4.5).
func rating() -> float:
	return rating_tenths / 10.0


func rent_tonight() -> int:
	return config.rent_for_night(night)
