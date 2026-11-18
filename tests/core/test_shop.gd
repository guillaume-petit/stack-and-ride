extends TestCase
## The shop between two nights (design doc §10).

var f: GameFixture


func before_each() -> void:
	f = GameFixture.start()


func _count(shop: Shop, kind: Reward.Kind) -> int:
	var count := 0
	for item in shop.items:
		if item.reward.kind == kind:
			count += 1
	return count


func _ids(shop: Shop) -> Array[StringName]:
	var out: Array[StringName] = []
	for item in shop.items:
		out.append(item.reward.id)
	return out


func test_stock_follows_the_design() -> void:
	var shop := Shop.stock(f.state)
	assert_eq(shop.items.size(), 7)
	assert_eq(_count(shop, Reward.Kind.EQUIPMENT), 2)
	assert_eq(_count(shop, Reward.Kind.CARD), 3)
	assert_eq(_count(shop, Reward.Kind.UPGRADE), 2, "a bag upgrade and Désencombrer")
	var ids := _ids(shop)
	assert_true(ids.has(&"trim"))
	assert_true(ids.has(&"wide") or ids.has(&"tall"))
	assert_false(ids.has(&"resto"), "free reward only")
	for item in shop.items:
		assert_eq(item.price, item.reward.price(f.content))
		assert_true(item.price > 0)
		assert_false(item.sold)


func test_stock_skips_what_is_not_available() -> void:
	for id in f.content.equipment_ids():
		if id != &"gilet":
			f.state.equipment.append(id)
	f.state.bag.grow(2, 2)
	f.state.deck.clear()
	var shop := Shop.stock(f.state)
	assert_eq(_ids(shop).slice(0, 1), [&"gilet"], "only one equipment left")
	assert_eq(_count(shop, Reward.Kind.UPGRADE), 0, "bag at its maximum, no Pédaler")
	assert_eq(shop.items.size(), 4)


func test_buying_pays_and_applies() -> void:
	f.open_shop(100)
	var shop := f.state.shop
	shop.items[0].reward = Reward.new(Reward.Kind.EQUIPMENT, &"separator")
	shop.items[0].price = 18
	var wallet := f.state.wallet
	assert_eq(f.game.buy(0), Game.Problem.NONE)
	assert_eq(f.state.wallet, wallet - 18)
	assert_true(shop.items[0].sold)
	assert_true(f.state.bag.hot_and_cold_may_touch)
	assert_eq(f.game.buy(0), Game.Problem.ALREADY_BOUGHT)
	assert_eq(f.game.buy(42), Game.Problem.NO_SUCH_REWARD)


func test_not_enough_money() -> void:
	f.open_shop(30)
	f.state.wallet = 3
	assert_eq(f.game.buy(0), Game.Problem.NOT_ENOUGH_MONEY)
	assert_false(f.state.shop.items[0].sold)
	assert_eq(f.state.wallet, 3)


func test_the_condition_is_checked_again_when_buying() -> void:
	f.open_shop(100)
	var item := f.state.shop.items[0]
	item.reward = Reward.new(Reward.Kind.UPGRADE, &"wide")
	item.price = 22
	f.state.bag.grow(6 - f.state.bag.columns, 0)
	assert_eq(f.game.buy(0), Game.Problem.NOT_AVAILABLE)
	assert_eq(f.state.wallet, 75)


func test_the_bag_keeps_its_upgrades_at_the_next_night() -> void:
	f.open_shop(100)
	f.state.shop.items[0].reward = Reward.new(Reward.Kind.UPGRADE, &"tall")
	f.state.shop.items[0].price = 24
	f.game.buy(0)
	f.game.start_next_night()
	assert_eq(f.state.bag.rows, 4)
