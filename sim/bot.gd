class_name Bot
extends RefCounted
## A "reasonable" player for balancing: one simple greedy strategy, not an optimal one.
##
## It only uses the actions of Game, like the interface will. Each turn it:
## 1. accepts the offers it thinks it can deliver in time and fit in the bag (and ignores
##    the others: ignoring costs less acceptance than refusing);
## 2. takes the dishes waiting at the restaurant where it stands, and places each one where it
##    sits lowest and is wedged the most;
## 3. rides to the nearest useful place (a client to deliver, a restaurant to pick up), playing
##    cards when it has no step left: free ones first, then the one that gives the most steps,
##    avoiding the cards that shake the bag while a dish is loose;
## 4. ends the turn, after playing the Fatigue cards it can get rid of.
## Between nights it picks rewards and buys by fixed priorities, keeping tomorrow's rent.

## Safety limits, so that a bug in the bot cannot loop forever.
const MAX_ACTIONS_PER_TURN := 60
const MAX_TURNS_PER_RUN := 200

## Average steps per turn used to estimate whether an order can be delivered in time, and
## the extra steps counted for each order already accepted (its stops delay the new one).
const ESTIMATED_STEPS_PER_TURN := 3
const STEPS_PER_ACCEPTED_ORDER := 2
## Part of the bag cells the bot is willing to fill with accepted orders.
const BAG_FILL_RATIO := 0.75

## Free rewards, best first. Anything else comes after, in the order of the choices.
const REWARD_PRIORITY: Array[StringName] = [
	&"wide", &"tall", &"resto", &"scooter", &"coffee", &"strap", &"trim", &"call", &"kebab", &"orange",
]
## Shop items, best first. Items not listed are never bought.
const SHOP_PRIORITY: Array[StringName] = [
	&"straps", &"battery", &"ebike", &"wide", &"tall", &"thermos", &"cupholder", &"separator",
	&"bonus", &"shocks", &"badge", &"trim", &"scooter", &"coffee", &"strap",
]

var game: Game
var state: GameState
## Orders whose dish did not fit in the bag this turn, so that the bot does not retry them.
var _skipped: Array[int] = []


func _init(p_game: Game) -> void:
	game = p_game
	state = p_game.state


## Plays a whole run with this profile. Returns the game, finished unless the bot got stuck
## (then the phase is still PLAYING, CHOOSING_REWARD or SHOPPING).
static func play_run(content: GameContent, seed: int, profile: StringName) -> Game:
	var run := Game.new_run(content, seed)
	if run == null:
		return null
	run.choose_profile(profile)
	Bot.new(run).play()
	return run


func play() -> void:
	for turn in MAX_TURNS_PER_RUN:
		match state.phase:
			GameState.Phase.PLAYING:
				_play_turn()
			GameState.Phase.CHOOSING_REWARD:
				game.choose_reward(_pick_reward())
			GameState.Phase.SHOPPING:
				_shop()
				game.start_next_night()
			_:
				return


# --- A turn ---------------------------------------------------------------------------------

func _play_turn() -> void:
	_skipped.clear()
	_accept_offers()
	_call_if_late_soon()
	for i in MAX_ACTIONS_PER_TURN:
		if not _act():
			break
	_play_fatigue()
	if game.end_turn() != Game.Problem.NONE:
		# Never happens with this bot (it sets nothing aside), but never get stuck.
		for item in state.bag.aside_items():
			game.take_from_aside(item.order_id)
			if game.drop_held(0) != Game.Problem.NONE:
				break
		game.end_turn()


## Does one useful thing. Returns false when there is nothing left to do this turn.
func _act() -> bool:
	if _take_dishes_here():
		return true
	var target := _next_target()
	if target == City.NOWHERE:
		return false
	if target != state.courier_position and state.steps > 0:
		var from_here := game.paths()
		var path := from_here.path_to(target)
		var stop := path[mini(state.steps, path.size()) - 1]
		var ride := path.slice(0, path.find(stop) + 1)
		if _crosses_paved(ride) and _shake_would_hurt() and not state.effects.paved_streets_dont_shake:
			var detour := _stop_avoiding_paved(target)
			if detour != City.NOWHERE:
				return game.move_to(detour) == Game.Problem.NONE
			var strap := state.piles.hand.find(&"strap")
			if strap >= 0:
				game.play_card(strap)
		return game.move_to(stop) == Game.Problem.NONE
	# No step left, or waiting at a 5th floor client: a card gives steps (and delivers here).
	return _play_step_card()


func _take_dishes_here() -> bool:
	for order in state.orders:
		if order.picked_up or order.restaurant != state.courier_position or _skipped.has(order.id):
			continue
		game.take_dish(order.id)
		if state.bag.held != null and not _place_held():
			game.cancel_held()
			_skipped.append(order.id)
		return true
	return false


## Nearest client with a dish ready, or restaurant with a dish to take; NOWHERE if none.
func _next_target() -> Vector2i:
	var from_here := game.paths()
	var best := City.NOWHERE
	var best_score := INF
	for order in state.orders:
		var place := City.NOWHERE
		var score := 0.0
		if state.bag.is_ready_to_deliver(order.id):
			place = order.client
			# Deliver first, the most urgent first.
			score = from_here.distance_to(place) - 0.5 - 0.01 * (10 - order.deadline)
		elif not order.picked_up and not _skipped.has(order.id):
			place = order.restaurant
			score = from_here.distance_to(place)
		if place != City.NOWHERE and from_here.is_reachable(place) and score < best_score:
			best = place
			best_score = score
	return best


# --- Offers ---------------------------------------------------------------------------------

func _accept_offers() -> void:
	var offers := state.offers.duplicate()
	offers.sort_custom(func(a: Offer, b: Offer) -> bool: return _offer_pay(a) > _offer_pay(b))
	for offer: Offer in offers:
		if _worth_accepting(offer):
			game.accept_offer(offer.id)


func _worth_accepting(offer: Offer) -> bool:
	if state.orders.size() + offer.parts.size() > state.config.max_active_orders:
		return false
	var cells := 0
	for order in state.orders:
		cells += _cells_in_bag(order.dish)
	for part in offer.parts:
		cells += _cells_in_bag(part.dish)
	if cells > state.bag.columns * state.bag.rows * BAG_FILL_RATIO:
		return false
	# Orders not delivered by the end of the night cost rating: count the turns left too.
	var turns_left := state.config.turns_per_night - state.turn + 1
	var to_restaurant := state.city.distance(state.courier_position, offer.restaurant) \
			+ STEPS_PER_ACCEPTED_ORDER * state.orders.size()
	for part in offer.parts:
		var steps := to_restaurant + state.city.distance(offer.restaurant, part.client)
		var turns := ceili(steps / float(ESTIMATED_STEPS_PER_TURN))
		if turns > part.deadline or turns > turns_left:
			return false
	return true


## Cells the dish will take in the grid (none in the cup holder).
func _cells_in_bag(dish: DishData) -> int:
	return 0 if state.effects.cup_holder and dish.fits_cup_holder else dish.cell_count()


static func _offer_pay(offer: Offer) -> int:
	var pay := 0
	for part in offer.parts:
		pay += part.pay
	return pay


# --- Bag ------------------------------------------------------------------------------------

## Drops the dish in hand where it sits lowest and is held the most on the sides.
## Returns false if it fits nowhere.
func _place_held() -> bool:
	var best_rotation := -1
	var best_column := -1
	var best_score := -INF
	for rotation in 4:
		for column in state.bag.columns:
			if state.bag.drop_problem(column) == Bag.Problem.NONE:
				var score := _placement_score(state.bag.drop_cells(state.bag.held.shape, column))
				if score > best_score:
					best_score = score
					best_rotation = rotation
					best_column = column
		game.rotate_held()
	if best_column < 0:
		return false
	for i in best_rotation:
		game.rotate_held()
	return game.drop_held(best_column) == Game.Problem.NONE


## Higher is better: low in the bag, touching a wall or a dish on each side.
func _placement_score(cells: Array[Vector2i]) -> float:
	var score := 0.0
	var left := false
	var right := false
	for cell in cells:
		score += cell.y
		left = left or _blocked(cell + Vector2i.LEFT, cells)
		right = right or _blocked(cell + Vector2i.RIGHT, cells)
	if left and right:
		score += 10.0
	return score


func _blocked(cell: Vector2i, own: Array[Vector2i]) -> bool:
	if cell.x < 0 or cell.x >= state.bag.columns:
		return true
	return not own.has(cell) and state.bag.item_at(cell) != null


func _crosses_paved(path: Array[Vector2i]) -> bool:
	var previous := state.courier_position
	for crossroads in path:
		if state.city.street_between(previous, crossroads) == City.Street.PAVED:
			return true
		previous = crossroads
	return false


## A crossroads within the steps left, reached without paved streets, that gets closer to
## the target than here; NOWHERE if there is none. The ride goes on from there.
func _stop_avoiding_paved(target: Vector2i) -> Vector2i:
	var from_here := game.paths()
	var best := City.NOWHERE
	var best_left := from_here.distance_to(target)
	for crossroads in from_here.reachable_within(state.steps):
		if _crosses_paved(from_here.path_to(crossroads)):
			continue
		var left := state.city.paths_from(crossroads, state.crossing_works).distance_to(target)
		if left >= 0 and left < best_left:
			best = crossroads
			best_left = left
	return best


## Dishes a shake would damage now.
func _shake_would_hurt() -> bool:
	if state.bag.braced:
		return false
	for item in state.bag.loose_items():
		if not item.damaged and (item.is_fragile() or not state.effects.only_fragile_shaken):
			return true
	return false


# --- Cards ----------------------------------------------------------------------------------

## Plays the best card to get steps. Returns false when no card helps.
func _play_step_card() -> bool:
	var hand := state.piles.hand
	if state.paid_cards_played >= state.max_paid_cards():
		return false
	# Free cards that draw first: they may bring a better card to play.
	var draw_free := hand.find(&"coffee")
	if draw_free >= 0:
		return game.play_card(draw_free) == Game.Problem.NONE
	var best := -1
	var best_steps := 0
	var safe := state.effects.cards_never_shake or not _shake_would_hurt()
	for i in hand.size():
		var card: CardData = state.content.cards[hand[i]]
		var steps := game.card_steps(card.id)
		if steps == 0 or (card.shakes and not safe) or card.rating_cost_tenths > 0:
			continue
		if steps > best_steps:
			best = i
			best_steps = steps
	if best < 0:
		best = _fallback_card(safe)
	if best < 0:
		return false
	var chosen: CardData = state.content.cards[hand[best]]
	if chosen.shakes and not safe:
		var strap := hand.find(&"strap")
		if strap >= 0:
			game.play_card(strap)
			return true
	return game.play_card(best) == Game.Problem.NONE


## When no safe card gives steps: the Contresens, then drawing cards, then a shaking card.
func _fallback_card(safe: bool) -> int:
	var hand := state.piles.hand
	for id in [&"wrong", &"kebab"]:
		var index := hand.find(id)
		if index >= 0:
			return index
	if not safe:
		for i in hand.size():
			if state.content.cards[hand[i]].shakes:
				return i
	return -1


## "Coup de fil" when an order is about to be late, if a card is left to ride after it.
func _call_if_late_soon() -> void:
	var call := state.piles.hand.find(&"call")
	if call < 0 or state.paid_cards_played + 1 >= state.max_paid_cards():
		return
	for order in state.orders:
		if order.deadline <= 0:
			game.play_card(call)
			return


func _play_fatigue() -> void:
	var index := state.piles.hand.find(state.config.fatigue_card)
	while index >= 0 and state.paid_cards_played < state.max_paid_cards():
		game.play_card(index)
		index = state.piles.hand.find(state.config.fatigue_card)


# --- Between nights -------------------------------------------------------------------------

func _pick_reward() -> int:
	for id in REWARD_PRIORITY:
		for i in state.reward_choices.size():
			if state.reward_choices[i].id == id:
				return i
	return 0


func _shop() -> void:
	for id in SHOP_PRIORITY:
		for i in state.shop.items.size():
			var item := state.shop.items[i]
			if item.reward.id == id and not item.sold and state.wallet - item.price >= state.rent_tomorrow():
				game.buy(i)
