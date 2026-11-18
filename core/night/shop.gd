class_name Shop
extends RefCounted
## The shop between two nights (design doc §10). Each item can be bought once per visit.


class Item:
	extends RefCounted
	var reward: Reward
	## In euros.
	var price: int
	var sold: bool = false


var items: Array[Item] = []


## Draws the stock: equipment not owned, a bag upgrade, cards, and the other upgrades sold
## in the shop (Désencombrer), each only when available (§10).
static func stock(state: GameState) -> Shop:
	var content := state.content
	var config := state.config
	var shop := Shop.new()
	var equipment: Array[Reward] = []
	for id in content.equipment_ids():
		equipment.append(Reward.new(Reward.Kind.EQUIPMENT, id))
	var bag_upgrades: Array[Reward] = []
	var other_upgrades: Array[Reward] = []
	for id in content.upgrade_ids():
		var upgrade: UpgradeData = content.upgrades[id]
		if not upgrade.sold_in_shop():
			continue
		var reward := Reward.new(Reward.Kind.UPGRADE, id)
		if upgrade.extra_columns > 0 or upgrade.extra_rows > 0:
			bag_upgrades.append(reward)
		else:
			other_upgrades.append(reward)
	var cards: Array[Reward] = []
	for id in content.card_ids():
		if content.cards[id].shop_price > 0:
			cards.append(Reward.new(Reward.Kind.CARD, id))
	shop._add_drawn(equipment, config.shop_equipment, state)
	shop._add_drawn(bag_upgrades, config.shop_bag_upgrades, state)
	shop._add_drawn(cards, config.shop_cards, state)
	shop._add_drawn(other_upgrades, other_upgrades.size(), state)
	return shop


## Adds up to count rewards drawn among the available ones.
func _add_drawn(candidates: Array[Reward], count: int, state: GameState) -> void:
	var available: Array[Reward] = []
	for reward in candidates:
		if reward.is_available(state):
			available.append(reward)
	state.rng.shuffle(available)
	for i in mini(count, available.size()):
		var item := Item.new()
		item.reward = available[i]
		item.price = available[i].price(state.content)
		items.append(item)
