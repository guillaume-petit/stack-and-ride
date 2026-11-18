class_name Reward
extends RefCounted
## Something the player can get at the end of a night, free or in the shop (design doc §8.3 to
## §8.5): a card for the deck, an upgrade (bag, deck, city) or a piece of equipment.

enum Kind { CARD, UPGRADE, EQUIPMENT }

var kind: Kind
var id: StringName


func _init(p_kind: Kind, p_id: StringName) -> void:
	kind = p_kind
	id = p_id


## Every reward that can be drawn as a free choice at the end of a night: the cards sold in
## the shop and the upgrades, without the equipment (§9). Conditions are checked separately.
static func free_pool(content: GameContent) -> Array[Reward]:
	var pool: Array[Reward] = []
	for card_id in content.card_ids():
		if content.cards[card_id].shop_price > 0:
			pool.append(Reward.new(Kind.CARD, card_id))
	for upgrade_id in content.upgrade_ids():
		pool.append(Reward.new(Kind.UPGRADE, upgrade_id))
	return pool


## Shop price in euros; 0 when it is never sold.
func price(content: GameContent) -> int:
	match kind:
		Kind.CARD:
			return content.cards[id].shop_price
		Kind.UPGRADE:
			return content.upgrades[id].shop_price
		_:
			return content.equipment[id].shop_price


## The reward makes sense now (§8.5): bag not at its maximum size, a card left to remove,
## a restaurant type missing from the city and a free crossroads for it, equipment not owned yet.
func is_available(state: GameState) -> bool:
	match kind:
		Kind.CARD:
			return true
		Kind.EQUIPMENT:
			return not state.equipment.has(id)
	var upgrade: UpgradeData = state.content.upgrades[id]
	if upgrade.extra_columns > 0 and state.bag.columns + upgrade.extra_columns > state.config.max_bag_columns:
		return false
	if upgrade.extra_rows > 0 and state.bag.rows + upgrade.extra_rows > state.config.max_bag_rows:
		return false
	if upgrade.removes_card != &"" and not state.deck.has(upgrade.removes_card):
		return false
	if upgrade.opens_restaurant:
		var room := state.city.crossroads_without_place()
		room.erase(state.courier_position)
		if missing_restaurant_kinds(state).is_empty() or room.is_empty():
			return false
	return true


## Gives the reward to the player. Call is_available() first.
func apply(state: GameState) -> void:
	match kind:
		Kind.CARD:
			state.deck.append(id)
			return
		Kind.EQUIPMENT:
			state.equipment.append(id)
			state.refresh_effects()
			return
	var upgrade: UpgradeData = state.content.upgrades[id]
	state.bag.grow(upgrade.extra_columns, upgrade.extra_rows)
	if upgrade.removes_card != &"":
		state.deck.erase(upgrade.removes_card)
	if upgrade.opens_restaurant:
		var kind_id: StringName = state.rng.pick(missing_restaurant_kinds(state))
		state.city.add_restaurant(kind_id, state.rng, state.courier_position)


func equals(other: Reward) -> bool:
	return other != null and kind == other.kind and id == other.id


## Restaurant types of the content not present in the city, sorted.
static func missing_restaurant_kinds(state: GameState) -> Array[StringName]:
	var present := state.city.restaurant_kinds()
	var out: Array[StringName] = []
	for kind_id in state.content.restaurant_ids():
		if not present.has(kind_id):
			out.append(kind_id)
	return out
