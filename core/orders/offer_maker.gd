class_name OfferMaker
extends RefCounted
## Draws the offers of the app and computes their deadline and pay (design doc §5).
##
## The formulas are static functions without randomness, so that they can be tested
## (and shown by the interface) on their own.


## Number of offers the app shows at the start of a turn (§5.1).
static func offers_per_turn(config: GameConfig, effects: EffectData, night: int) -> int:
	var count := config.offers_per_turn_late if night >= config.late_offers_night else config.offers_per_turn
	return count + effects.extra_offers


## Deadline of one dish, in turns (§5.3).
static func deadline(config: GameConfig, effects: EffectData, distance: int, urgent: bool, cold: bool) -> int:
	var turns := ceili(distance / float(config.deadline_steps_per_turn)) + config.deadline_base
	if urgent:
		turns = maxi(config.min_deadline, turns + config.urgent_deadline)
	turns += effects.offer_deadline
	if cold and effects.cold_deadline != 0:
		turns = maxi(config.min_deadline, turns + effects.cold_deadline)
	return turns


## Pay of one dish, in euros (§5.3).
static func pay(config: GameConfig, effects: EffectData, cells: int, distance: int, acceptance: int,
		urgent: bool, grouped: bool, cold: bool) -> int:
	var base := cells * config.pay_per_cell + config.pay_base + ceili(distance / float(config.pay_steps_per_euro))
	var multiplier := acceptance_multiplier(config, acceptance) * effects.pay_multiplier
	if urgent:
		multiplier *= config.urgent_pay_multiplier
	if grouped:
		multiplier *= config.group_pay_multiplier
	if cold:
		multiplier *= effects.cold_pay_multiplier
	return roundi(base * multiplier)


## 0.6 at 0 % of acceptance, 1.0 at 100 % (§5.3).
static func acceptance_multiplier(config: GameConfig, acceptance: int) -> float:
	var floor_value := config.acceptance_pay_floor
	return floor_value + (1.0 - floor_value) * acceptance / 100.0


## Clients with neither an accepted order nor a pending offer, from the top left (§5.2).
static func free_clients(state: GameState) -> Array[Vector2i]:
	var busy: Array[Vector2i] = []
	for order in state.orders:
		busy.append(order.client)
	for offer in state.offers:
		busy.append_array(offer.clients())
	var out: Array[Vector2i] = []
	for client in state.city.crossroads_with(City.Place.CLIENT):
		if not busy.has(client):
			out.append(client)
	return out


## Draws a new offer, or returns null when no client is free. The id is left to the caller.
static func make(state: GameState) -> Offer:
	var config := state.config
	var effects := state.effects
	var rng := state.rng
	var free := free_clients(state)
	var restaurants := state.city.crossroads_with(City.Place.RESTAURANT)
	if free.is_empty() or restaurants.is_empty():
		return null

	var offer := Offer.new()
	offer.restaurant = rng.pick(restaurants)
	offer.restaurant_kind = state.city.restaurant_kind_at(offer.restaurant)
	var group_chance := effects.group_chance if effects.group_chance >= 0.0 else config.group_chance
	var wants_group := rng.chance(group_chance)
	offer.modifiers.urgent = rng.chance(config.urgent_chance)
	offer.modifiers.fifth_floor = rng.chance(config.fifth_floor_chance)
	if effects.vip_ignores_acceptance or state.acceptance >= config.vip_min_acceptance:
		var vip_chance := effects.vip_chance if effects.vip_chance >= 0.0 else config.vip_chance
		offer.modifiers.vip = rng.chance(vip_chance)

	var clients: Array[Vector2i] = []
	var first: Vector2i = rng.pick(free)
	clients.append(first)
	free.erase(first)
	var size := config.group_size if wants_group else 1
	while clients.size() < size and not free.is_empty():
		var nearest := _nearest(free, first, config.group_nearest_clients)
		var next: Vector2i = rng.pick(nearest)
		clients.append(next)
		free.erase(next)
	# Without a second free client the offer is a simple one, without the grouped bonus.
	offer.modifiers.grouped = clients.size() > 1

	var menu: Array[StringName] = state.content.restaurants[offer.restaurant_kind].dishes
	for client in clients:
		var part := Offer.Part.new()
		part.dish = state.content.dishes[rng.pick(menu)]
		part.client = client
		var distance := state.city.distance(offer.restaurant, client)
		var cold := part.dish.temperature == DishData.Temperature.COLD
		part.deadline = deadline(config, effects, distance, offer.modifiers.urgent, cold)
		part.pay = pay(config, effects, part.dish.cell_count(), distance, state.acceptance,
				offer.modifiers.urgent, offer.modifiers.grouped, cold)
		offer.parts.append(part)
	return offer


## The count clients nearest to the target (Manhattan distance), ties broken by reading order.
static func _nearest(clients: Array[Vector2i], target: Vector2i, count: int) -> Array[Vector2i]:
	var sorted := clients.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := City.manhattan(a, target)
		var db := City.manhattan(b, target)
		if da != db:
			return da < db
		return a.y < b.y if a.y != b.y else a.x < b.x)
	sorted.resize(mini(count, sorted.size()))
	return sorted
