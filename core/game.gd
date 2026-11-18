class_name Game
extends RefCounted
## The rules of a run: the only way for the interface and the bot to change the state.
##
## Each action checks that it is allowed and returns Problem.NONE, or the reason why it is
## refused; a refused action changes nothing. Everything that happens is also added to
## state.history (see GameEvent).

## Why an action is refused.
enum Problem {
	NONE,
	## The action does not exist in this phase of the run.
	WRONG_PHASE,
	UNKNOWN_PROFILE,
	NO_SUCH_OFFER,
	## Accepting would go over the maximum number of orders (§5.4).
	TOO_MANY_ORDERS,
	NO_SUCH_CARD,
	## No more non-free cards this turn (§4).
	CARD_LIMIT,
	## A dish is in hand or set aside: the courier cannot move nor end the turn (§6.8).
	SORTING,
	SAME_PLACE,
	## Not enough steps, or no way to get there.
	TOO_FAR,
	NO_SUCH_ORDER,
	ALREADY_PICKED_UP,
	NOT_AT_RESTAURANT,
	# The bag refused (see Bag.Problem).
	NO_ROOM,
	ON_FRAGILE,
	HOT_COLD_TOUCH,
	SOMETHING_ON_TOP,
	HAND_BUSY,
	NOTHING_HELD,
	NOT_IN_BAG,
	NOT_ASIDE,
}

var state: GameState


func _init(p_state: GameState) -> void:
	state = p_state


## Starts a new run, waiting for the profile. Returns null if no city can be drawn.
static func new_run(content: GameContent, seed: int) -> Game:
	var run_state := GameState.new_run(content, seed)
	return Game.new(run_state) if run_state != null else null


# --- Start of the run ----------------------------------------------------------------------

## Picks the profile for the whole run (§11) and starts the first night.
func choose_profile(id: StringName) -> Problem:
	if state.phase != GameState.Phase.CHOOSE_PROFILE:
		return Problem.WRONG_PHASE
	if not state.content.profiles.has(id):
		return Problem.UNKNOWN_PROFILE
	var profile: ProfileData = state.content.profiles[id]
	state.profile = id
	var columns := profile.bag_columns if profile.bag_columns > 0 else state.config.bag_columns
	state.bag = Bag.new(columns, state.config.bag_rows)
	state.deck.append_array(profile.extra_cards)
	_start_night(1)
	return Problem.NONE


# --- Offers (§5) ----------------------------------------------------------------------------

func accept_offer(id: int) -> Problem:
	if state.phase != GameState.Phase.PLAYING:
		return Problem.WRONG_PHASE
	var offer := state.find_offer(id)
	if offer == null:
		return Problem.NO_SUCH_OFFER
	if state.orders.size() + offer.parts.size() > state.config.max_active_orders:
		return Problem.TOO_MANY_ORDERS
	state.offers.erase(offer)
	_change_acceptance(state.config.accept_acceptance)
	for part in offer.parts:
		var order := Order.new()
		order.id = state.next_order_id
		state.next_order_id += 1
		order.dish = part.dish
		order.restaurant = offer.restaurant
		order.client = part.client
		order.deadline = part.deadline + state.effects.accept_deadline
		order.pay = part.pay
		order.modifiers = offer.modifiers
		state.orders.append(order)
	return Problem.NONE


func refuse_offer(id: int) -> Problem:
	if state.phase != GameState.Phase.PLAYING:
		return Problem.WRONG_PHASE
	var offer := state.find_offer(id)
	if offer == null:
		return Problem.NO_SUCH_OFFER
	state.offers.erase(offer)
	_change_acceptance(state.config.refuse_acceptance)
	return Problem.NONE


# --- Cards (§4, §8.3) -----------------------------------------------------------------------

## Steps the card would give if played now (0 for cards that give no steps).
func card_steps(card_id: StringName) -> int:
	var card: CardData = state.content.cards[card_id]
	if not card.gives_steps():
		return 0
	var steps := card.steps + state.effects.card_steps
	if state.paid_cards_played > 0:
		steps += card.steps_bonus_if_not_first
	var heavy := state.effects.heavy_bag_dishes
	if heavy > 0 and state.bag.dish_count() >= heavy:
		steps += state.effects.heavy_bag_steps
	return maxi(state.config.min_card_steps, steps)


## Why the card at this index of the hand cannot be played now, or Problem.NONE.
func card_problem(hand_index: int) -> Problem:
	if state.phase != GameState.Phase.PLAYING:
		return Problem.WRONG_PHASE
	if hand_index < 0 or hand_index >= state.piles.hand.size():
		return Problem.NO_SUCH_CARD
	var card: CardData = state.content.cards[state.piles.hand[hand_index]]
	if not card.free and state.paid_cards_played >= state.max_paid_cards():
		return Problem.CARD_LIMIT
	return Problem.NONE


func play_card(hand_index: int) -> Problem:
	var problem := card_problem(hand_index)
	if problem != Problem.NONE:
		return problem
	var card: CardData = state.content.cards[state.piles.hand[hand_index]]
	var gained := card_steps(card.id)
	state.piles.take_from_hand(hand_index)
	if not card.removed_when_played:
		state.piles.discard(card.id)
	if not card.free:
		state.paid_cards_played += 1
	state.steps += gained
	if card.crosses_works:
		state.crossing_works = true
	if card.rating_cost_tenths > 0 and not state.effects.no_card_rating_cost:
		_change_rating(-card.rating_cost_tenths)
		var cost := GameEvent.new(GameEvent.Kind.CARD_RATING_COST)
		cost.source = card.id
		cost.rating_tenths = -card.rating_cost_tenths
		_record(cost)
	if card.deadline_bonus != 0:
		for order in state.orders:
			order.deadline += card.deadline_bonus
		var extended := GameEvent.new(GameEvent.Kind.DEADLINES_EXTENDED)
		extended.value = card.deadline_bonus
		_record(extended)
	if card.draws > 0:
		state.piles.draw(card.draws, state.rng)
	if card.cancels_next_shake:
		state.bag.brace()
	if card.adds_fatigue:
		state.piles.discard(state.config.fatigue_card)
	if card.shakes and not state.effects.cards_never_shake:
		_shake(card.id)
	_deliver_here()
	return Problem.NONE


# --- Moving (§3, §6.6) ----------------------------------------------------------------------

## Shortest paths from the courier, through the road works when a Contresens was played.
func paths() -> CityPaths:
	return state.city.paths_from(state.courier_position, state.crossing_works)


## Rides to a crossroads, spending one step per street. Deliveries only happen where the
## ride ends (§7.2): to deliver on the way, stop there.
func move_to(target: Vector2i) -> Problem:
	if state.phase != GameState.Phase.PLAYING:
		return Problem.WRONG_PHASE
	if state.bag.is_sorting():
		return Problem.SORTING
	if target == state.courier_position:
		return Problem.SAME_PLACE
	var from_here := paths()
	var distance := from_here.distance_to(target)
	if distance < 0 or distance > state.steps:
		return Problem.TOO_FAR
	var previous := state.courier_position
	var shaken := false
	for crossroads in from_here.path_to(target):
		var paved := state.city.street_between(previous, crossroads) == City.Street.PAVED
		if paved and not shaken and not state.effects.paved_streets_dont_shake:
			shaken = true
			_shake(&"paved")
		previous = crossroads
	state.steps -= distance
	state.courier_position = target
	_deliver_here()
	return Problem.NONE


# --- Dishes and bag (§6, §7.1) --------------------------------------------------------------

## Takes the dish of an order at its restaurant: it goes in hand, or in the cup holder.
func take_dish(order_id: int) -> Problem:
	if state.phase != GameState.Phase.PLAYING:
		return Problem.WRONG_PHASE
	var order := state.find_order(order_id)
	if order == null:
		return Problem.NO_SUCH_ORDER
	if order.picked_up:
		return Problem.ALREADY_PICKED_UP
	if state.courier_position != order.restaurant:
		return Problem.NOT_AT_RESTAURANT
	if not state.bag.take_from_restaurant(BagItem.new(order.id, order.dish)):
		return Problem.HAND_BUSY
	order.picked_up = true
	_deliver_here()
	return Problem.NONE


## Drops the dish in hand in a column; it is delivered at once if its client is here.
func drop_held(column: int) -> Problem:
	if state.phase != GameState.Phase.PLAYING:
		return Problem.WRONG_PHASE
	var problem := _from_bag(state.bag.drop_held(column))
	if problem == Problem.NONE:
		_deliver_here()
	return problem


func rotate_held() -> Problem:
	if state.phase != GameState.Phase.PLAYING:
		return Problem.WRONG_PHASE
	if state.bag.held == null:
		return Problem.NOTHING_HELD
	state.bag.rotate_held()
	return Problem.NONE


func lift(order_id: int) -> Problem:
	if state.phase != GameState.Phase.PLAYING:
		return Problem.WRONG_PHASE
	return _from_bag(state.bag.lift(order_id))


func set_held_aside() -> Problem:
	if state.phase != GameState.Phase.PLAYING:
		return Problem.WRONG_PHASE
	if state.bag.held == null:
		return Problem.NOTHING_HELD
	state.bag.set_held_aside()
	return Problem.NONE


func take_from_aside(order_id: int) -> Problem:
	if state.phase != GameState.Phase.PLAYING:
		return Problem.WRONG_PHASE
	if state.bag.held != null:
		return Problem.HAND_BUSY
	if state.bag.location_of(order_id) != Bag.Location.ASIDE:
		return Problem.NOT_ASIDE
	state.bag.take_from_aside(order_id)
	return Problem.NONE


## Puts the dish in hand back where it came from (a dish from the restaurant goes back there).
func cancel_held() -> Problem:
	if state.phase != GameState.Phase.PLAYING:
		return Problem.WRONG_PHASE
	if state.bag.held == null:
		return Problem.NOTHING_HELD
	var back_to_restaurant := state.bag.cancel_held()
	if back_to_restaurant != null:
		state.find_order(back_to_restaurant.order_id).picked_up = false
	return Problem.NONE


# --- End of the turn (§4, §7.4) -------------------------------------------------------------

func end_turn() -> Problem:
	if state.phase != GameState.Phase.PLAYING:
		return Problem.WRONG_PHASE
	if state.bag.held != null and state.bag.held_origin != Bag.Origin.ASIDE:
		cancel_held()
	if state.bag.is_sorting():
		return Problem.SORTING

	if not state.offers.is_empty():
		_change_acceptance(state.config.ignore_acceptance * state.offers.size())
		var ignored := GameEvent.new(GameEvent.Kind.OFFERS_IGNORED)
		ignored.value = state.offers.size()
		_record(ignored)
		state.offers.clear()

	for order in state.orders.duplicate():
		order.deadline -= 1
		if order.deadline < state.config.cancel_below_deadline:
			_remove_order(order)
			var rating := state.config.cancel_rating_tenths - state.effects.problem_extra_cost_tenths
			_change_rating(rating)
			var cancelled := GameEvent.new(GameEvent.Kind.CANCELLED)
			cancelled.order_id = order.id
			cancelled.rating_tenths = rating
			_record(cancelled)

	state.turn += 1
	state.steps = 0
	state.paid_cards_played = 0
	state.crossing_works = false
	state.perfect_deliveries_this_turn = 0
	state.bag.release_brace()

	if state.rating_tenths < state.config.min_rating_tenths:
		_lose(GameState.LossReason.RATING)
	elif state.turn > state.config.turns_per_night:
		_end_night()
	else:
		_start_turn()
	return Problem.NONE


# --- Nights (§9) ----------------------------------------------------------------------------

func _start_night(night: int) -> void:
	state.phase = GameState.Phase.PLAYING
	state.night = night
	state.turn = 1
	state.courier_position = state.city.base
	state.bag.clear()
	state.orders.clear()
	state.offers.clear()
	state.steps = 0
	state.paid_cards_played = 0
	state.crossing_works = false
	state.perfect_deliveries_this_turn = 0
	state.night_earnings = 0
	state.refresh_effects()
	var started := GameEvent.new(GameEvent.Kind.NIGHT_STARTED)
	started.value = night
	_record(started)
	if state.effects.relocates_works:
		if state.city.relocate_works(state.rng, state.config.works_relocation_attempts):
			_record(GameEvent.new(GameEvent.Kind.WORKS_MOVED))
	state.piles.start_night(state.deck, state.rng)
	_start_turn()


func _start_turn() -> void:
	var wanted := OfferMaker.offers_per_turn(state.config, state.effects, state.night)
	var attempts := state.config.offer_attempts
	while state.offers.size() < wanted and attempts > 0:
		attempts -= 1
		var offer := OfferMaker.make(state)
		if offer != null:
			offer.id = state.next_offer_id
			state.next_offer_id += 1
			state.offers.append(offer)
	state.piles.fill_hand(state.config.hand_size, state.rng)


## Undelivered orders cost rating, then the rent is paid (§9). The rewards and the shop come
## with the next step of iteration 3: until then the next night starts right away.
func _end_night() -> void:
	var undelivered := state.orders.size()
	_change_rating(state.config.undelivered_rating_tenths * undelivered)
	var ended := GameEvent.new(GameEvent.Kind.NIGHT_ENDED)
	ended.value = state.night
	_record(ended)
	var rent := state.rent_tonight()
	if state.wallet < rent:
		state.wallet = 0
		_lose(GameState.LossReason.RENT)
		return
	state.wallet -= rent
	if state.rating_tenths < state.config.min_rating_tenths:
		_lose(GameState.LossReason.RATING)
	elif state.night >= state.config.nights:
		state.phase = GameState.Phase.WON
	else:
		_start_night(state.night + 1)


func _lose(reason: GameState.LossReason) -> void:
	state.phase = GameState.Phase.LOST
	state.loss_reason = reason


# --- Deliveries (§7) ------------------------------------------------------------------------

## Delivers every order whose client is here and whose dish is in the bag (or the cup
## holder). A delivery ends the ride: the steps left are lost (decision of 17/11/2026).
func _deliver_here() -> void:
	for order in state.orders.duplicate():
		if order.client != state.courier_position or not state.bag.is_ready_to_deliver(order.id):
			continue
		if order.modifiers.fifth_floor and state.steps < state.config.fifth_floor_steps:
			if not order.fifth_floor_warned:
				order.fifth_floor_warned = true
				var waiting := GameEvent.new(GameEvent.Kind.FIFTH_FLOOR_WAIT)
				waiting.order_id = order.id
				_record(waiting)
			continue
		var damaged := state.bag.find(order.id).damaged
		var delivery := Delivery.evaluate(order, damaged, state.perfect_deliveries_this_turn,
				state.config, state.effects)
		_remove_order(order)
		state.steps = 0
		state.wallet += delivery.total()
		state.night_earnings += delivery.total()
		state.total_earnings += delivery.total()
		_change_rating(delivery.rating_tenths)
		if delivery.outcome == Delivery.Outcome.PERFECT:
			state.perfect_deliveries_this_turn += 1
		var delivered := GameEvent.new(GameEvent.Kind.DELIVERED)
		delivered.order_id = order.id
		delivered.delivery = delivery
		delivered.rating_tenths = delivery.rating_tenths
		_record(delivered)


## The order leaves the run (delivered or cancelled); its dish leaves the bag and the dishes
## above fall (§6.7).
func _remove_order(order: Order) -> void:
	state.orders.erase(order)
	var crushed := state.bag.remove(order.id)
	if not crushed.is_empty():
		var event := GameEvent.new(GameEvent.Kind.CRUSHED)
		for item in crushed:
			event.order_ids.append(item.order_id)
		_record(event)


# --- Helpers --------------------------------------------------------------------------------

func _shake(source: StringName) -> void:
	var result := state.bag.shake()
	var event := GameEvent.new(GameEvent.Kind.SHAKE)
	event.source = source
	event.braced = result.braced
	for item in result.damaged:
		event.order_ids.append(item.order_id)
	_record(event)


func _change_rating(tenths: int) -> void:
	state.rating_tenths = clampi(state.rating_tenths + tenths, 0, state.config.max_rating_tenths)


func _change_acceptance(points: int) -> void:
	state.acceptance = clampi(state.acceptance + points, 0, state.config.max_acceptance)


func _record(event: GameEvent) -> void:
	state.history.append(event)


static func _from_bag(problem: Bag.Problem) -> Problem:
	match problem:
		Bag.Problem.NONE:
			return Problem.NONE
		Bag.Problem.NO_ROOM:
			return Problem.NO_ROOM
		Bag.Problem.ON_FRAGILE:
			return Problem.ON_FRAGILE
		Bag.Problem.HOT_COLD_TOUCH:
			return Problem.HOT_COLD_TOUCH
		Bag.Problem.SOMETHING_ON_TOP:
			return Problem.SOMETHING_ON_TOP
		Bag.Problem.HAND_BUSY:
			return Problem.HAND_BUSY
		Bag.Problem.NOTHING_HELD:
			return Problem.NOTHING_HELD
		Bag.Problem.NOT_IN_BAG:
			return Problem.NOT_IN_BAG
	assert(false, "unknown bag problem %d" % problem)
	return Problem.NONE
