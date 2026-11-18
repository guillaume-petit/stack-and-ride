class_name GameState
extends RefCounted
## Everything that describes a run in progress. The UI reads it; only core rules change it
## (through the actions of Game).

## Where the run is.
enum Phase {
	## Before the night 1: the player picks a profile (§11).
	CHOOSE_PROFILE,
	## During a night.
	PLAYING,
	## End of a night: the player picks a free reward (§9).
	CHOOSING_REWARD,
	## Between two nights (§10).
	SHOPPING,
	WON,
	LOST,
}

enum LossReason { NONE, RATING, RENT }

var content: GameContent
var config: GameConfig
## Single source of randomness for the whole run.
var rng: GameRng

var phase: Phase = Phase.CHOOSE_PROFILE
var loss_reason: LossReason = LossReason.NONE

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
## Permanent deck (card ids). The piles of the night are built from it.
var deck: Array[StringName] = []
## Draw pile, hand and discard pile of the night.
var piles := CardPiles.new()
## Profile id, or &"" before the player picks one.
var profile: StringName = &""
## Event of the current night; night 1 is always calm.
var event: StringName = &"calm"
## Equipment ids owned.
var equipment: Array[StringName] = []
## Every active effect (profile, equipment, event) combined; see refresh_effects().
var effects: EffectData = EffectData.new()

var city: City
## Crossroads where the courier stands.
var courier_position: Vector2i

## Offers shown by the app this turn, and accepted orders not delivered yet.
var offers: Array[Offer] = []
var orders: Array[Order] = []
var next_offer_id: int = 1
var next_order_id: int = 1

## Steps left this turn, given by the cards.
var steps: int = 0
## Non-free cards played this turn (§4).
var paid_cards_played: int = 0
## Road works can be crossed until the end of the turn (Contresens).
var crossing_works: bool = false
## Perfect deliveries made this turn (Roi du groupé).
var perfect_deliveries_this_turn: int = 0

## Event of the next night, drawn at the end of the night and shown in the shop (§12).
var next_event: StringName = &""
## Free rewards to choose from at the end of the night (§9).
var reward_choices: Array[Reward] = []
## Shop between two nights, null outside of it (§10).
var shop: Shop = null
## One summary per night played, the last one for the night that just ended.
var night_summaries: Array[NightSummary] = []

## Money earned during the current night, and since the start of the run.
var night_earnings: int = 0
var total_earnings: int = 0

## What happened, oldest first.
var history: Array[GameEvent] = []


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
	state.refresh_effects()
	return state


## Rating in stars, for display (4.5).
func rating() -> float:
	return rating_tenths / 10.0


func rent_tonight() -> int:
	return config.rent_for_night(night)


## Rent of the next night, shown in the shop (§10); 0 after the last night.
func rent_tomorrow() -> int:
	return config.rent_for_night(night + 1) if night < config.nights else 0


## Number of non-free cards that can be played each turn (§4, Batterie longue durée).
func max_paid_cards() -> int:
	return config.max_paid_cards_per_turn + effects.extra_paid_cards


func find_offer(id: int) -> Offer:
	for offer in offers:
		if offer.id == id:
			return offer
	return null


func find_order(id: int) -> Order:
	for order in orders:
		if order.id == id:
			return order
	return null


## Combines the effects of the profile, the equipment and the event of the night, and
## gives the bag the ones that change its rules. Call it whenever one of them changes.
func refresh_effects() -> void:
	var sources: Array[EffectData] = []
	if content.profiles.has(profile):
		sources.append(content.profiles[profile].effects)
	for id in equipment:
		sources.append(content.equipment[id].effects)
	if content.events.has(event):
		sources.append(content.events[event].effects)
	effects = EffectData.combine(sources)
	bag.set_equipment(effects.hot_and_cold_may_touch, effects.only_fragile_shaken, effects.cup_holder)
